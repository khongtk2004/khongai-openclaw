#!/bin/bash
# KhongAI Installer - With AI Chat Integration

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
LOG_FILE="/tmp/khongai_install.log"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

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

log_step() { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; log_message "STEP: $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; log_message "SUCCESS: $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; log_message "ERROR: $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; log_message "WARNING: $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; log_message "INFO: $1"; }

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    log_info "Detected OS: $OS $VER"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    
    # Start Docker service
    log_info "Starting Docker service..."
    sudo systemctl start docker || sudo service docker start
    
    # Enable Docker on boot
    log_info "Enabling Docker on boot..."
    sudo systemctl enable docker || sudo systemctl enable docker.service
    
    # Add user to docker group
    log_info "Adding user to docker group..."
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
    
    # Check if we need to refresh group
    if ! groups | grep -q docker; then
        log_warning "Please log out and log back in, or run: newgrp docker"
        log_warning "Then run the installer again"
        exit 0
    fi
}

# Install Node.js
install_nodejs() {
    log_step "Installing Node.js..."
    
    if command -v node &> /dev/null; then
        log_success "Node.js already installed: $(node --version)"
        return 0
    fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            rhel|centos|fedora|rocky|almalinux)
                log_info "Installing Node.js 20.x for RHEL/CentOS/Fedora..."
                curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
                sudo dnf install -y nodejs
                ;;
            ubuntu|debian|linuxmint)
                log_info "Installing Node.js 20.x for Ubuntu/Debian..."
                curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                sudo apt-get install -y nodejs
                ;;
            *)
                log_warning "Unsupported OS for automatic Node.js installation"
                return 1
                ;;
        esac
    fi
    
    if command -v node &> /dev/null; then
        log_success "Node.js installed: $(node --version)"
        log_success "npm installed: $(npm --version)"
    else
        log_error "Node.js installation failed"
        return 1
    fi
}

# Create Docker container
create_container() {
    log_step "Creating Docker container..."
    
    cd "$INSTALL_DIR"
    
    # Create docker-compose.yml
    cat > docker-compose.yml << 'EOF'
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
    
    # Pull image
    log_info "Pulling OpenClaw image..."
    docker pull ghcr.io/openclaw/openclaw:latest
    
    # Start container
    log_info "Starting container..."
    docker compose up -d
    
    # Wait for container to be ready
    sleep 5
    
    if docker ps | grep -q khongai; then
        log_success "Container is running"
        return 0
    else
        log_error "Container failed to start"
        docker logs khongai
        return 1
    fi
}

# Create Telegram bot with AI chat
create_telegram_bot() {
    log_step "Creating Telegram bot with AI chat..."
    
    local bot_dir="$HOME/khongai-telegram-bot"
    mkdir -p "$bot_dir"
    cd "$bot_dir"
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "khongai-telegram-bot",
  "version": "1.0.0",
  "description": "KhongAI Telegram Bot with AI Chat",
  "main": "bot.js",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "node-fetch": "^3.3.2"
  }
}
EOF
    
    # Install dependencies
    log_info "Installing dependencies..."
    npm install --production --silent 2>/dev/null || npm install --production
    
    # Create AI chat bot
    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const KHONGAI_API = 'http://localhost:18789';
const bot = new TelegramBot(token, { polling: true });

// Store conversation history (simple in-memory)
const conversations = new Map();

console.log('🤖 KhongAI Bot with AI Chat Started');
console.log('Bot token: ' + token.substring(0, 10) + '...');
console.log('API URL: ' + KHONGAI_API);

