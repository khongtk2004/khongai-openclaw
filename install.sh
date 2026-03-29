#!/bin/bash
# KhongAI Installer - With Telegram Input

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
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }

# Get Telegram credentials
get_telegram_credentials() {
    echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Setup${NC}\n"
    
    # Get Bot Token
    while true; do
        echo -e "${YELLOW}Enter your Telegram Bot Token:${NC}"
        echo -e "${BLUE}(Get it from @BotFather on Telegram)${NC}"
        read -p "➤ " TELEGRAM_BOT_TOKEN
        
        if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
            log_error "Bot Token cannot be empty!"
        elif [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            log_error "Invalid token format! Should be like: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
        else
            log_success "Token format accepted"
            break
        fi
    done
    
    # Get Telegram Username (optional)
    echo -e "\n${YELLOW}Enter your Telegram Username (optional):${NC}"
    echo -e "${BLUE}(Without @ symbol - for notifications)${NC}"
    read -p "➤ " TELEGRAM_USERNAME
    
    if [[ -n "$TELEGRAM_USERNAME" ]]; then
        # Remove @ if user added it
        TELEGRAM_USERNAME="${TELEGRAM_USERNAME#@}"
        log_success "Username: @$TELEGRAM_USERNAME"
    else
        log_info "No username provided (optional)"
    fi
    
    echo -e "\n${GREEN}✓ Telegram credentials saved${NC}"
}

print_banner

# Get Telegram credentials
get_telegram_credentials

log_step "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p ~/.khongai/workspace
mkdir -p ~/.khongai/logs

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

# Create bot directory
mkdir -p ~/khongai-telegram-bot
cd ~/khongai-telegram-bot

# Initialize npm project
cat > package.json << EOF
{
  "name": "khongai-telegram-bot",
  "version": "1.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0"
  }
}
EOF

# Install dependencies
npm install --silent 2>/dev/null || {
    log_info "Installing dependencies..."
    npm install
}

# Create bot with the provided token
cat > bot.js << EOF
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

// Your bot token from @BotFather
const token = '${TELEGRAM_BOT_TOKEN}';
const bot = new TelegramBot(token, { polling: true });

// Configuration
const KHONGAI_URL = 'http://localhost:18789';
const ADMIN_USERNAME = '${TELEGRAM_USERNAME}';

console.log('🤖 KhongAI Telegram Bot Starting...');
console.log('📱 Bot Token: ' + token.substring(0, 10) + '...');
console.log('👤 Admin: @' + (ADMIN_USERNAME || 'Not set'));

// Send message to admin on startup
const notifyAdmin = async () => {
    if (ADMIN_USERNAME) {
        try {
            // Get all updates to find admin chat ID
            const updates = await bot.getUpdates();
            // This is simplified - in production you'd store chat IDs
            console.log('✅ Bot is ready. Send /start to begin.');
        } catch (error) {
            console.log('⚠️ Could not notify admin automatically');
        }
    }
};

