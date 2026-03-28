# 🦙 KhongAI - OpenClaw with Telegram Bot Admin Control

<div align="center">

![KhongAI Banner](https://i.pinimg.com/736x/b9/ff/56/b9ff56209b3d5156c0790e01ecde7abf.jpg)

**AI Assistant with Telegram Bot Management**
Control and configure your AI assistant via Telegram commands

[![GitHub stars](https://img.shields.io/github/stars/khongtk2004/khongai-openclaw?style=social)](https://github.com/khongtk2004/khongai-openclaw/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/khongtk2004/khongai-openclaw?style=social)](https://github.com/khongtk2004/khongai-openclaw/network/members)
[![Docker](https://img.shields.io/badge/docker-ghcr.io-blue)](https://github.com/khongtk2004/khongai-openclaw/pkgs/container/khongai-openclaw)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

[Report Bug](https://github.com/khongtk2004/khongai-openclaw/issues) ·
[Request Feature](https://github.com/khongtk2004/khongai-openclaw/issues) ·
[Telegram Support](https://t.me/khongtk)

</div>

---

## ✨ Features

* 🤖 **Telegram Admin Panel** – Control AI remotely
* 🎯 **Full OpenClaw Integration**
* 👥 **Multi-admin Support** (@khongtk, @renyu4444)
* 🐳 **Docker Ready** – One-command deployment
* 🔄 **Auto-restart Services**
* 📝 **Logging System**
* 🔐 **Secure Commands (Confirmation Required)**
* ⚡ **Fast Execution**
* 🖥️ **Cross-platform Support**

---

## 🎯 Use Cases

* Personal AI Assistant
* Team AI Management
* Remote Monitoring
* AI Model Switching
* Log Checking via Telegram
* Safe System Commands Execution

---

## 📋 Prerequisites

| Requirement | Minimum  | Recommended |
| ----------- | -------- | ----------- |
| RAM         | 4GB      | 8GB+        |
| Disk        | 10GB     | 20GB+       |
| Docker      | 20.10+   | Latest      |
| Internet    | Required | Required    |

---

## 🚀 Quick Install

### 🐧 Linux / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.sh)
```

---

### 🪟 Windows (PowerShell)

#### Option 1 (Admin)

```powershell
irm https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.ps1 | iex
```

#### Option 2 (User + Docker Desktop)

```powershell
irm https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.ps1 | iex
```

---

## ⚙️ Install Options

### Linux / macOS

```bash
# Pull only
--pull-only

# Skip onboarding
--skip-onboard

# No auto start
--no-start

# Custom directory
--install-dir /opt/khongai
```

---

### Windows

```powershell
-PullOnly
-SkipOnboard
-NoStart
-InstallDir "C:\khongai"
```

---

## 🔄 Workflow

1. Run install script
2. Setup Telegram bot
3. Configure admins
4. Start service
5. Control via Telegram

---

## 🤖 Telegram Commands

| Command  | Description     |
| -------- | --------------- |
| /start   | Start bot       |
| /status  | Check system    |
| /logs    | View logs       |
| /restart | Restart service |
| /model   | Change AI model |

---

## ⚙️ Configuration

* Telegram Bot Token
* Admin User IDs
* AI Model Settings
* Docker Environment

---

## 📊 Monitoring & Logs

* Logs stored locally
* View via Telegram
* Debug support included

---

## 🛠️ Troubleshooting

* Ensure Docker is installed
* Check internet connection
* Verify bot token
* Restart services

---

## 🔄 Updating

```bash
git pull
docker compose pull
docker compose up -d
```

---

## 🗑️ Uninstall

```bash
docker compose down -v
rm -rf khongai-openclaw
```

---

## 🤝 Contributing

Pull requests are welcome!
Feel free to improve features or fix bugs.

---

## 📝 License

MIT License

---

## 🙏 Credits

* OpenClaw Project
* Docker Community
* Telegram Bot API

---

⭐ **Star this repo if you like it!**