// Helper: Call KhongAI API
async function callKhongAI(message, userId) {
    try {
        // Get conversation history
        let history = conversations.get(userId) || [];
        
        // Add user message to history
        history.push({ role: 'user', content: message });
        
        // Keep last 10 messages for context
        if (history.length > 10) {
            history = history.slice(-10);
        }
        
        // Call OpenClaw API
        const response = await axios.post(`${KHONGAI_API}/chat`, {
            messages: history,
            temperature: 0.7,
            max_tokens: 500
        }, {
            timeout: 30000,
            headers: { 'Content-Type': 'application/json' }
        });
        
        if (response.data && response.data.response) {
            const aiResponse = response.data.response;
            
            // Add AI response to history
            history.push({ role: 'assistant', content: aiResponse });
            conversations.set(userId, history);
            
            return aiResponse;
        } else {
            return "I'm here! How can I help you today?";
        }
    } catch (error) {
        console.error('API Error:', error.message);
        
        if (error.code === 'ECONNREFUSED') {
            return "⚠️ KhongAI service is not running. Please start it with: ~/khongai-manager.sh start";
        } else if (error.response) {
            return `❌ API Error: ${error.response.status}\nPlease try again later.`;
        } else {
            return "🤖 I'm having trouble connecting. Please make sure KhongAI is running.";
        }
    }
}

// Helper: Check system health
async function checkHealth() {
    try {
        const response = await axios.get(`${KHONGAI_API}/health`, { timeout: 5000 });
        return response.status === 200;
    } catch {
        return false;
    }
}

// Command: /start
bot.onText(/\/start/, async (msg) => {
    const chatId = msg.chat.id;
    const username = msg.from.first_name || msg.from.username;
    const isHealthy = await checkHealth();
    
    const welcomeMessage = `🦙 *Welcome to KhongAI, ${username}!* 🦙

Your AI assistant is ready to chat with you!

✨ *Features:*
• 💬 Natural conversation
• 🧠 Context-aware responses
• ⚡ Fast replies
• 🔒 Private & secure

📋 *Commands:*
/chat [message] - Chat with AI (or just send any message)
/status - Check system status
/health - Detailed health check
/clear - Clear conversation history
/info - Bot information
/help - Show this help

💡 *Quick start:*
Just send me any message to start chatting!

*Example:*
"Hello, who are you?"
"What can you help me with?"
"Tell me a joke"

${isHealthy ? '✅ System: Online' : '⚠️ System: Offline'}

_Start chatting now!_ 🚀`;
    
    bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
});

// Handle all text messages (AI chat)
bot.onText(/^\/chat (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const message = match[1];
    
    bot.sendChatAction(chatId, 'typing');
    
    const aiResponse = await callKhongAI(message, chatId);
    bot.sendMessage(chatId, aiResponse, { parse_mode: 'Markdown' });
});

// Handle direct messages (without command)
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    
    // Skip commands
    if (!text || text.startsWith('/')) return;
    
    // Send typing indicator
    bot.sendChatAction(chatId, 'typing');
    
    // Get AI response
    const aiResponse = await callKhongAI(text, chatId);
    
    // Split long messages
    if (aiResponse.length > 4000) {
        for (let i = 0; i < aiResponse.length; i += 4000) {
            bot.sendMessage(chatId, aiResponse.substring(i, i + 4000));
        }
    } else {
        bot.sendMessage(chatId, aiResponse);
    }
});

// Command: /status
bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    const isHealthy = await checkHealth();
    
    const statusMessage = `📊 *KhongAI System Status*

${isHealthy ? '✅ Status: Online' : '❌ Status: Offline'}

*Details:*
• Service: OpenClaw Gateway
• API: ${KHONGAI_API}
• Bot: Active

*Commands:*
/health - Detailed health check
/info - Bot information
/clear - Clear conversation history

${isHealthy ? '🟢 System is operational' : '🔴 System is down. Run: ~/khongai-manager.sh start'}`;
    
    bot.sendMessage(chatId, statusMessage, { parse_mode: 'Markdown' });
});

