# BridyMee 🕊️

> **Nokia N9 (MeeGo 1.2 Harmattan) İçin Yerel WhatsApp Multi-Device İstemcisi**  
> *BridyMee = Bird (Haberci Güvercin) + Bridge (Köprü) + Mee (MeeGo)*

![Platform](https://img.shields.io/badge/Platform-Nokia%20N9%20%7C%20MeeGo%201.2%20Harmattan-00a884)
![Backend](https://img.shields.io/badge/Backend-Go%20%7C%20whatsmeow-00d2c4)
![Frontend](https://img.shields.io/badge/Frontend-PySide%20QtQuick%201.1-202c33)
![Lisans](https://img.shields.io/badge/Lisans-MIT-blue)

BridyMee, efsanevi **Nokia N9** akıllı telefonuna modern WhatsApp Multi-Device desteğini tamamen yerel (web sarmalayıcısı olmadan) geri getirir. OMAP3630 işlemciye ve PowerVR SGX grafik hızlandırıcısına özel olarak optimize edilmiş QtQuick 1.1 arayüzü ile çalışır.

---

## ✨ Özellikler

- **%100 Yerel MeeGo Arayüzü:** Web tabanlı hantal çözümler yerine PySide + QtQuick 1.1 ile saf C++/Python performansı.
- **Sailfish OS Esintili Alt Gezinme Çubuğu:** 84px ergonomik alt bar ve belirgin vektörel simgeler (**Sohbetler**, **Gruplar**, **Arşiv**).
- **Akıcı 60 FPS Kaydırma:** Listeyi temizlemeyen akıllı yenileme; sayfayı nereye kaydırırsanız orada kalır, asla başa sarmaz.
- **Otomatik LID (Linked ID) Eşitleme:** WhatsApp'ın gizli kimliklerini (`@lid`) `whatsmeow_lid_map` tablosu üzerinden telefon rehberinizdeki gerçek isimlerle (örn. *Saliha Zahman*) eşleştirir.
- **Yerel Profil Fotoğrafları:** Diskten doğrudan önbelleklenmiş avatarları yükler; fotoğrafı olmayanlar için renkli baş harf gösterir.
- **Anında Mesajlaşma (Optimistic UI):** Gönder butonuna basıldığı salisede mesaj balonu ekrana yerleşir ve arka planda asenkron iletilir.
- **Gelişmiş Arama:** Sohbet başlıkları ve mesaj içeriklerinde anlık canlı arama kutusu.

---

## 🏗️ Mimari Yapı

```
┌─────────────────────────────────┐           ┌─────────────────────────────────┐
│     Nokia N9 (MeeGo 1.2)        │           │     Köprü Sunucu (Host Cihaz)   │
│                                 │           │ (Termux / Linux / Raspberry Pi) │
│  ┌───────────────────────────┐  │   HTTP    │  ┌───────────────────────────┐  │
│  │   main.qml (QtQuick 1.1)  │  │  :8082    │  │   wp-server (Go Binary)   │  │
│  └─────────────┬─────────────┘  │◄─────────►│  └─────────────┬─────────────┘  │
│                │ PySide Bridge  │           │                │ whatsmeow      │
│  ┌─────────────┴─────────────┐  │           │  ┌─────────────┴─────────────┐  │
│  │     wp.py (Python 2.6)    │  │           │  │   WhatsApp Multi-Device   │  │
│  └───────────────────────────┘  │           │  └───────────────────────────┘  │
└─────────────────────────────────┘           └─────────────────────────────────┘
```

---

## 🚀 Kurulum Rehberi

### 1. Sunucu Kurulumu (Android Termux veya Linux Bilgisayar)

1. **Gerekli Paketleri Yükleyin:**
   ```bash
   pkg install golang sqlite git   # Termux için
   # veya: sudo apt install golang sqlite3 git  # Ubuntu / Debian
   ```

2. **Projeyi İndirin ve Derleyin:**
   ```bash
   git clone https://github.com/kullaniciadi/BridyMee.git
   cd BridyMee/server
   go build -o wp-server main.go
   ```

3. **Başlatın ve Eşleyin:**
   ```bash
   ./wp-server
   ```
   İlk çalıştırmada terminalde beliren QR kodu ana WhatsApp telefonunuzdan taratın (**Bağlı Cihazlar** -> **Cihaz Bağla**).

### 2. Nokia N9 İstemci Kurulumu

1. **İstemci Dosyalarını N9'a Aktarın:**
   `client/` klasörünü Nokia N9'unuzda `/home/user/apps/wp` dizinine kopyalayın.

2. **Sunucu IP Adresini Tanımlayın:**
   `/home/user/apps/wp/wp.py` dosyasını açıp sunucunuzun yerel Wi-Fi IP adresini yazın:
   ```python
   SERVER_URL = "http://192.168.x.x:8082"
   ```

3. **Otomatik Yükleyiciyi Çalıştırın:**
   N9 terminalinde (root yetkisiyle):
   ```bash
   cd /home/user/apps/wp
   sh install_n9.sh
   ```

4. **Kullanmaya Başlayın:**
   Nokia N9 ana menüsünde **BridyMee** ikonuna tıklayarak doğrudan kullanabilirsiniz!

---

## 📄 Lisans

Bu proje MIT Lisansı ile lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
