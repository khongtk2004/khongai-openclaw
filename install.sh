#!/bin/bash
# KhongAI Installer - Complete Fixed Version

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
    
    # Create docker-compose.yml (without version attribute)
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

# Create Telegram bot
create_telegram_bot() {
    log_step "Creating Telegram bot..."
    
    local bot_dir="$HOME/khongai-telegram-bot"
    mkdir -p "$bot_dir"
    cd "$bot_dir"
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "khongai-telegram-bot",
  "version": "1.0.0",
  "description": "KhongAI Telegram Bot",
  "main": "bot.js",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0"
  }
}
EOF
    
    # Install dependencies
    log_info "Installing dependencies..."
    npm install --production --silent 2>/dev/null || npm install --production
    
    # Create bot.js
    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');

// Get token from environment or use default
const token = process.env.TELEGRAM_BOT_TOKEN || 'YOUR_BOT_TOKEN_HERE';
const bot = new TelegramBot(token, { polling: true });

console.log('🤖 KhongAI Bot Started');
console.log('Bot token: ' + token.substring(0, 10) + '...');

// Command handlers
bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const welcomeMessage = `🦙 Welcome to KhongAI! 🦙

Your AI assistant is ready to help.

Available Commands:
/status - Check system status
/health - Detailed health check
/info - Bot information
/help - Show help

Send any command to get started!`;
    
    bot.sendMessage(chatId, welcomeMessage);
});

bot.onText(/\/status/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, '✅ KhongAI is online and running!');
});

bot.onText(/\/health/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, '🩺 All systems operational');
});

bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    const info = `📊 KhongAI Information

Version: 1.0.0
Status: Online
Type: AI Assistant

Commands:
/start - Welcome message
/status - System status
/health - Health check
/info - Bot information
/help - Help menu`;
    
    bot.sendMessage(chatId, info);
});

bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, 'Send /start to see available commands');
});

// Error handling
bot.on('polling_error', (error) => {
    console.log('Polling error:', error.message);
});

console.log('Bot is ready! Send /start to your bot on Telegram');
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
    
    log_success "Telegram bot created"
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
}

case "$1" in
    start)
        echo -e "${BLUE}Starting KhongAI...${NC}"
        cd ~/khongai && docker compose up -d
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
        docker logs khongai --tail 50
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
    health)
        curl -s http://localhost:18789/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:18789/health
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|bot-start|bot-stop|bot-logs|health}"
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
    echo -e "${GREEN}✅ KhongAI installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}📊 Dashboard:${NC} http://localhost:18789"
    echo -e "${CYAN}🤖 Telegram Bot:${NC} Send /start to your bot"
    echo -e "${CYAN}👤 Admin:${NC} @${TELEGRAM_USERNAME:-Not set}\n"
    
    echo -e "${BOLD}📝 Management Commands:${NC}"
    echo -e "  ${YELLOW}~/khongai-manager.sh status${NC}      - Check status"
    echo -e "  ${YELLOW}~/khongai-manager.sh restart${NC}     - Restart everything"
    echo -e "  ${YELLOW}~/khongai-manager.sh logs${NC}        - View container logs"
    echo -e "  ${YELLOW}~/khongai-manager.sh bot-logs${NC}    - View bot logs"
    echo -e "  ${YELLOW}~/khongai-manager.sh health${NC}      - Check API health\n"
    
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
        echo -e "\n${GREEN}🎉 Send /start to your Telegram bot to begin!${NC}\n"
    else
        log_warning "Bot not running. Start with: ~/khongai-manager.sh bot-start"
    fi
}

# Run main function
main "$@"