// Command: /health
bot.onText(/\/health/, async (msg) => {
    const chatId = msg.chat.id;
    
    bot.sendMessage(chatId, '🩺 *Checking system health...*', { parse_mode: 'Markdown' });
    
    try {
        const response = await axios.get(`${KHONGAI_API}/health`, { timeout: 5000 });
        
        const healthMessage = `✅ *Health Check Passed*

*Status:* Healthy
*HTTP Code:* ${response.status}
*Response Time:* < 5s

*System Info:*
• API: Responding
• Bot: Active
• Memory: ${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB used

All systems operational! 🟢`;
        
        bot.sendMessage(chatId, healthMessage, { parse_mode: 'Markdown' });
    } catch (error) {
        const errorMessage = `❌ *Health Check Failed*

*Error:* ${error.code || error.message}
*Status:* Unreachable

*Troubleshooting:*
1. Check Docker: \`docker ps\`
2. View logs: \`~/khongai-manager.sh logs\`
3. Restart: \`~/khongai-manager.sh restart\`

Contact @khongtk2004 for support.`;
        
        bot.sendMessage(chatId, errorMessage, { parse_mode: 'Markdown' });
    }
});

// Command: /clear
bot.onText(/\/clear/, (msg) => {
    const chatId = msg.chat.id;
    conversations.delete(chatId);
    bot.sendMessage(chatId, '🗑️ *Conversation history cleared!*\n\nYou can start a fresh conversation now.', { parse_mode: 'Markdown' });
});

// Command: /info
bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    
    const infoMessage = `📊 *KhongAI Information*

*Version:* 1.0.0
*Type:* AI Assistant with Telegram Integration
*API:* OpenClaw Gateway

*Features:*
• AI Chat with context
• Multi-user support
• Conversation history
• Health monitoring

*Commands:* /start, /status, /health, /clear, /info, /help

*Links:*
• GitHub: @khongtk2004
• Support: @khongtk2004

*Stats:*
• Uptime: ${Math.round(process.uptime())} seconds
• Active conversations: ${conversations.size}
• Node version: ${process.version}`;
    
    bot.sendMessage(chatId, infoMessage, { parse_mode: 'Markdown' });
});

// Command: /help
bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    
    const helpMessage = `📚 *KhongAI Help Guide*

*Chat Commands:*
• \`/chat [message]\` - Chat with AI
• \`Just send any message\` - Direct chat

*System Commands:*
• \`/status\` - Check system status
• \`/health\` - Detailed health check
• \`/clear\` - Clear conversation history
• \`/info\` - Bot information
• \`/help\` - Show this help

*Tips:*
💡 The AI remembers context from your conversation
💡 Use /clear to start fresh
💡 Long responses are automatically split

*Examples:*
"Tell me about AI"
"What's the weather like?"
"Explain quantum computing"
"Tell me a fun fact"

*Need help?* Contact @khongtk2004

Start chatting now! 🚀`;
    
    bot.sendMessage(chatId, helpMessage, { parse_mode: 'Markdown' });
});

// Error handling
bot.on('polling_error', (error) => {
    console.error('Polling error:', error.message);
    if (error.message.includes('ETELEGRAM')) {
        console.log('Bot token might be invalid. Please check your token.');
    }
});

process.on('uncaughtException', (error) => {
    console.error('Uncaught exception:', error);
});

process.on('unhandledRejection', (error) => {
    console.error('Unhandled rejection:', error);
});

console.log('🚀 Bot is ready!');
console.log('💡 Send /start to your bot on Telegram');
console.log('✨ AI chat is now active!');
BOTEOF
    
    # Create start script
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
export TELEGRAM_BOT_TOKEN="${1:-$TELEGRAM_BOT_TOKEN}"
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN not set"
    echo "Usage: ./start.sh YOUR_BOT_TOKEN"
    exit 1
fi
pkill -f "node bot.js" 2>/dev/null
nohup node bot.js > bot.log 2>&1 &
echo $! > bot.pid
echo "Bot started with PID: $(cat bot.pid)"
sleep 2
if pgrep -f "node bot.js" > /dev/null; then
    echo "✅ Bot is running!"
    tail -5 bot.log
