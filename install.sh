#!/bin/bash
# KhongAI Installer with Telegram Bot Support
# Complete working version with directory creation fix

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

# Flags
NO_START=false
SKIP_ONBOARD=false
PULL_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-start)
            NO_START=true
            shift
            ;;
        --skip-onboard)
            SKIP_ONBOARD=true
            shift
            ;;
        --pull-only)
            PULL_ONLY=true
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "KhongAI Installer"
            echo ""
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR   Installation directory (default: ~/khongai)"
            echo "  --no-start          Don't start the gateway after setup"
            echo "  --skip-onboard      Skip onboarding wizard"
            echo "  --pull-only         Only pull the image, don't set up"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to get user home directory (handles sudo)
get_user_home() {
    if [ -n "$SUDO_USER" ]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -z "$user_home" ]; then
            user_home=$(eval echo ~"$SUDO_USER")
        fi
        echo "$user_home"
    else
        echo "$HOME"
    fi
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

log_step() {
    echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 found"
        return 0
    else
        log_error "$1 not found"
        return 1
    fi
}

check_docker() {
    log_step "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        echo -e "\n${YELLOW}Installing Docker...${NC}"
        
        # Detect OS and install Docker
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
        elif [ -f /etc/redhat-release ]; then
            # CentOS/RHEL/Fedora
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
        else
            log_error "Unsupported OS. Please install Docker manually: https://docs.docker.com/get-docker/"
            exit 1
        fi
        
        log_success "Docker installed"
        echo -e "${YELLOW}Please log out and back in, then run this script again${NC}"
        exit 0
    fi
    
    log_success "Docker is installed"
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        echo -e "${YELLOW}Starting Docker...${NC}"
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        sleep 2
    fi
    
    log_success "Docker is running"
}

check_docker_compose() {
    log_step "Checking Docker Compose..."
    
    if docker compose version &> /dev/null; then
        log_success "Docker Compose found (plugin)"
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        log_success "Docker Compose found (standalone)"
        COMPOSE_CMD="docker-compose"
    else
        log_error "Docker Compose not found"
        echo -e "\n${YELLOW}Installing Docker Compose plugin...${NC}"
        
        if [ -f /etc/debian_version ]; then
            sudo apt-get update && sudo apt-get install -y docker-compose-plugin
        elif [ -f /etc/redhat-release ]; then
            sudo dnf install -y docker-compose-plugin
        fi
        
        if docker compose version &> /dev/null; then
            log_success "Docker Compose installed"
            COMPOSE_CMD="docker compose"
        else
            log_error "Failed to install Docker Compose"
            exit 1
        fi
    fi
}

setup_environment() {
    log_step "Setting up environment..."
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    log_success "Created install directory: $INSTALL_DIR"
    
    # Prompt for Telegram bot token
    echo -e "${YELLOW}Enter your Telegram Bot Token (from @BotFather):${NC}"
    read -r TELEGRAM_BOT_TOKEN
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        log_error "Bot token is required!"
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
    
    log_success "Environment configured"
}

download_compose() {
    log_step "Downloading docker-compose.yml..."
    
    cd "$INSTALL_DIR"
    
    if curl -fsSL "$COMPOSE_URL" -o docker-compose.yml; then
        log_success "Downloaded docker-compose.yml"
    else
        log_error "Failed to download docker-compose.yml"
        exit 1
    fi
}

create_data_directories() {
    log_step "Creating data directories..."
    
    USER_HOME=$(get_user_home)
    KHONGAI_DIR="$USER_HOME/.khongai"
    
    mkdir -p "$KHONGAI_DIR"
    mkdir -p "$KHONGAI_DIR/workspace"
    mkdir -p "$KHONGAI_DIR/logs"
    
    # Fix permissions for container access
    if [ "$(id -u)" -eq 0 ]; then
        if [ -n "$SUDO_USER" ]; then
            SUDO_GID=$(id -g "$SUDO_USER")
            chown -R 1000:"$SUDO_GID" "$KHONGAI_DIR"
            chmod -R u+rwX,g+rwX,o-rwx "$KHONGAI_DIR"
        else
            chown -R 1000:1000 "$KHONGAI_DIR"
            chmod -R 755 "$KHONGAI_DIR"
        fi
    else
        chmod -R 775 "$KHONGAI_DIR" 2>/dev/null || chmod -R 777 "$KHONGAI_DIR"
    fi
    
    log_success "Created $KHONGAI_DIR (config)"
    log_success "Created $KHONGAI_DIR/workspace (workspace)"
    log_success "Created $KHONGAI_DIR/logs (logs)"
}

