package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/store/sqlstore"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
	waLog "go.mau.fi/whatsmeow/util/log"
	"google.golang.org/protobuf/proto"
)

type ChatItem struct {
	JID         string `json:"jid"`
	ChatJID     string `json:"chatJid"`
	Name        string `json:"name"`
	ChatTitle   string `json:"chatTitle"`
	LastText    string `json:"lastText"`
	LastMessage string `json:"last_message"`
	Time        string `json:"time"`
	TimeStr     string `json:"time_str"`
	UnreadCount int    `json:"unread_count"`
	IsGroup     bool   `json:"isGroup"`
	IsGroupOld  bool   `json:"is_group"`
	IsArchived  bool   `json:"isArchived"`
	IsArchOld   bool   `json:"is_archived"`
	AvatarChar  string `json:"avatarChar"`
	AvatarCharO string `json:"avatar_char"`
	AvatarURL   string `json:"avatarUrl"`
	AvatarURLO  string `json:"avatar_url"`
}

type MessageItem struct {
	ID        string `json:"id"`
	ChatJID   string `json:"chatJid"`
	SenderJID string `json:"senderJid"`
	Name      string `json:"name"`
	Text      string `json:"text"`
	TimeStr   string `json:"time_str"`
	Timestamp int64  `json:"timestamp"`
	IsFromMe  bool   `json:"is_from_me"`
	IsGroup   bool   `json:"is_group"`
}

var (
	client        *whatsmeow.Client
	appDB         *sql.DB
	dbMu          sync.Mutex
	contactBook   = make(map[string]string)
	contactBookMu sync.RWMutex
	isConnected   bool
	statusMu      sync.RWMutex
)

func cleanJIDString(jid string) string {
	if jid == "" {
		return ""
	}
	parts := strings.Split(jid, "@")
	if len(parts) == 2 {
		user := strings.Split(parts[0], ":")[0]
		return user + "@" + parts[1]
	}
	return jid
}

func isGroupJID(jid string) bool {
	return strings.HasSuffix(cleanJIDString(jid), "@g.us")
}

func initDB() {
	var err error
	appDB, err = sql.Open("sqlite3", "file:wp_history.db?_foreign_keys=on&_journal_mode=WAL")
	if err != nil {
		panic(err)
	}

	query := `
	CREATE TABLE IF NOT EXISTS messages (
		id TEXT PRIMARY KEY,
		chat_jid TEXT,
		sender_jid TEXT,
		name TEXT,
		text TEXT,
		timestamp INTEGER,
		is_from_me INTEGER,
		is_group INTEGER,
		is_archived INTEGER DEFAULT 0,
		time_str TEXT
	);
	CREATE INDEX IF NOT EXISTS idx_chat_jid ON messages(chat_jid);
	CREATE INDEX IF NOT EXISTS idx_timestamp ON messages(timestamp);
	`
	_, err = appDB.Exec(query)
	if err != nil {
		panic(err)
	}
}

