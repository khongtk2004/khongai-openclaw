# 🦙 KhongAI - OpenClaw with Telegram Bot Admin Control

<div align="center">

## 🤖 AI Assistant with Telegram Bot Management

Control and configure your AI assistant via Telegram commands from anywhere

[Report Bug](https://github.com/khongtk2004/khongai-openclaw/issues) ·
[Request Feature](https://github.com/khongtk2004/khongai-openclaw/issues) ·
[Telegram Support](https://t.me/khongtk)

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

---

### 🪟 Windows (PowerShell - Admin)

```powershell
irm https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.ps1 | iex
```

---

## 📦 Manual Installation

```bash
# Clone repository
git clone https://github.com/khongtk2004/khongai-openclaw.git
cd khongai-openclaw

# Setup environment
cp .env.example .env
nano .env

# Start services
docker-compose up -d

# Check status
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

## 🔄 Workflow

1. Run install script
2. Setup Telegram bot (@BotFather)
3. Add admin IDs
4. Start services
5. Control via Telegram

---

## 🤖 Telegram Commands

### 🔑 Admin Commands

| Command     | Description    |
| ----------- | -------------- |
| /status     | System status  |
| /health     | Health check   |
| /logs       | View logs      |
| /restart    | Restart system |
| /model      | Change model   |
| /config     | View config    |
| /users      | List users     |
| /adduser    | Add admin      |
| /removeuser | Remove admin   |

### 👤 User Commands

| Command | Description |
| ------- | ----------- |
| /start  | Start bot   |
| /status | Check bot   |
| /info   | Info        |
| /help   | Help        |

---

## 🔧 Configuration

### `.env`

```env
TELEGRAM_BOT_TOKEN=your_token
TELEGRAM_ADMIN_IDS=123456789

AI_MODEL=openclaw-default
AI_TEMPERATURE=0.7
AI_MAX_TOKENS=2000

COMPOSE_PROJECT_NAME=khongai
DOCKER_IMAGE=ghcr.io/openclaw/openclaw:latest

NODE_ENV=production
LOG_LEVEL=info
AUTO_RESTART=true

REQUIRE_CONFIRMATION=true
SESSION_TIMEOUT=3600
```

---

## 📊 Monitoring & Logs

### Log Paths

```bash
docker logs khongai
~/khongai-telegram-bot/bot.log
~/.khongai/logs/system.log
~/.khongai/logs/error.log
```

### Commands

```bash
docker ps
docker stats khongai
ps aux | grep node
```

---

## 🛠️ Troubleshooting

### Docker Issues

```bash
docker logs khongai
sudo systemctl restart docker
docker-compose down && docker-compose up -d
```

### Bot Not Responding

```bash
ps aux | grep node
./stop-bot.sh
./start-bot.sh
tail -f bot.log
```

### Permission Issues

```bash
sudo chown -R $USER:$USER ~/.khongai
sudo chmod -R 755 ~/.khongai
sudo usermod -aG docker $USER
```

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
rm -rf ~/khongai ~/.khongai ~/khongai-telegram-bot
docker rmi ghcr.io/openclaw/openclaw:latest
```

---

## 📁 Project Structure

```
khongai-openclaw/
├── install.sh
├── install.ps1
├── docker-compose.yml
├── .env.example
├── README.md
├── scripts/
```

---

## 🤝 Contributing

```bash
git checkout -b feature/new-feature
git commit -m "Add feature"
git push origin feature/new-feature
```

Then open a Pull Request 🚀

---

## 📝 License

MIT License

---

## 📞 Support

* Telegram: @khongai_support
* Issues: GitHub Issues

---

## ⭐ Support Project

* ⭐ Star the repo
* 🐛 Report bugs
* 💡 Suggest features
* 🔄 Share project

---

<div align="center">

**Made with ❤️ by KhongAI Team**

</div>
