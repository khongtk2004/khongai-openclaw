#!/bin/bash
# KhongAI Installer - Fixed Version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
INSTALL_DIR="${KHONGAI_INSTALL_DIR:-$HOME/khongai}"
COMPOSE_URL="https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/docker-compose.yml"

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║    _  __ _                                                    ║"
    echo "║   | |/ /| |                                                   ║"
    echo "║   | ' / | |   ___   __ _  _ __   _   _   ___   _ __           ║"
    echo "║   |  <  | |  / _ \ / _\` || '_ \ | | | | / _ \ | '_ \          ║"
    echo "║   | . \ | | |  __/| (_| || | | || |_| || (_) || | | |         ║"
    echo "║   |_|\_\|_|  \___| \__,_||_| |_| \__,_| \___/ |_| |_|         ║"
    echo "║                                                              ║"
    echo "║              OpenClaw + Telegram Bot Installer                ║"
    echo "║                    by KhongAI                                 ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step() { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p ~/.khongai/workspace
mkdir -p ~/.khongai/logs

print_banner

log_step "Checking Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker not installed. Installing..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    log_success "Docker installed. Please log out and back in."
    exit 0
fi
log_success "Docker found"

log_step "Pulling OpenClaw image..."
sudo docker pull ghcr.io/openclaw/openclaw:latest

log_step "Creating docker-compose.yml..."
cd "$INSTALL_DIR"
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  khongai:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: khongai
    restart: unless-stopped
    volumes:
      - ~/.khongai:/home/node/.openclaw
      - ~/.khongai/workspace:/home/node/.openclaw/workspace
    ports:
      - "18789:18789"
    environment:
      - NODE_ENV=production
    command: ["gateway", "start", "--foreground"]
EOF

log_step "Starting KhongAI..."
sudo docker compose up -d

sleep 5
if sudo docker ps | grep -q khongai; then
    log_success "KhongAI is running!"
else
    log_error "Failed to start"
    sudo docker logs khongai
    exit 1
fi

log_step "Setting up Telegram bot..."
cd ~
git clone https://github.com/khongtk2004/khongai-openclaw.git temp-bot 2>/dev/null || true
cd temp-bot
npm install node-telegram-bot-api 2>/dev/null || true

cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const token = 'YourBotoken';
const bot = new TelegramBot(token, { polling: true });
console.log('🤖 KhongAI Bot Running');
bot.onText(/\/start/, (msg) => {
    bot.sendMessage(msg.chat.id, '🦙 KhongAI Ready!\nSend /status');
});
bot.onText(/\/status/, async (msg) => {
    try {
        const res = await fetch('http://localhost:18789/health');
        bot.sendMessage(msg.chat.id, res.ok ? '✅ KhongAI OK' : '⚠️ Issues');
    } catch { bot.sendMessage(msg.chat.id, '❌ Cannot connect'); }
});
BOTEOF

nohup node bot.js > bot.log 2>&1 &

log_success "Bot started!"

echo -e "\n${GREEN}✅ KhongAI installed successfully!${NC}"
echo -e "📊 Dashboard: http://localhost:18789"
echo -e "🤖 Telegram: Send /start to your bot"
echo -e "📝 Logs: sudo docker logs khongai"