pull_image() {
    log_step "Pulling KhongAI Docker image..."
    
    if docker pull "$IMAGE"; then
        log_success "Image pulled successfully!"
    else
        log_error "Failed to pull image"
        exit 1
    fi
}

start_services() {
    log_step "Starting KhongAI services..."
    
    cd "$INSTALL_DIR"
    
    if $COMPOSE_CMD up -d; then
        log_success "Services started"
    else
        log_error "Failed to start services"
        exit 1
    fi
    
    # Wait for services to be ready
    echo -n "Waiting for services to start"
    for i in {1..30}; do
        if curl -s http://localhost:18789/health &> /dev/null; then
            echo ""
            log_success "KhongAI is ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    log_warning "Services may still be starting. Check logs with: docker logs khongai"
}

test_telegram_bot() {
    log_step "Testing Telegram bot connection..."
    
    # Get bot token from .env
    source "$INSTALL_DIR/.env"
    
    BOT_INFO=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe")
    
    if echo "$BOT_INFO" | grep -q '"ok":true'; then
        BOT_NAME=$(echo "$BOT_INFO" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
        log_success "Bot @$BOT_NAME is active"
        echo -e "${CYAN}ℹ️  Ask your admins to start the bot with /start${NC}"
    else
        log_warning "Failed to connect to Telegram bot"
        echo -e "${YELLOW}Please check your bot token${NC}"
    fi
}

show_completion() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║         🎉 KhongAI installed successfully! 🎉                ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    USER_HOME=$(get_user_home)
    KHONGAI_DIR="$USER_HOME/.khongai"
    
    echo -e "\n${BOLD}Quick reference:${NC}"
    echo -e "  ${CYAN}Dashboard:${NC}      http://localhost:18789"
    echo -e "  ${CYAN}Config dir:${NC}     $KHONGAI_DIR/"
    echo -e "  ${CYAN}Logs:${NC}           $KHONGAI_DIR/logs/"
    echo -e "  ${CYAN}Install dir:${NC}    $INSTALL_DIR"
    
    echo -e "\n${BOLD}Telegram Bot Commands:${NC}"
    echo -e "  ${CYAN}/status${NC}    - Check system status"
    echo -e "  ${CYAN}/model${NC}     - Change AI model"
    echo -e "  ${CYAN}/restart${NC}   - Restart KhongAI"
    echo -e "  ${CYAN}/logs${NC}      - View recent logs"
    echo -e "  ${CYAN}/help${NC}      - Show all commands"
    
    echo -e "\n${BOLD}Useful commands:${NC}"
    echo -e "  ${CYAN}View logs:${NC}      docker logs -f khongai"
    echo -e "  ${CYAN}Stop:${NC}           cd $INSTALL_DIR && $COMPOSE_CMD down"
    echo -e "  ${CYAN}Start:${NC}          cd $INSTALL_DIR && $COMPOSE_CMD up -d"
    echo -e "  ${CYAN}Restart:${NC}        docker restart khongai"
    echo -e "  ${CYAN}Update:${NC}         cd $INSTALL_DIR && $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
    
    echo -e "\n${BOLD}Documentation:${NC}  $REPO_URL"
    echo -e "${BOLD}Support:${NC}        Telegram: @khongtk"
    
    echo -e "\n${YELLOW}Happy building with KhongAI! 🤖🦙${NC}\n"
}

# Main execution
print_banner

# Check system requirements
log_step "Checking system requirements..."
if command -v free &> /dev/null; then
    echo -e "  RAM: $(free -h | awk '/^Mem:/ {print $2}')"
fi
if command -v df &> /dev/null; then
    echo -e "  Disk: $(df -h / | awk 'NR==2 {print $4}') free"
fi
echo ""

# Pull only mode
if [ "$PULL_ONLY" = true ]; then
    log_step "Pull only mode..."
    docker pull "$IMAGE"
    log_success "Image pulled successfully!"
    echo -e "\n${GREEN}Done!${NC} Run the installer again without --pull-only to complete setup."
    exit 0
fi

# Run installation steps
check_docker
check_docker_compose
setup_environment
download_compose
create_data_directories
pull_image
start_services
test_telegram_bot
show_completion