// /start command
bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const username = msg.from.username || msg.from.first_name;
    
    const welcomeMessage = \`
🦙 *Welcome to KhongAI!* 🦙

Your AI assistant is ready to help.

*Available Commands:*
/status - Check KhongAI server status
/health - Detailed health check
/info - Bot information
/help - Show this help message

*About:*
🤖 KhongAI v1.0
💡 OpenClaw Gateway
📡 Telegram Integration

*Need help?* Contact @khongtk2004
    \`;
    
    bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
});

// /status command
bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    
    try {
        const response = await axios.get(\`\${KHONGAI_URL}/health\`, {
            timeout: 5000
        });
        
        if (response.status === 200) {
            bot.sendMessage(chatId, '✅ *KhongAI is running!*\n\nStatus: Healthy\nResponse: ' + JSON.stringify(response.data), { parse_mode: 'Markdown' });
        } else {
            bot.sendMessage(chatId, '⚠️ *KhongAI is responding but status unclear*', { parse_mode: 'Markdown' });
        }
    } catch (error) {
        bot.sendMessage(chatId, '❌ *Cannot connect to KhongAI*\n\nMake sure the server is running.\nCheck logs: `sudo docker logs khongai`', { parse_mode: 'Markdown' });
    }
});

// /health command
bot.onText(/\/health/, async (msg) => {
    const chatId = msg.chat.id;
    
    bot.sendMessage(chatId, '🩺 *Checking KhongAI Health...*', { parse_mode: 'Markdown' });
    
    try {
        const response = await axios.get(\`\${KHONGAI_URL}/health\`, {
            timeout: 5000
        });
        
        const healthMessage = \`
✅ *KhongAI Health Check*

Status: \${response.status === 200 ? 'Healthy' : 'Warning'}
HTTP Code: \${response.status}
Response Time: < 5s

*Details:*
\`\`\`json
\${JSON.stringify(response.data, null, 2)}
\`\`\`
        \`;
        
        bot.sendMessage(chatId, healthMessage, { parse_mode: 'Markdown' });
    } catch (error) {
        bot.sendMessage(chatId, \`
❌ *KhongAI Unreachable*

Error: \${error.code || error.message}
URL: \${KHONGAI_URL}

*Troubleshooting:*
1. Check if Docker is running: \`docker ps\`
2. View logs: \`sudo docker logs khongai\`
3. Restart: \`sudo docker restart khongai\`
        \`, { parse_mode: 'Markdown' });
    }
});

// /info command
bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    
    const infoMessage = \`
📊 *KhongAI Information*

*Server:*
- URL: \${KHONGAI_URL}
- Type: OpenClaw Gateway

*Bot:*
- Admin: @\${ADMIN_USERNAME || 'Not configured'}
- Commands: /start, /status, /health, /info

*Installation:*
- Directory: ~/khongai
- Logs: ~/.khongai/logs

*Support:*
- GitHub: @khongtk2004
- Telegram: @khongtk2004
    \`;
    
    bot.sendMessage(chatId, infoMessage, { parse_mode: 'Markdown' });
});

// /help command
bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    
    bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
});

// Error handling
bot.on('polling_error', (error) => {
    console.log('Polling error:', error.code);
    if (error.code === 'EFATAL' || error.code === 'ETELEGRAM') {
        console.log('Fatal error, restarting...');
        setTimeout(() => process.exit(1), 1000);
    }
});

// Start the bot
console.log('🚀 Bot is polling for messages...');
console.log('💡 Send /start to your bot on Telegram');

// Keep process alive
process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (error) => {
    console.error('Unhandled Rejection:', error);
});
EOF

# Create a .env file for credentials
cat > .env << EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_USERNAME=${TELEGRAM_USERNAME}
KHONGAI_URL=http://localhost:18789
EOF

# Create start script
cat > start-bot.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
node bot.js >> bot.log 2>&1 &
echo $! > bot.pid
echo "Bot started with PID: $(cat bot.pid)"
EOF

chmod +x start-bot.sh

# Create stop script
cat > stop-bot.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if [ -f bot.pid ]; then
    kill $(cat bot.pid) 2>/dev/null
    rm bot.pid
    echo "Bot stopped"
else
    pkill -f "node bot.js"
    echo "Bot stopped (by process name)"
fi
EOF

chmod +x stop-bot.sh

# Stop existing bot if running
pkill -f "node bot.js" 2>/dev/null || true
sleep 2

# Start the bot
log_step "Starting Telegram bot..."
nohup node bot.js > bot.log 2>&1 &
BOT_PID=$!
echo $BOT_PID > bot.pid

sleep 3

# Check if bot is running
if ps -p $BOT_PID > /dev/null 2>&1; then
    log_success "Telegram bot started (PID: $BOT_PID)"
else
    log_error "Failed to start bot. Check bot.log"
    tail -20 bot.log
fi

# Create management script
cat > ~/khongai-manager.sh << 'EOF'
#!/bin/bash
# KhongAI Management Script

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${BLUE}Starting KhongAI...${NC}"
        cd ~/khongai && sudo docker compose up -d
        cd ~/khongai-telegram-bot && ./start-bot.sh
        ;;
    stop)
        echo -e "${BLUE}Stopping KhongAI...${NC}"
        cd ~/khongai && sudo docker compose down
        cd ~/khongai-telegram-bot && ./stop-bot.sh
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo -e "${BLUE}KhongAI Status:${NC}"
        sudo docker ps | grep khongai
        echo -e "\n${BLUE}Bot Status:${NC}"
        ps aux | grep "node bot.js" | grep -v grep
        ;;
    logs)
        sudo docker logs khongai --tail 50
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|bot-logs}"
        exit 1
        ;;
esac
EOF

chmod +x ~/khongai-manager.sh

# Save credentials for future reference
cat > ~/.khongai/credentials.txt << EOF
========================================
KhongAI Installation Credentials
========================================
Date: $(date)
Telegram Bot Token: ${TELEGRAM_BOT_TOKEN}
Telegram Username: ${TELEGRAM_USERNAME}
Dashboard URL: http://localhost:18789
========================================
EOF

chmod 600 ~/.khongai/credentials.txt

# Final output
echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ KhongAI installed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}📊 Dashboard:${NC} http://localhost:18789"
echo -e "${CYAN}🤖 Telegram Bot:${NC} Send /start to your bot"
echo -e "${CYAN}👤 Admin Username:${NC} @${TELEGRAM_USERNAME:-Not set}\n"

echo -e "${BOLD}📝 Management Commands:${NC}"
echo -e "  ${YELLOW}~/khongai-manager.sh status${NC}     - Check status"
echo -e "  ${YELLOW}~/khongai-manager.sh restart${NC}    - Restart everything"
echo -e "  ${YELLOW}~/khongai-manager.sh logs${NC}       - View KhongAI logs"
echo -e "  ${YELLOW}~/khongai-manager.sh bot-logs${NC}   - View bot logs\n"

echo -e "${BOLD}🔧 Bot Directory:${NC} ~/khongai-telegram-bot"
echo -e "${BOLD}📁 Credentials saved:${NC} ~/.khongai/credentials.txt\n"

echo -e "${GREEN}🎉 Installation complete! Send /start to your Telegram bot to begin.${NC}\n"

# Test connection
sleep 2
echo -e "${CYAN}Testing KhongAI connection...${NC}"
if curl -s http://localhost:18789/health > /dev/null 2>&1; then
    log_success "KhongAI is responding!"
else
    log_error "KhongAI not responding. Check with: sudo docker logs khongai"
fi