else
    echo "❌ Bot failed to start"
    cat bot.log
fi
EOF
    
    chmod +x start.sh
    
    # Create stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if [ -f bot.pid ]; then
    kill $(cat bot.pid) 2>/dev/null
    rm bot.pid
fi
pkill -f "node bot.js" 2>/dev/null
echo "Bot stopped"
EOF
    
    chmod +x stop.sh
    
    log_success "Telegram bot with AI chat created"
}

# Create management script
create_manager() {
    cat > ~/khongai-manager.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BOLD}KhongAI Status${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    # Docker container status
    echo -e "\n${BOLD}📦 Docker Container:${NC}"
    if docker ps | grep -q khongai; then
        echo -e "${GREEN}✓ Running${NC}"
        docker ps --filter "name=khongai" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "${RED}✗ Not running${NC}"
    fi
    
    # Bot status
    echo -e "\n${BOLD}🤖 Telegram Bot:${NC}"
    if pgrep -f "node bot.js" > /dev/null; then
        echo -e "${GREEN}✓ Running${NC}"
        ps aux | grep "node bot.js" | grep -v grep | awk '{print "  PID: " $2 " | CPU: " $3 "% | MEM: " $4 "%"}'
    else
        echo -e "${RED}✗ Not running${NC}"
    fi
    
    # API endpoint
    echo -e "\n${BOLD}🌐 API Endpoint:${NC}"
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Responding${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
    
    # Active conversations
    if pgrep -f "node bot.js" > /dev/null; then
        echo -e "\n${BOLD}💬 Active Conversations:${NC}"
        tail -20 ~/khongai-telegram-bot/bot.log | grep -c "Message from" || echo "0"
    fi
}

case "$1" in
    start)
        echo -e "${BLUE}Starting KhongAI...${NC}"
        cd ~/khongai && docker compose up -d
        sleep 3
        cd ~/khongai-telegram-bot && ./start.sh "$(cat ~/.khongai/bot-token.txt 2>/dev/null)"
        echo -e "${GREEN}✓ KhongAI started${NC}"
        ;;
    stop)
        echo -e "${BLUE}Stopping KhongAI...${NC}"
        cd ~/khongai && docker compose down
        cd ~/khongai-telegram-bot && ./stop.sh 2>/dev/null
        echo -e "${GREEN}✓ KhongAI stopped${NC}"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        show_status
        ;;
    logs)
        docker logs khongai --tail 50 -f
        ;;
    bot-start)
        cd ~/khongai-telegram-bot
        if [ -f ~/.khongai/bot-token.txt ]; then
            ./start.sh "$(cat ~/.khongai/bot-token.txt)"
        else
            echo -e "${RED}No bot token found${NC}"
        fi
        ;;
    bot-stop)
        cd ~/khongai-telegram-bot && ./stop.sh
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    bot-restart)
        $0 bot-stop
        sleep 2
        $0 bot-start
        ;;
    health)
        curl -s http://localhost:18789/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:18789/health
        ;;
    test)
        echo -e "${BLUE}Testing AI Chat...${NC}"
        curl -X POST http://localhost:18789/chat \
            -H "Content-Type: application/json" \
            -d '{"messages":[{"role":"user","content":"Hello"}],"temperature":0.7}' \
            2>/dev/null | python3 -m json.tool 2>/dev/null || echo "API not responding"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|bot-start|bot-stop|bot-restart|bot-logs|health|test}"
        exit 1
        ;;
esac
EOF
    
    chmod +x ~/khongai-manager.sh
    log_success "Management script created"
}

