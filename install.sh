#!/bin/bash
# KhongAI Installer - Complete Docker Setup

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

# Detect OS distribution
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

# Setup Docker service and permissions
setup_docker_service() {
    log_step "Setting up Docker service..."
    
    # Start Docker service
    log_info "Starting Docker service..."
    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || {
        log_error "Failed to start Docker service"
        return 1
    }
    log_success "Docker service started"
    
    # Enable Docker to start on boot
    log_info "Enabling Docker to start on boot..."
    sudo systemctl enable docker 2>/dev/null || sudo systemctl enable docker.service 2>/dev/null || {
        log_warning "Could not enable Docker service (non-critical)"
    }
    log_success "Docker enabled on boot"
    
    # Add user to docker group
    log_info "Adding user '$USER' to docker group..."
    sudo usermod -aG docker $USER
    log_success "User added to docker group"
    
    return 0
}

# Apply Docker group changes without logout
apply_docker_group() {
    log_info "Applying Docker group changes..."
    
    # Check if user is already in docker group
    if groups | grep -q docker; then
        log_success "User already in docker group"
        return 0
    fi
    
    # Try to apply group changes
    if command -v newgrp &> /dev/null; then
        log_info "Using newgrp to apply group changes..."
        # We'll need to run the rest of the script in a new group context
        if [ "$FORCE_NEWGRP" != "true" ]; then
            export FORCE_NEWGRP=true
            exec newgrp docker <<< "bash $0 $@"
            exit 0
        fi
    else
        log_warning "newgrp command not found"
        log_info "Please log out and log back in for Docker permissions to take effect"
        echo ""
        echo -e "${YELLOW}After logging back in, run:${NC}"
        echo "  bash <(curl -fsSL https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.sh)"
        echo ""
        exit 0
    fi
}

# Install Node.js based on OS
install_nodejs() {
    log_step "Checking Node.js installation..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_success "Node.js already installed: $NODE_VERSION"
        return 0
    fi
    
    log_info "Node.js not found. Installing..."
    
    case $OS in
        rhel|centos|fedora|rocky|almalinux)
            log_info "Installing Node.js 18.x for RHEL/CentOS/Fedora..."
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo dnf install -y nodejs
            ;;
        ubuntu|debian|linuxmint)
            log_info "Installing Node.js 18.x for Ubuntu/Debian..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        opensuse|suse)
            log_info "Installing Node.js for openSUSE..."
            sudo zypper install -y nodejs18
            ;;
        arch|manjaro)
            log_info "Installing Node.js for Arch Linux..."
            sudo pacman -S --noconfirm nodejs npm
            ;;
        *)
            log_warning "Unsupported OS for automatic Node.js installation: $OS"
            log_info "Please install Node.js 18+ manually from https://nodejs.org/"
            read -p "Press Enter after installing Node.js..."
            ;;
    esac
    
    # Verify installation
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_success "Node.js installed successfully: $NODE_VERSION"
        NPM_VERSION=$(npm --version)
        log_success "npm installed: $NPM_VERSION"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
}

