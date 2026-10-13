# BridyMee 🕊️

> **Native WhatsApp Multi-Device Client for Nokia N9 (MeeGo 1.2 Harmattan)**  
> *BridyMee = Bird (Messenger Dove) + Bridge + Mee (MeeGo)*

![Platform](https://img.shields.io/badge/Platform-Nokia%20N9%20%7C%20MeeGo%201.2%20Harmattan-00a884)
![Backend](https://img.shields.io/badge/Backend-Go%20%7C%20whatsmeow-00d2c4)
![Frontend](https://img.shields.io/badge/Frontend-PySide%20QtQuick%201.1-202c33)
![License](https://img.shields.io/badge/License-MIT-blue)

BridyMee brings WhatsApp back to the legendary **Nokia N9** with zero web wrappers. It features a native QtQuick 1.1 frontend optimized for the OMAP3630 processor and PowerVR SGX graphics, connected via a self-hosted Go Multi-Device bridge server running on an Android companion phone (Termux), Raspberry Pi, or local Linux server.

---

## ✨ Features

- **100% Native MeeGo UI:** Built with QtQuick 1.1 / PySide, styled with MeeGo AMOLED dark aesthetics.
- **Sailfish OS-Inspired Bottom Bar:** 84px thumb-friendly bottom navigation bar with crisp vector icons (**Chats**, **Groups**, **Archive**).
- **Smooth 60 FPS Scrolling:** Zero scroll resetting. Memory-efficient list delegates with subquery limits prevent PowerVR SGX driver crashes.
- **Automatic LID Resolution:** Automatically maps WhatsApp's internal Linked IDs (`@lid`) to real phone numbers and Google Contacts names via `whatsmeow_lid_map`.
- **Contact Avatars & Colored Fallbacks:** Displays cached profile photos locally from disk, with instant colored initial fallbacks.
- **Real-time Live Messaging:** Instant background dispatch (`/send`) and incoming message synchronization.
- **MeeGo Virtual Keyboard Integration:** Fast input response with Enter key binding and native touch handlers.
- **Interactive Search Bar:** Real-time filter across chat titles and message snippets.

---

## 🏗️ Architecture

```
┌─────────────────────────────────┐           ┌─────────────────────────────────┐
│     Nokia N9 (MeeGo 1.2)        │           │    Companion Device / Host      │
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

## 🚀 Quick Start Guide

### 1. Server Setup (Termux on Android or Linux Host)

1. **Install Go and SQLite:**
   ```bash
   pkg install golang sqlite git   # Termux
   # or: sudo apt install golang sqlite3 git  # Ubuntu / Debian
   ```

2. **Clone and Build:**
   ```bash
   git clone https://github.com/yourusername/BridyMee.git
   cd BridyMee/server
   go build -o wp-server main.go
   ```

3. **Run and Pair with WhatsApp:**
   ```bash
   ./wp-server
   ```
   On first launch, scan the displayed QR code with your primary WhatsApp phone (**Linked Devices** -> **Link a Device**).

### 2. Nokia N9 Client Installation

1. **Copy Client Files to Nokia N9:**
   Copy the `client/` folder to `/home/user/apps/wp` on your Nokia N9.

2. **Configure Server IP:**
   Open `/home/user/apps/wp/wp.py` and set your server's local IP address:
   ```python
   SERVER_URL = "http://192.168.x.x:8082"
   ```

3. **Run Automated Installer on N9:**
   Open terminal on N9 as root:
   ```bash
   cd /home/user/apps/wp
   sh install_n9.sh
   ```

4. **Launch BridyMee:**
   Tap the **BridyMee** icon from your Nokia N9 Application Menu!

---

## 🛠️ Technical Insights for MeeGo Developers

1. **Graphics Clipping:** Never use `clip: true` on rounded rectangles (`radius > 0`) on MeeGo Harmattan; the PowerVR SGX OpenGL ES 2.0 driver lacks a stencil buffer for clip paths, causing `BadDamage 153` segfaults.
2. **Network Limit in Qt 4.7.4:** Never use remote HTTP URLs directly in `ListView` delegates. Download avatars to local storage and load them with `file:///`.
3. **Maliit SIP Interaction:** Handle both `onPressed` and `onClicked` on touch items to prevent the virtual keyboard from consuming touch dismissal gestures.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
