import QtQuick 1.1
import com.nokia.meego 1.0

PageStackWindow {
    id: appWindow
    initialPage: chatsPage
    showToolBar: false

    property string activeChatJid: ""
    property string activeChatTitle: ""
    property variant allChatsData: []

    ListModel { id: chatsModel }
    ListModel { id: groupsModel }
    ListModel { id: archivedModel }
    ListModel { id: activeChatModel }

    function applyFilter(filterText) {
        chatsModel.clear();
        groupsModel.clear();
        archivedModel.clear();
        var q = (filterText || "").toLowerCase();
        for (var i = 0; i < allChatsData.length; i++) {
            var item = allChatsData[i];
            var nameMatch = item.name && item.name.toLowerCase().indexOf(q) !== -1;
            var textMatch = item.lastText && item.lastText.toLowerCase().indexOf(q) !== -1;
            if (q === "" || nameMatch || textMatch) {
                var target = item.isArchived ? archivedModel : (item.isGroup ? groupsModel : chatsModel);
                target.append(item);
            }
        }
    }

    function reloadChats() {
        var raw = pyBridge.get_chats();
        if (!raw || raw === "") return;
        try {
            var data = JSON.parse(raw);
            if (!data || !data.length) return;
            allChatsData = data;
            applyFilter(searchInput.text);
        } catch(e) {}
    }

    function reloadMessages(jid) {
        if (!jid || jid.length === 0) return;
        var raw = pyBridge.get_messages(jid);
        if (!raw || raw === "") return;
        try {
            var msgs = JSON.parse(raw);
            if (!msgs || msgs.length === 0) return;
            
            var lastNew = msgs[msgs.length - 1];
            var lastCur = activeChatModel.count > 0 ? activeChatModel.get(activeChatModel.count - 1) : null;
            if (lastCur && lastCur.text === lastNew.text && lastCur.time_str === lastNew.time_str && msgs.length === activeChatModel.count) {
                return;
            }

            activeChatModel.clear();
            for (var i = 0; i < msgs.length; i++) {
                activeChatModel.append(msgs[i]);
            }
            msgListView.positionViewAtEnd();
        } catch(e) {}
    }

    Page {
        id: chatsPage

        Rectangle {
            anchors.fill: parent
            color: "#111b21"

            // 1. Top Bar: BridyMee Logo + Title (z: 100)
            Rectangle {
                id: topBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 68
                color: "#202c33"
                z: 100

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Image {
                        width: 38
                        height: 38
                        anchors.verticalCenter: parent.verticalCenter
                        source: "file:///home/user/apps/wp/icons/bridymee_logo.png"
                        smooth: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "BridyMee"
                        color: "#00a884"
                        font.pixelSize: 28
                        font.bold: true
                    }
                }
            }

            // 2. Large Search Bar (z: 99)
            Rectangle {
                id: searchBar
                anchors.top: topBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 70
                color: "#111b21"
                z: 99

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "#202c33"
                    radius: 14

                    Item {
                        id: searchIconItem
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: "transparent"
                            border.color: "#8696a0"
                            border.width: 2
                        }
                        Rectangle {
                            x: 11
                            y: 11
                            width: 8
                            height: 3
                            radius: 1
                            color: "#8696a0"
                            rotation: 45
                        }
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: searchIconItem.right
                        anchors.leftMargin: 12
                        anchors.right: clearSearchBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#e9edef"
                        font.pixelSize: 22
                        onTextChanged: applyFilter(text)

                        Text {
                            anchors.fill: parent
                            text: "Sohbetlerde ara..."
                            color: "#8696a0"
                            font.pixelSize: 22
                            visible: !searchInput.activeFocus && searchInput.text.length === 0
                        }
                    }

                    Text {
                        id: clearSearchBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: "#8696a0"
                        font.pixelSize: 24
                        font.bold: true
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            // 3. Chat List (clip: true keeps it strictly between bars, scroll never jumps)
            ListView {
                id: chatListView
                anchors.top: searchBar.bottom
                anchors.bottom: bottomNavBar.top
                anchors.left: parent.left
                anchors.right: parent.right
                clip: true
                z: 1
                model: bottomNavBar.activeTab === 0 ? chatsModel : (bottomNavBar.activeTab === 1 ? groupsModel : archivedModel)
                interactive: true
                boundsBehavior: Flickable.DragAndOvershootBounds

                delegate: Item {
                    width: parent.width
                    height: 88

                    Rectangle {
                        id: avatarBox
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        height: 58
                        radius: 29
                        color: "#2a3942"

                        Text {
                            anchors.centerIn: parent
                            text: model.avatarChar || (model.name ? model.name.charAt(0).toUpperCase() : "#")
                            color: "#e9edef"
                            font.pixelSize: 24
                            font.bold: true
                            visible: !avatarImage.visible
                        }

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: model.avatarUrl && model.avatarUrl.length > 0 ? "file:///home/user/apps/wp/" + model.avatarUrl : ""
                            visible: model.avatarUrl && model.avatarUrl.length > 0 && status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }
                    }

                    Column {
                        anchors.left: avatarBox.right
                        anchors.leftMargin: 14
                        anchors.right: timeText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            text: model.name || "Bilinmeyen"
                            color: "#e9edef"
                            font.pixelSize: 24
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: model.lastText || ""
                            color: "#8696a0"
                            font.pixelSize: 18
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Text {
                        id: timeText
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.top: parent.top
                        anchors.topMargin: 18
                        text: model.time || ""
                        color: "#8696a0"
                        font.pixelSize: 15
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 86
                        anchors.right: parent.right
                        height: 1
                        color: "#202c33"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (pageStack.busy) return;
                            activeChatJid = model.chatJid;
                            activeChatTitle = model.name;
                            activeChatModel.clear();
                            var rawMsgs = pyBridge.get_messages(activeChatJid);
                            if (rawMsgs && rawMsgs !== "") {
                                try {
                                    var msgs = JSON.parse(rawMsgs);
                                    for (var m = 0; m < msgs.length; m++) {
                                        activeChatModel.append(msgs[m]);
                                    }
                                } catch(err) {}
                            }
                            pageStack.push(conversationPage);
                        }
                    }
                }
            }

            // 4. Sailfish OS Style Bottom Navigation Bar (84px, 18px Bold Text, Clean Icons)
            Rectangle {
                id: bottomNavBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 84
                color: "#202c33"
                z: 100
                property int activeTab: 0

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#2a3942"
                }

                Row {
                    anchors.fill: parent

                    // TAB 0: Chats
                    Rectangle {
                        width: bottomNavBar.width / 3
                        height: 84
                        color: "transparent"

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 34
                                height: 34
                                source: "file:///home/user/apps/wp/icons/chat.png"
                                opacity: bottomNavBar.activeTab === 0 ? 1.0 : 0.45
                                smooth: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Sohbetler"
                                color: bottomNavBar.activeTab === 0 ? "#00a884" : "#8696a0"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.7
                            height: 4
                            color: "#00a884"
                            visible: bottomNavBar.activeTab === 0
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: bottomNavBar.activeTab = 0
                        }
                    }

                    // TAB 1: Groups
                    Rectangle {
                        width: bottomNavBar.width / 3
                        height: 84
                        color: "transparent"

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 34
                                height: 34
                                source: "file:///home/user/apps/wp/icons/groups.png"
                                opacity: bottomNavBar.activeTab === 1 ? 1.0 : 0.45
                                smooth: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Gruplar"
                                color: bottomNavBar.activeTab === 1 ? "#00a884" : "#8696a0"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.7
                            height: 4
                            color: "#00a884"
                            visible: bottomNavBar.activeTab === 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: bottomNavBar.activeTab = 1
                        }
                    }

                    // TAB 2: Archive
                    Rectangle {
                        width: bottomNavBar.width / 3
                        height: 84
                        color: "transparent"

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 34
                                height: 34
                                source: "file:///home/user/apps/wp/icons/archive.png"
                                opacity: bottomNavBar.activeTab === 2 ? 1.0 : 0.45
                                smooth: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Arşiv"
                                color: bottomNavBar.activeTab === 2 ? "#00a884" : "#8696a0"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.7
                            height: 4
                            color: "#00a884"
                            visible: bottomNavBar.activeTab === 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: bottomNavBar.activeTab = 2
                        }
                    }
                }
            }
        }
    }

    Page {
        id: conversationPage

        function doSendMessage() {
            var txt = msgInput.text;
            if (!txt || txt.length === 0) return;
            msgInput.text = "";
            activeChatModel.append({
                "text": txt,
                "time_str": Qt.formatTime(new Date(), "hh:mm"),
                "isMe": true
            });
            msgListView.positionViewAtEnd();
            pyBridge.send_message(activeChatJid, txt);
        }

        Rectangle {
            anchors.fill: parent
            color: "#0b141a"

            // 1. Chat Header: z: 100 pinned on top (messages never overlap)
            Rectangle {
                id: chatHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 72
                color: "#202c33"
                z: 100

                Rectangle {
                    id: backBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 72
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        color: "#00a884"
                        font.pixelSize: 36
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!pageStack.busy && pageStack.currentPage === conversationPage) {
                                pageStack.pop();
                            }
                        }
                    }
                }

                Text {
                    anchors.left: backBtn.right
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: activeChatTitle
                    color: "#e9edef"
                    font.pixelSize: 24
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            // 2. Message List (clip: true keeps messages strictly between header and footer)
            ListView {
                id: msgListView
                anchors.top: chatHeader.bottom
                anchors.bottom: inputBar.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 12
                clip: true
                z: 1
                model: activeChatModel

                onHeightChanged: positionViewAtEnd()
                onCountChanged: positionViewAtEnd()

                delegate: Item {
                    width: msgListView.width
                    height: bubbleBox.height + 6

                    Rectangle {
                        id: bubbleBox
                        anchors.right: (model.isMe || model.is_from_me) ? parent.right : undefined
                        anchors.left: (model.isMe || model.is_from_me) ? undefined : parent.left
                        width: Math.min(Math.max(dummyText.paintedWidth + 28, 95), msgListView.width * 0.82)
                        height: contentCol.height + 16
                        color: (model.isMe || model.is_from_me) ? "#005c4b" : "#202c33"
                        radius: 12

                        Text {
                            id: dummyText
                            text: model.text || ""
                            font.pixelSize: 22
                            visible: false
                        }

                        Column {
                            id: contentCol
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            spacing: 6

                            Text {
                                width: parent.width
                                text: model.text || ""
                                color: "#e9edef"
                                font.pixelSize: 22
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }

                            Text {
                                anchors.right: parent.right
                                text: model.time_str || ""
                                color: "#8696a0"
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }

            // 3. Message Input Bar (z: 100)
            Rectangle {
                id: inputBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 72
                color: "#202c33"
                z: 100

                Rectangle {
                    id: inputWrapper
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: sendBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 52
                    color: "#2a3942"
                    radius: 26

                    TextInput {
                        id: msgInput
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#e9edef"
                        font.pixelSize: 22

                        onAccepted: conversationPage.doSendMessage()
                        Keys.onReturnPressed: conversationPage.doSendMessage()
                        Keys.onEnterPressed: conversationPage.doSendMessage()

                        Text {
                            id: placeholder
                            anchors.fill: parent
                            text: "Mesaj yazın..."
                            color: "#8696a0"
                            font.pixelSize: 22
                            visible: !msgInput.activeFocus && msgInput.text.length === 0
                        }
                    }
                }

                Rectangle {
                    id: sendBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 58
                    height: 58
                    radius: 29
                    color: "#00a884"

                    Text {
                        anchors.centerIn: parent
                        text: "➤"
                        color: "#ffffff"
                        font.pixelSize: 26
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: conversationPage.doSendMessage()
                        onClicked: conversationPage.doSendMessage()
                    }
                }
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: reloadChats()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (pageStack.currentPage === conversationPage) {
                if (activeChatJid.length > 0) {
                    reloadMessages(activeChatJid);
                }
            }
        }
    }
}