# Main installation
main() {
    print_banner
    detect_os
    
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
    
    # Save credentials
    mkdir -p ~/.khongai
    cat > ~/.khongai/bot-token.txt << EOF
$TELEGRAM_BOT_TOKEN
EOF
    cat > ~/.khongai/credentials.txt << EOF
========================================
KhongAI Installation
========================================
Date: $(date)
Bot Token: $TELEGRAM_BOT_TOKEN
Username: ${TELEGRAM_USERNAME:-Not set}
========================================
EOF
    chmod 600 ~/.khongai/*.txt
    
    # Create directories
    log_step "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p ~/.khongai/workspace
    mkdir -p ~/.khongai/logs
    
    # Check/Install Docker
    log_step "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        install_docker
    else
        log_success "Docker found"
        # Ensure user is in docker group
        if ! groups | grep -q docker; then
            log_info "Adding user to docker group..."
            sudo usermod -aG docker $USER
            log_warning "Please log out and back in, then run the installer again"
            exit 0
        fi
    fi
    
    # Verify Docker works
    if ! docker info &> /dev/null; then
        log_warning "Docker not accessible. Trying to start..."
        sudo systemctl start docker
        sleep 3
        if ! docker info &> /dev/null; then
            log_error "Cannot connect to Docker. Please check Docker service"
            exit 1
        fi
    fi
    
    # Pull and run container
    create_container
    
    # Install Node.js and create bot
    install_nodejs
    create_telegram_bot
    
    # Start bot with token
    cd ~/khongai-telegram-bot
    ./start.sh "$TELEGRAM_BOT_TOKEN"
    
    # Create manager script
    create_manager
    
    # Final output
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ KhongAI with AI Chat installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}📊 Dashboard:${NC} http://localhost:18789"
    echo -e "${CYAN}🤖 Telegram Bot:${NC} Send any message to chat with AI"
    echo -e "${CYAN}👤 Admin:${NC} @${TELEGRAM_USERNAME:-Not set}\n"
    
    echo -e "${BOLD}📝 Management Commands:${NC}"
    echo -e "  ${YELLOW}~/khongai-manager.sh status${NC}       - Check status"
    echo -e "  ${YELLOW}~/khongai-manager.sh restart${NC}      - Restart everything"
    echo -e "  ${YELLOW}~/khongai-manager.sh logs${NC}         - View container logs"
    echo -e "  ${YELLOW}~/khongai-manager.sh bot-logs${NC}     - View bot logs"
    echo -e "  ${YELLOW}~/khongai-manager.sh test${NC}         - Test AI chat API"
    echo -e "  ${YELLOW}~/khongai-manager.sh health${NC}       - Check API health\n"
    
    echo -e "${BOLD}💬 Telegram Bot Features:${NC}"
    echo -e "  • Send any message to chat with AI"
    echo -e "  • Commands: /start, /status, /health, /clear, /info"
    echo -e "  • AI remembers conversation context"
    echo -e "  • Supports long responses\n"
    
    echo -e "${BOLD}🔧 Directories:${NC}"
    echo -e "  KhongAI: ${YELLOW}~/khongai${NC}"
    echo -e "  Bot: ${YELLOW}~/khongai-telegram-bot${NC}"
    echo -e "  Data: ${YELLOW}~/.khongai${NC}\n"
    
    # Test connection
    sleep 3
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        log_success "KhongAI API is responding!"
    else
        log_warning "KhongAI API not responding yet"
        echo "Check with: ~/khongai-manager.sh logs"
    fi
    
    if pgrep -f "node bot.js" > /dev/null; then
        log_success "Telegram bot is running!"
        echo -e "\n${GREEN}🎉 Send any message to your Telegram bot to start chatting with AI!${NC}\n"
        echo -e "${CYAN}Example:${NC} \"Hello! Who are you?\""
        echo -e "${CYAN}Commands:${NC} /start, /status, /health, /clear\n"
    else
        log_warning "Bot not running. Start with: ~/khongai-manager.sh bot-start"
    fi
}

# Run main function
main "$@"
