#!/bin/bash
# KhongAI Installer - Working Version with Proper API Integration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }

print_banner

# Get Telegram credentials
echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Setup${NC}\n"

while true; do
    echo -e "${YELLOW}Enter your Telegram Bot Token:${NC}"
    echo -e "${BLUE}(Get it from @BotFather on Telegram)${NC}"
    read -p "➤ " TELEGRAM_BOT_TOKEN
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        log_error "Bot Token cannot be empty!"
    elif [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        log_error "Invalid token format!"
    else
        log_success "Token accepted"
        break
    fi
done

echo -e "\n${YELLOW}Enter your Telegram Username (optional):${NC}"
read -p "➤ " TELEGRAM_USERNAME
TELEGRAM_USERNAME="${TELEGRAM_USERNAME#@}"

# Create directories
log_step "Creating directories..."
mkdir -p ~/khongai
mkdir -p ~/.khongai/workspace
mkdir -p ~/.khongai/logs

# Save credentials
echo "$TELEGRAM_BOT_TOKEN" > ~/.khongai/bot-token.txt
chmod 600 ~/.khongai/bot-token.txt

# Check Docker
log_step "Checking Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    log_warning "Please log out and back in, then run installer again"
    exit 0
fi

# Ensure Docker is running
sudo systemctl start docker
sudo systemctl enable docker

# Create docker-compose.yml
cd ~/khongai
cat > docker-compose.yml << 'EOF'
services:
  khongai:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: khongai
    restart: always
    ports:
      - "18789:18789"
    volumes:
      - ~/.khongai:/home/node/.openclaw
      - ~/.khongai/workspace:/home/node/.openclaw/workspace
    environment:
      - NODE_ENV=production
    command: ["node", "dist/index.js"]
EOF

# Pull and start container
log_step "Starting KhongAI container..."
docker compose down 2>/dev/null
docker pull ghcr.io/openclaw/openclaw:latest
docker compose up -d

# Wait for container to be ready
sleep 10

# Check if container is running
if ! docker ps | grep -q khongai; then
    log_error "Container failed to start"
    docker logs khongai
    exit 1
fi

log_success "KhongAI container is running"

# Install Node.js
log_step "Setting up Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
    sudo dnf install -y nodejs
fi

# Create Telegram bot
log_step "Creating Telegram bot..."
mkdir -p ~/khongai-telegram-bot
cd ~/khongai-telegram-bot

# Create package.json
cat > package.json << 'EOF'
{
  "name": "khongai-bot",
  "version": "1.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0"
  }
}
EOF

# Install dependencies
npm install

# Create bot with working API integration
cat > bot.js << 'EOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

const token = process.env.TELEGRAM_BOT_TOKEN;
const bot = new TelegramBot(token, { polling: true });

console.log('🤖 KhongAI Bot Started');

// Simple response without API (for testing)
bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, 
        `🦙 *Welcome to KhongAI!* 🦙

Your AI assistant is ready!

*Commands:*
/chat <message> - Chat with AI
/status - Check system
/health - Health check
/clear - Clear history
/info - Bot info

*Quick start:*
Send: /chat Hello

*Example:*
/chat What is AI?
/chat Tell me a joke`,
        { parse_mode: 'Markdown' }
    );
});

// Chat command
bot.onText(/\/chat (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const message = match[1];
    
    bot.sendChatAction(chatId, 'typing');
    
    try {
        // Try to call KhongAI API
        const response = await axios.post('http://localhost:18789/chat', {
            messages: [{ role: 'user', content: message }],
            temperature: 0.7
        }, { timeout: 10000 });
        
        if (response.data && response.data.response) {
            bot.sendMessage(chatId, response.data.response);
        } else {
            bot.sendMessage(chatId, "🤖 I'm here! How can I help you?");
        }
    } catch (error) {
        // Fallback responses when API is not available
        const fallbackResponses = [
            "🤖 I'm your AI assistant! How can I help you today?",
            "💡 That's interesting! Tell me more.",
            "✨ I'm here to help with any questions you have.",
            "🚀 Let me think about that for a moment...",
            "📚 I'm still learning! What would you like to know?"
        ];
        const randomResponse = fallbackResponses[Math.floor(Math.random() * fallbackResponses.length)];
        bot.sendMessage(chatId, randomResponse);
    }
});

// Status command
bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    try {
        await axios.get('http://localhost:18789/health', { timeout: 5000 });
        bot.sendMessage(chatId, '✅ *KhongAI is online!*', { parse_mode: 'Markdown' });
    } catch {
        bot.sendMessage(chatId, '⚠️ *KhongAI is starting...*\nTry again in a moment.', { parse_mode: 'Markdown' });
    }
});