# Check Docker accessibility
check_docker_access() {
    if docker info &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for Docker socket
wait_for_docker() {
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker info &> /dev/null; then
            log_success "Docker socket is accessible"
            return 0
        fi
        log_info "Waiting for Docker socket... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

print_banner

# Detect OS
detect_os

# Get Telegram credentials
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
    TELEGRAM_USERNAME="${TELEGRAM_USERNAME#@}"
    log_success "Username: @$TELEGRAM_USERNAME"
else
    log_info "No username provided (optional)"
fi

# Save credentials
mkdir -p ~/.khongai
cat > ~/.khongai/credentials.txt << EOF
========================================
KhongAI Installation Credentials
========================================
Date: $(date)
OS: $OS $VER
Telegram Bot Token: ${TELEGRAM_BOT_TOKEN}
Telegram Username: ${TELEGRAM_USERNAME}
========================================
EOF
chmod 600 ~/.khongai/credentials.txt

echo -e "\n${GREEN}✓ Telegram credentials saved${NC}"

log_step "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p ~/.khongai/workspace
mkdir -p ~/.khongai/logs

log_step "Checking Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker not installed. Installing..."
    curl -fsSL https://get.docker.com | sh
    
    # Setup Docker service and permissions
    setup_docker_service
    
    # Apply group changes
    apply_docker_group
    
    log_success "Docker installed and configured successfully!"
    
    # Verify Docker works
    if check_docker_access; then
        log_success "Docker is ready to use!"
    else
        log_warning "Docker installed but may need group refresh"
        log_info "Please run: newgrp docker"
        log_info "Then run the installer again"
        exit 0
    fi
else
    log_success "Docker found"
    
    # Ensure Docker service is running
    log_step "Ensuring Docker service is running..."
    if ! systemctl is-active --quiet docker 2>/dev/null && ! service docker status &>/dev/null; then
        log_info "Starting Docker service..."
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
    fi
    
    # Ensure Docker is enabled on boot
    sudo systemctl enable docker 2>/dev/null || true
    
    # Ensure user is in docker group
    if ! groups | grep -q docker; then
        log_info "Adding user to docker group..."
        sudo usermod -aG docker $USER
        apply_docker_group
    fi
fi

# Check Docker daemon status
log_step "Checking Docker daemon..."
if ! systemctl is-active --quiet docker 2>/dev/null && ! service docker status &>/dev/null; then
    log_info "Starting Docker daemon..."
    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || {
        log_error "Failed to start Docker. Please start Docker manually."
        exit 1
    }
fi

# Check Docker access
if ! check_docker_access; then
    log_warning "Cannot connect to Docker daemon"
    
    # Try to fix by starting Docker
    log_info "Attempting to start Docker daemon..."
    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
    
    # Wait for Docker socket
    if wait_for_docker; then
        log_success "Docker is now accessible"
    else
        log_error "Docker is not accessible after multiple attempts"
        echo "Please check:"
        echo "  - Docker service status: sudo systemctl status docker"
        echo "  - User groups: groups $USER"
        echo "  - Docker socket: ls -la /var/run/docker.sock"
        exit 1
    fi
fi

log_success "Docker is ready"

# Pull OpenClaw image with retry
log_step "Pulling OpenClaw image..."
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker pull ghcr.io/openclaw/openclaw:latest; then
        log_success "OpenClaw image pulled successfully"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_warning "Pull failed, retrying in 5 seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep 5
        else
            log_error "Failed to pull OpenClaw image after $MAX_RETRIES attempts"
            exit 1
        fi
    fi
done

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
docker compose up -d

# Wait for container to be ready
sleep 10
if docker ps | grep -q khongai; then
    log_success "KhongAI is running!"
else
    log_error "Failed to start KhongAI"
    echo "Container logs:"
    docker logs khongai
    exit 1
fi

# Install Node.js for the bot
install_nodejs

log_step "Setting up Telegram bot..."

# Create bot directory
mkdir -p ~/khongai-telegram-bot
cd ~/khongai-telegram-bot

# Initialize npm project
cat > package.json << EOF
{
  "name": "khongai-telegram-bot",
  "version": "1.0.0",
  "description": "KhongAI Telegram Bot",
  "main": "bot.js",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0"
  }
}
EOF

# Install dependencies
log_info "Installing Node.js dependencies..."
npm install --silent 2>/dev/null || npm install

# Create bot with the provided token
cat > bot.js << EOF
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

const token = '${TELEGRAM_BOT_TOKEN}';
const bot = new TelegramBot(token, { polling: true });
const KHONGAI_URL = 'http://localhost:18789';
const ADMIN_USERNAME = '${TELEGRAM_USERNAME}';

console.log('🤖 KhongAI Telegram Bot Starting...');
console.log('📱 Bot Token: ' + token.substring(0, 10) + '...');
console.log('👤 Admin: @' + (ADMIN_USERNAME || 'Not set'));

bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
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

bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    try {
        const response = await axios.get(\`\${KHONGAI_URL}/health\`, { timeout: 5000 });
        if (response.status === 200) {
            bot.sendMessage(chatId, '✅ *KhongAI is running!*', { parse_mode: 'Markdown' });
        } else {
            bot.sendMessage(chatId, '⚠️ *KhongAI is responding but status unclear*', { parse_mode: 'Markdown' });
        }
    } catch (error) {
        bot.sendMessage(chatId, '❌ *Cannot connect to KhongAI*\\n\\nMake sure the server is running.', { parse_mode: 'Markdown' });
    }
});

bot.onText(/\/health/, async (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, '🩺 *Checking KhongAI Health...*', { parse_mode: 'Markdown' });
    
    try {
        const response = await axios.get(\`\${KHONGAI_URL}/health\`, { timeout: 5000 });
        const healthMessage = \`
✅ *KhongAI Health Check*

Status: Healthy
HTTP Code: \${response.status}
Response Time: < 5s

*Details:*
\`\`\`json
\${JSON.stringify(response.data, null, 2)}
\`\`\`
        \`;
        bot.sendMessage(chatId, healthMessage, { parse_mode: 'Markdown' });
    } catch (error) {
        bot.sendMessage(chatId, '❌ *KhongAI Unreachable*\\n\\nCheck if Docker is running.', { parse_mode: 'Markdown' });
    }
});

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

bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, 'Send /start to see available commands');
});

bot.on('polling_error', (error) => {
    console.log('Polling error:', error.code);
});

console.log('🚀 Bot is polling for messages...');
console.log('💡 Send /start to your bot on Telegram');
EOF

# Create start script
cat > start-bot.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
pkill -f "node bot.js" 2>/dev/null || true
nohup node bot.js > bot.log 2>&1 &
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
fi
pkill -f "node bot.js" 2>/dev/null
echo "Bot stopped"
EOF

chmod +x stop-bot.sh

# Start the bot
log_step "Starting Telegram bot..."
./start-bot.sh

sleep 3
if pgrep -f "node bot.js" > /dev/null; then
    log_success "Telegram bot started successfully!"
else
    log_warning "Bot may not have started properly. Checking logs..."
    tail -20 bot.log
fi

# Create management script
cat > ~/khongai-manager.sh << 'EOF'
#!/bin/bash
# KhongAI Management Script

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${BLUE}Starting KhongAI...${NC}"
        cd ~/khongai && docker compose up -d
        cd ~/khongai-telegram-bot && ./start-bot.sh
        ;;
    stop)
        echo -e "${BLUE}Stopping KhongAI...${NC}"
        cd ~/khongai && docker compose down
        cd ~/khongai-telegram-bot && ./stop-bot.sh
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo -e "${BLUE}KhongAI Status:${NC}"
        docker ps | grep khongai || echo "Not running"
        echo -e "\n${BLUE}Bot Status:${NC}"
        pgrep -f "node bot.js" > /dev/null && echo "Bot running" || echo "Bot not running"
        ;;
    logs)
        docker logs khongai --tail 50
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    health)
        curl -s http://localhost:18789/health | jq . 2>/dev/null || curl -s http://localhost:18789/health
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|bot-logs|health}"
        exit 1
        ;;
esac
EOF

chmod +x ~/khongai-manager.sh

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
echo -e "  ${YELLOW}~/khongai-manager.sh bot-logs${NC}   - View bot logs"
echo -e "  ${YELLOW}~/khongai-manager.sh health${NC}     - Check health\n"

echo -e "${BOLD}🔧 Bot Directory:${NC} ~/khongai-telegram-bot"
echo -e "${BOLD}📁 Credentials saved:${NC} ~/.khongai/credentials.txt\n"

# Test connection
sleep 2
echo -e "${CYAN}Testing KhongAI connection...${NC}"
if curl -s http://localhost:18789/health > /dev/null 2>&1; then
    log_success "KhongAI is responding!"
else
    log_warning "KhongAI not responding yet. It may take a few moments."
    echo "Check with: ~/khongai-manager.sh logs"
fi

# Test bot
if pgrep -f "node bot.js" > /dev/null; then
    log_success "Telegram bot is running and waiting for messages!"
    echo -e "\n${GREEN}🎉 Send /start to your Telegram bot to begin!${NC}\n"
else
    log_warning "Bot not running. Check with: ~/khongai-manager.sh bot-logs"
fi
