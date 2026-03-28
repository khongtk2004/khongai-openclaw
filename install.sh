#!/bin/bash
# KhongAI Installer with Telegram Bot Support

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
IMAGE="ghcr.io/khongtk2004/khongai-openclaw:latest"
REPO_URL="https://github.com/khongtk2004/khongai-openclaw"
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

check_docker() {
    echo -e "\n${BLUE}▶ Checking Docker installation...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        echo -e "${YELLOW}Installing Docker...${NC}"
        
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        
        echo -e "${GREEN}✓ Docker installed${NC}"
        echo -e "${YELLOW}Please log out and back in, then run this script again${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}✓ Docker is installed${NC}"
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}✗ Docker is not running${NC}"
        echo -e "${YELLOW}Starting Docker...${NC}"
        sudo systemctl start docker || sudo service docker start
        sleep 2
    fi
    
    echo -e "${GREEN}✓ Docker is running${NC}"
}

check_docker_compose() {
    echo -e "\n${BLUE}▶ Checking Docker Compose...${NC}"
    
    if ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Installing Docker Compose plugin...${NC}"
        sudo apt-get update && sudo apt-get install -y docker-compose-plugin
    fi
    
    echo -e "${GREEN}✓ Docker Compose is available${NC}"
}

setup_environment() {
    echo -e "\n${BLUE}▶ Setting up environment...${NC}"
    
    # Prompt for Telegram bot token
    echo -e "${YELLOW}Enter your Telegram Bot Token (from @BotFather):${NC}"
    read -r TELEGRAM_BOT_TOKEN
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo -e "${RED}Bot token is required!${NC}"
        exit 1
    fi
    
    # Prompt for admin usernames
    echo -e "${YELLOW}Enter admin usernames (comma-separated, e.g., @khongtk,@renyu4444):${NC}"
    read -r ADMIN_USER_IDS
    
    if [ -z "$ADMIN_USER_IDS" ]; then
        ADMIN_USER_IDS="@khongtk,@renyu4444"
        echo -e "${YELLOW}Using default admins: $ADMIN_USER_IDS${NC}"
    fi
    
    # Create .env file
    cat > "$INSTALL_DIR/.env" << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
ADMIN_USER_IDS=$ADMIN_USER_IDS
KHONGAI_VERSION=latest
EOF
    
    echo -e "${GREEN}✓ Environment configured${NC}"
}

install_khongai() {
    echo -e "\n${BLUE}▶ Installing KhongAI...${NC}"
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
    
    mkdir -p ~/.khongai/{workspace,logs}
    
    echo -e "${YELLOW}Pulling KhongAI Docker image...${NC}"
    docker pull "$IMAGE"
    
    echo -e "${YELLOW}Starting KhongAI services...${NC}"
    docker compose up -d
    
    echo -e "${YELLOW}Waiting for services to start...${NC}"
    sleep 10
    
    if docker ps | grep -q khongai; then
        echo -e "${GREEN}✓ KhongAI is running${NC}"
    else
        echo -e "${RED}✗ KhongAI failed to start${NC}"
        docker compose logs
        exit 1
    fi
}

test_telegram_bot() {
    echo -e "\n${BLUE}▶ Testing Telegram bot connection...${NC}"
    
    # Get bot token from .env
    source "$INSTALL_DIR/.env"
    
    BOT_INFO=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe")
    
    if echo "$BOT_INFO" | grep -q '"ok":true'; then
        BOT_NAME=$(echo "$BOT_INFO" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✓ Bot @$BOT_NAME is active${NC}"
        echo -e "${CYAN}ℹ️  Ask your admins to start the bot with /start${NC}"
    else
        echo -e "${RED}✗ Failed to connect to Telegram bot${NC}"
        echo -e "${YELLOW}Please check your bot token${NC}"
    fi
}

show_completion() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║         🎉 KhongAI installed successfully! 🎉                ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BOLD}Quick reference:${NC}"
    echo -e "  ${CYAN}Dashboard:${NC}      http://localhost:18789"
    echo -e "  ${CYAN}Config dir:${NC}     ~/.khongai/"
    echo -e "  ${CYAN}Logs:${NC}           ~/.khongai/logs/"
    
    echo -e "\n${BOLD}Telegram Bot Commands:${NC}"
    echo -e "  ${CYAN}/status${NC}    - Check system status"
    echo -e "  ${CYAN}/model${NC}     - Change AI model"
    echo -e "  ${CYAN}/restart${NC}   - Restart KhongAI"
    echo -e "  ${CYAN}/logs${NC}      - View recent logs"
    echo -e "  ${CYAN}/help${NC}      - Show all commands"
    
    echo -e "\n${BOLD}Useful commands:${NC}"
    echo -e "  ${CYAN}View logs:${NC}      docker logs -f khongai"
    echo -e "  ${CYAN}Stop:${NC}           cd $INSTALL_DIR && docker compose down"
    echo -e "  ${CYAN}Start:${NC}          cd $INSTALL_DIR && docker compose up -d"
    echo -e "  ${CYAN}Restart:${NC}        docker restart khongai"
    
    echo -e "\n${YELLOW}Happy building with KhongAI! 🤖🦙${NC}\n"
}

# Main execution
print_banner

echo -e "${BLUE}▶ Checking system requirements...${NC}"
echo -e "  RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo -e "  Disk: $(df -h / | awk 'NR==2 {print $4}') free"
echo ""

check_docker
check_docker_compose

setup_environment
install_khongai
test_telegram_bot
show_completion