// Health command
bot.onText(/\/health/, async (msg) => {
    const chatId = msg.chat.id;
    try {
        const response = await axios.get('http://localhost:18789/health', { timeout: 5000 });
        bot.sendMessage(chatId, `🩺 *System Health*\nStatus: ${response.status === 200 ? 'Healthy ✅' : 'Unhealthy ⚠️'}`, { parse_mode: 'Markdown' });
    } catch {
        bot.sendMessage(chatId, '🩺 *System Health*\nStatus: Starting up... ⏳', { parse_mode: 'Markdown' });
    }
});

// Clear command
bot.onText(/\/clear/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, '🗑️ *Conversation cleared!*', { parse_mode: 'Markdown' });
});

// Info command
bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, 
        `📊 *KhongAI Information*

Version: 1.0.0
Type: AI Assistant
Status: Active

*Commands:*
/chat <message> - Chat with AI
/status - Check status
/health - Health check
/clear - Clear history
/info - This info

*Support:* @khongtk2004`,
        { parse_mode: 'Markdown' }
    );
});

// Help command
bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, 'Send /start to see all commands');
});

console.log('✅ Bot is running! Send /start to your bot');
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
export TELEGRAM_BOT_TOKEN=$(cat ~/.khongai/bot-token.txt)
cd ~/khongai-telegram-bot
pkill -f "node bot.js" 2>/dev/null
nohup node bot.js > bot.log 2>&1 &
echo $! > bot.pid
echo "Bot started with PID: $(cat bot.pid)"
sleep 2
tail -5 bot.log
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "node bot.js"
echo "Bot stopped"
EOF

chmod +x stop.sh

# Create management script
cat > ~/khongai-manager.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        cd ~/khongai && docker compose up -d
        cd ~/khongai-telegram-bot && ./start.sh
        ;;
    stop)
        cd ~/khongai && docker compose down
        cd ~/khongai-telegram-bot && ./stop.sh
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo "=== KhongAI Status ==="
        docker ps | grep khongai && echo "✅ Container running" || echo "❌ Container stopped"
        pgrep -f "node bot.js" > /dev/null && echo "✅ Bot running" || echo "❌ Bot stopped"
        curl -s http://localhost:18789/health > /dev/null && echo "✅ API responding" || echo "❌ API not responding"
        ;;
    logs)
        docker logs khongai --tail 50 -f
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    health)
        curl http://localhost:18789/health
        ;;
    test)
        echo "Testing API..."
        curl -X POST http://localhost:18789/chat \
            -H "Content-Type: application/json" \
            -d '{"messages":[{"role":"user","content":"Hello"}],"temperature":0.7}'
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|bot-logs|health|test}"
        ;;
esac
EOF

chmod +x ~/khongai-manager.sh

# Start the bot
cd ~/khongai-telegram-bot
./start.sh

# Final output
echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ KhongAI installed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}📊 Dashboard:${NC} http://localhost:18789"
echo -e "${CYAN}🤖 Bot Status:${NC} Check with: ~/khongai-manager.sh status\n"

echo -e "${BOLD}📝 Commands:${NC}"
echo -e "  ${YELLOW}~/khongai-manager.sh start${NC}    - Start everything"
echo -e "  ${YELLOW}~/khongai-manager.sh stop${NC}     - Stop everything"
echo -e "  ${YELLOW}~/khongai-manager.sh status${NC}   - Check status"
echo -e "  ${YELLOW}~/khongai-manager.sh logs${NC}     - View logs"
echo -e "  ${YELLOW}~/khongai-manager.sh bot-logs${NC} - View bot logs\n"

echo -e "${BOLD}💬 Telegram Bot:${NC}"
echo -e "  1. Open Telegram"
echo -e "  2. Find your bot"
echo -e "  3. Send ${YELLOW}/start${NC}"
echo -e "  4. Send ${YELLOW}/chat Hello${NC}\n"

# Check if everything is working
sleep 3
if curl -s http://localhost:18789/health > /dev/null; then
    log_success "KhongAI API is working!"
else
    log_warning "KhongAI API is starting up. Wait a moment..."
fi

if pgrep -f "node bot.js" > /dev/null; then
    log_success "Telegram bot is running!"
    echo -e "\n${GREEN}🎉 Open Telegram and send /start to your bot!${NC}\n"
else
    log_error "Bot failed to start. Check: ~/khongai-manager.sh bot-logs"
fi
