# 🦙 KhongAI - OpenClaw with Telegram Bot Admin Control

<div align="center">

![KhongAI Banner](https://www.google.com/imgres?q=luffy&imgurl=https%3A%2F%2Fi.pinimg.com%2F736x%2Fb9%2Fff%2F56%2Fb9ff56209b3d5156c0790e01ecde7abf.jpg&imgrefurl=https%3A%2F%2Fwww.pinterest.com%2Fpin%2Fmonkey-d-luffy-icon--35184440831805673%2F&docid=1fqiTXDcUD9WVM&tbnid=xfGaQ8ilIVu3TM&vet=12ahUKEwjyv9Hb4MSTAxWnwzgGHWyMDkYQnPAOegQIGBAB..i&w=736&h=736&hcb=2&ved=2ahUKEwjyv9Hb4MSTAxWnwzgGHWyMDkYQnPAOegQIGBAB)

## 🤖 AI Assistant with Telegram Bot Management

Control and configure your AI assistant via Telegram commands from anywhere

[Report Bug](https://github.com/khongtk2004/khongai-openclaw/issues) ·
[Request Feature](https://github.com/khongtk2004/khongai-openclaw/issues) ·
[Telegram Support](https://t.me/khongtk)

</div>

---

## 📸 Preview

<div align="center">

![Dashboard Preview](https://via.placeholder.com/900x450/1e293b/ffffff?text=KhongAI+Dashboard)
![Telegram Bot Preview](https://via.placeholder.com/900x450/334155/ffffff?text=Telegram+Bot+Control)

</div>

---

## 🏗️ Architecture

<div align="center">

![Architecture Diagram](https://via.placeholder.com/1000x500/020617/ffffff?text=User+%E2%86%92+Telegram+Bot+%E2%86%92+KhongAI+%E2%86%92+OpenClaw+%E2%86%92+Docker)

</div>

---

## ✨ Features

* 🤖 Telegram Admin Panel – Control AI remotely via commands
* 🎯 Full OpenClaw Integration
* 👥 Multi-admin Support
* 🐳 Docker Ready (one-command deploy)
* 🔄 Auto-restart Services
* 📝 Logging System
* 🔐 Secure Commands with confirmation
* ⚡ Fast Execution
* 🖥️ Cross-platform Support
* 📊 Real-time Monitoring
* 🔧 Easy Configuration
* 🚀 Zero Downtime Updates

---

## 🎯 Use Cases

* Personal AI assistant (control anywhere)
* Team AI management
* Remote monitoring
* AI model switching
* Log checking via Telegram
* Secure system command execution
* Automation & scheduling

---

## 📋 Prerequisites

| Requirement | Minimum                 | Recommended |
| ----------- | ----------------------- | ----------- |
| RAM         | 4GB                     | 8GB+        |
| Disk        | 10GB                    | 20GB+       |
| Docker      | 20.10+                  | Latest      |
| Node.js     | 16+                     | 18+         |
| Internet    | Required                | Stable      |
| OS          | Linux / macOS / Windows | Latest      |

---

## 🚀 Quick Install

### 🐧 Linux / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.sh)
```

### 🪟 Windows (PowerShell - Admin)

```powershell
irm https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.ps1 | iex
```

---

## 📦 Manual Installation

```bash
git clone https://github.com/khongtk2004/khongai-openclaw.git
cd khongai-openclaw

cp .env.example .env
nano .env

docker-compose up -d
docker-compose ps
```

---

## ⚙️ Install Options

### Linux / macOS

```bash
bash install.sh --pull-only
bash install.sh --skip-onboard
bash install.sh --no-start
bash install.sh --install-dir /opt/khongai
bash install.sh --verbose
```

### Windows

```powershell
.\install.ps1 -PullOnly
.\install.ps1 -SkipOnboard
.\install.ps1 -NoStart
.\install.ps1 -InstallDir "C:\khongai"
.\install.ps1 -TelegramBotToken "YOUR_TOKEN"
```

---

## 🤖 Telegram Commands

### 🔑 Admin

| Command  | Description    |
| -------- | -------------- |
| /status  | System status  |
| /logs    | View logs      |
| /restart | Restart system |
| /model   | Change model   |

### 👤 User

| Command | Description |
| ------- | ----------- |
| /start  | Start bot   |
| /help   | Help        |

---

## 📝 License

MIT License

---

<div align="center">

**Made with ❤️ by KhongAI Team**

</div>