func updateContactBook() {
	if client == nil || client.Store == nil || client.Store.Contacts == nil {
		return
	}
	contacts, err := client.Store.Contacts.GetAllContacts(context.Background())
	if err != nil {
		return
	}

	newMap := make(map[string]string)
	// 1. Load phone numbers with real address book full names
	for jid, contact := range contacts {
		if strings.HasSuffix(jid.String(), "@s.whatsapp.net") {
			n := strings.TrimSpace(contact.FullName)
			if n == "" { n = strings.TrimSpace(contact.BusinessName) }
			if n == "" { n = strings.TrimSpace(contact.PushName) }
			if n != "" {
				cJid := cleanJIDString(jid.String())
				newMap[cJid] = n
				u := jid.User
				if len(u) >= 10 {
					newMap[u[len(u)-10:]] = n
				}
			}
		}
	}

	// 2. Resolve WhatsApp LIDs to real address book names via whatsmeow_lid_map
	sStoreDB, sErr := sql.Open("sqlite3", "file:whatsapp_store.db?mode=ro")
	if sErr == nil {
		rows, rErr := sStoreDB.Query("SELECT lid, pn FROM whatsmeow_lid_map")
		if rErr == nil {
			for rows.Next() {
				var lid, pn string
				if rows.Scan(&lid, &pn) == nil {
					var realName string
					if n, ok := newMap[pn+"@s.whatsapp.net"]; ok && n != "" {
						realName = n
					} else if len(pn) >= 10 {
						if n, ok := newMap[pn[len(pn)-10:]]; ok && n != "" {
							realName = n
						}
					}
					if realName != "" {
						newMap[lid+"@lid"] = realName
						newMap[cleanJIDString(lid+"@lid")] = realName
					}
				}
			}
			rows.Close()
		}
		sStoreDB.Close()
	}

	// 3. Fallback for remaining LIDs to profile PushName
	for jid, contact := range contacts {
		cJid := cleanJIDString(jid.String())
		if _, ok := newMap[cJid]; !ok {
			n := strings.TrimSpace(contact.FullName)
			if n == "" { n = strings.TrimSpace(contact.PushName) }
			if n == "" { n = strings.TrimSpace(contact.BusinessName) }
			if n != "" {
				newMap[cJid] = n
			}
		}
	}

	contactBookMu.Lock()
	contactBook = newMap
	contactBookMu.Unlock()
	fmt.Printf("[BridyMee Server] %d contacts cached with LID mapping!
", len(newMap))
}

func resolveContactName(jidStr string, fallback ...string) string {
	fallbackName := ""
	if len(fallback) > 0 {
		fallbackName = fallback[0]
	}
	clean := cleanJIDString(jidStr)

	contactBookMu.RLock()
	name, ok := contactBook[clean]
	contactBookMu.RUnlock()
	if ok && name != "" {
		return name
	}

	user := strings.Split(clean, "@")[0]
	if len(user) >= 10 {
		p10 := user[len(user)-10:]
		contactBookMu.RLock()
		name, ok := contactBook[p10]
		contactBookMu.RUnlock()
		if ok && name != "" {
			return name
		}
	}

	if fallbackName != "" && fallbackName != jidStr && !strings.Contains(fallbackName, "@") {
		return fallbackName
	}

	digits := strings.TrimPrefix(user, "+")
	if len(digits) == 12 && strings.HasPrefix(digits, "90") {
		return fmt.Sprintf("+90 %s %s %s", digits[2:5], digits[5:8], digits[8:])
	}
	return "+" + digits
}

func loadArchivedChats() map[string]bool {
	res := make(map[string]bool)
	db, err := sql.Open("sqlite3", "file:whatsapp_store.db?mode=ro")
	if err != nil {
		return res
	}
	defer db.Close()
	rows, err := db.Query("SELECT chat_jid FROM whatsmeow_chat_settings WHERE archived = 1")
	if err != nil {
		return res
	}
	defer rows.Close()
	for rows.Next() {
		var j string
		rows.Scan(&j)
		res[cleanJIDString(j)] = true
	}
	return res
}

func saveMsg(m MessageItem) {
	dbMu.Lock()
	defer dbMu.Unlock()

	timeStr := time.Unix(m.Timestamp, 0).In(time.Local).Format("15:04")
	m.TimeStr = timeStr

	isFromMeInt := 0
	if m.IsFromMe { isFromMeInt = 1 }
	isGroupInt := 0
	if m.IsGroup { isGroupInt = 1 }

	_, _ = appDB.Exec(`
		INSERT OR IGNORE INTO messages (id, chat_jid, sender_jid, name, text, timestamp, is_from_me, is_group, is_archived, time_str)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
	`, m.ID, m.ChatJID, m.SenderJID, m.Name, m.Text, m.Timestamp, isFromMeInt, isGroupInt, m.TimeStr)
}

func eventHandler(evt interface{}) {
	switch v := evt.(type) {
	case *events.Connected:
		statusMu.Lock()
		isConnected = true
		statusMu.Unlock()
		fmt.Println("[BridyMee Server] Connected to WhatsApp Multi-Device!")
		go updateContactBook()

	case *events.Disconnected:
		statusMu.Lock()
		isConnected = false
		statusMu.Unlock()
		fmt.Println("[BridyMee Server] Disconnected from WhatsApp!")

	case *events.Message:
		if v.Message == nil {
			return
		}
		text := v.Message.GetConversation()
		if text == "" && v.Message.ExtendedTextMessage != nil {
			text = v.Message.ExtendedTextMessage.GetText()
		}
		if text == "" && v.Message.ImageMessage != nil {
			text = "[Fotoğraf]"
		}
		if text == "" && v.Message.VideoMessage != nil {
			text = "[Video]"
		}
		if text == "" && v.Message.AudioMessage != nil {
			text = "[Ses Kaydı]"
		}

		if text != "" {
			chatJID := v.Info.Chat.String()
			isGroup := isGroupJID(chatJID)
			senderJID := v.Info.Sender.ToNonAD().String()
			name := v.Info.PushName
			if name == "" {
				name = v.Info.Sender.User
			}

			saveMsg(MessageItem{
				ID:        v.Info.ID,
				ChatJID:   chatJID,
				SenderJID: senderJID,
				Name:      name,
				Text:      text,
				Timestamp: v.Info.Timestamp.Unix(),
				IsFromMe:  v.Info.IsFromMe,
				IsGroup:   isGroup,
			})
		}
	}
}

func main() {
	initDB()
	ctx := context.Background()

	os.MkdirAll("avatars", 0755)

	dbLog := waLog.Stdout("Database", "ERROR", true)
	container, err := sqlstore.New(ctx, "sqlite3", "file:whatsapp_store.db?_foreign_keys=on", dbLog)
	if err != nil {
		panic(err)
	}

	deviceStore, err := container.GetFirstDevice(ctx)
	if err != nil {
		panic(err)
	}

	client = whatsmeow.NewClient(deviceStore, waLog.Stdout("Client", "ERROR", true))
	client.AddEventHandler(eventHandler)

	http.HandleFunc("/main.qml", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		http.ServeFile(w, r, "main.qml")
	})

	http.HandleFunc("/avatar", func(w http.ResponseWriter, r *http.Request) {
		jid := r.URL.Query().Get("jid")
		clean := cleanJIDString(jid)
		filePath := filepath.Join("avatars", clean+".jpg")
		if _, err := os.Stat(filePath); err == nil {
			w.Header().Set("Content-Type", "image/jpeg")
			http.ServeFile(w, r, filePath)
			return
		}
		http.NotFound(w, r)
	})

	http.HandleFunc("/chats", func(w http.ResponseWriter, r *http.Request) {
		if len(contactBook) == 0 {
			updateContactBook()
		}
		archivedMap := loadArchivedChats()

		dbMu.Lock()
		rows, err := appDB.Query("SELECT chat_jid, name, text, time_str, is_group, is_archived, sender_jid, is_from_me FROM messages ORDER BY timestamp DESC")
		if err != nil {
			dbMu.Unlock()
			http.Error(w, err.Error(), 500)
			return
		}
		defer rows.Close()

		seenJID := make(map[string]bool)
		var chats []ChatItem

		for rows.Next() {
			var rawJid, rawName, text, timeStr, senderJid string
			var isGrp, isArchived, isFromMe int
			rows.Scan(&rawJid, &rawName, &text, &timeStr, &isGrp, &isArchived, &senderJid, &isFromMe)

			clean := cleanJIDString(rawJid)
			if clean == "" || strings.HasSuffix(clean, "@broadcast") || strings.HasSuffix(clean, "@newsletter") {
				continue
			}

			if seenJID[clean] {
				continue
			}
			seenJID[clean] = true

			realIsGroup := strings.HasSuffix(clean, "@g.us")
			displayName := resolveContactName(clean, rawName)
			realIsArchived := archivedMap[clean]

			avUrl := ""
			if _, err := os.Stat(filepath.Join("avatars", clean+".jpg")); err == nil {
				avUrl = "avatars/" + clean + ".jpg"
			}

			avChar := "#"
			if len(displayName) > 0 {
				avChar = strings.ToUpper(string([]rune(displayName)[0]))
			}

			finalSnippet := text
			if isFromMe == 1 {
				finalSnippet = "Siz: " + text
			}

			chats = append(chats, ChatItem{
				JID:         clean,
				ChatJID:     clean,
				Name:        displayName,
				ChatTitle:   displayName,
				LastText:    finalSnippet,
				LastMessage: finalSnippet,
				Time:        timeStr,
				TimeStr:     timeStr,
				IsGroup:     realIsGroup,
				IsGroupOld:  realIsGroup,
				IsArchived:  realIsArchived,
				IsArchOld:   realIsArchived,
				AvatarChar:  avChar,
				AvatarCharO: avChar,
				AvatarURL:   avUrl,
				AvatarURLO:  avUrl,
			})
		}
		dbMu.Unlock()

		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		if chats == nil {
			w.Write([]byte("[]"))
			return
		}
		json.NewEncoder(w).Encode(chats)
	})

	http.HandleFunc("/messages", func(w http.ResponseWriter, r *http.Request) {
		jid := r.URL.Query().Get("jid")
		if jid == "" {
			jid = r.URL.Query().Get("chat")
		}
		clean := cleanJIDString(jid)

		dbMu.Lock()
		defer dbMu.Unlock()

		userPrefix := strings.Split(clean, "@")[0]
		query := `
		SELECT id, chat_jid, sender_jid, name, text, time_str, is_from_me, is_group, timestamp 
		FROM (
			SELECT * FROM messages 
			WHERE chat_jid LIKE ? OR chat_jid LIKE ? 
			ORDER BY timestamp DESC LIMIT 30
		) ORDER BY timestamp ASC;
		`
		rows, err := appDB.Query(query, "%"+userPrefix+"%", clean)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		defer rows.Close()

		var msgs []MessageItem
		for rows.Next() {
			var m MessageItem
			var isFromMeInt, isGroupInt int
			rows.Scan(&m.ID, &m.ChatJID, &m.SenderJID, &m.Name, &m.Text, &m.TimeStr, &isFromMeInt, &isGroupInt, &m.Timestamp)
			m.IsFromMe = (isFromMeInt == 1)
			m.IsGroup = (isGroupInt == 1)
			msgs = append(msgs, m)
		}

		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		if msgs == nil {
			w.Write([]byte("[]"))
			return
		}
		json.NewEncoder(w).Encode(msgs)
	})

	http.HandleFunc("/send", func(w http.ResponseWriter, r *http.Request) {
		type SendPayload struct {
			To      string `json:"to"`
			Message string `json:"message"`
		}
		var p SendPayload
		if r.Body != nil {
			json.NewDecoder(r.Body).Decode(&p)
		}

		if p.To == "" || p.Message == "" || client == nil {
			http.Error(w, "missing parameter", 400)
			return
		}

		clean := strings.TrimPrefix(p.To, "+")
		// Automatically resolve LID to Phone number for instant message delivery
		if strings.HasSuffix(clean, "@lid") {
			lidNum := strings.Split(clean, "@")[0]
			sStoreDB, sErr := sql.Open("sqlite3", "file:whatsapp_store.db?mode=ro")
			if sErr == nil {
				var pn string
				if sStoreDB.QueryRow("SELECT pn FROM whatsmeow_lid_map WHERE lid = ?", lidNum).Scan(&pn) == nil && pn != "" {
					clean = pn + "@s.whatsapp.net"
				}
				sStoreDB.Close()
			}
		}

		var targetJID types.JID
		var err error
		if strings.Contains(clean, "@") {
			targetJID, err = types.ParseJID(clean)
		} else {
			targetJID = types.NewJID(clean, types.DefaultUserServer)
		}
		if err != nil {
			http.Error(w, err.Error(), 400)
			return
		}

		msg := &waE2E.Message{Conversation: proto.String(p.Message)}
		_, err = client.SendMessage(context.Background(), targetJID, msg)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		now := time.Now().Unix()
		timeStr := time.Now().In(time.Local).Format("15:04")
		msgID := fmt.Sprintf("%s_%d", targetJID.String(), now)
		isGrpInt := 0
		if isGroupJID(targetJID.String()) { isGrpInt = 1 }

		appDB.Exec(`
			INSERT OR REPLACE INTO messages (id, chat_jid, sender_jid, name, text, timestamp, is_from_me, is_group, is_archived, time_str) 
			VALUES (?, ?, ?, ?, ?, ?, 1, ?, 0, ?)
		`, msgID, targetJID.String(), targetJID.String(), "Ben", p.Message, now, isGrpInt, timeStr)

		w.Write([]byte(`{"status":"ok"}`))
	})

	// Start WhatsApp Client Connection
	if client.Store.ID == nil {
		qrChan, _ := client.GetQRChannel(context.Background())
		err = client.Connect()
		if err != nil {
			panic(err)
		}
		for evt := range qrChan {
			if evt.Event == "code" {
				fmt.Println("Scan QR code to log in:", evt.Code)
			} else {
				fmt.Println("QR Event:", evt.Event)
			}
		}
	} else {
		err = client.Connect()
		if err != nil {
			panic(err)
		}
		fmt.Println("[BridyMee Server] Multi-Device session restored.")
	}

	go func() {
		fmt.Println("[BridyMee Server] Listening on :8082 ...")
		if err := http.ListenAndServe(":8082", nil); err != nil {
			panic(err)
		}
	}()

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	client.Disconnect()
	appDB.Close()
	fmt.Println("[BridyMee Server] Shutdown complete.")
}
