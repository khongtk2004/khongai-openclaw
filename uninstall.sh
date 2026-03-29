#!/bin/bash
# KhongAI Uninstaller for Linux

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
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║         ██╗  ██╗ ██████╗ ███╗   ██╗ ██████╗                  ║"
    echo "║         ██║  ██║██╔═══██╗████╗  ██║██╔════╝                  ║"
    echo "║         ███████║██║   ██║██╔██╗ ██║██║  ███╗                 ║"
    echo "║         ██╔══██║██║   ██║██║╚██╗██║██║   ██║                 ║"
    echo "║         ██║  ██║╚██████╔╝██║ ╚████║╚██████╔╝                 ║"
    echo "║         ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝                  ║"
    echo "║                                                              ║"
    echo "║                 KhongAI Uninstaller                           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step() { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

confirm_uninstall() {
    echo -e "\n${RED}${BOLD}WARNING: This will completely remove KhongAI and all data!${NC}"
    echo -e "${YELLOW}This includes:${NC}"
    echo "  - Docker containers and images"
    echo "  - Configuration files"
    echo "  - Telegram bot files"
    echo "  - Workspace data"
    echo "  - Logs"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
}

print_banner
confirm_uninstall

# Stop and remove Docker container
log_step "Stopping and removing Docker container..."
if sudo docker ps -a | grep -q khongai; then
    sudo docker stop khongai 2>/dev/null || true
    sudo docker rm khongai 2>/dev/null || true
    log_success "Docker container removed"
else
    log_info "No Docker container found"
fi

# Remove Docker image (optional)
read -p "Remove OpenClaw Docker image as well? (yes/no): " remove_image
if [[ "$remove_image" == "yes" ]]; then
    log_step "Removing Docker image..."
    sudo docker rmi ghcr.io/openclaw/openclaw:latest 2>/dev/null || true
    log_success "Docker image removed"
fi

# Stop Telegram bot
log_step "Stopping Telegram bot..."
pkill -f "node bot.js" 2>/dev/null || true
log_success "Bot stopped"

# Remove installation directories
log_step "Removing installation directories..."

# KhongAI main directory
if [ -d "$HOME/khongai" ]; then
    rm -rf "$HOME/khongai"
    log_success "Removed $HOME/khongai"
fi

# KhongAI data directory
if [ -d "$HOME/.khongai" ]; then
    rm -rf "$HOME/.khongai"
    log_success "Removed $HOME/.khongai"
fi

# Telegram bot directory
if [ -d "$HOME/khongai-telegram-bot" ]; then
    rm -rf "$HOME/khongai-telegram-bot"
    log_success "Removed $HOME/khongai-telegram-bot"
fi

# Remove management script
if [ -f "$HOME/khongai-manager.sh" ]; then
    rm -f "$HOME/khongai-manager.sh"
    log_success "Removed management script"
fi

# Remove docker-compose file
if [ -f "$HOME/khongai/docker-compose.yml" ]; then
    rm -f "$HOME/khongai/docker-compose.yml"
fi

# Clean up Docker volumes (optional)
read -p "Remove Docker volumes as well? (yes/no): " remove_volumes
if [[ "$remove_volumes" == "yes" ]]; then
    log_step "Removing Docker volumes..."
    sudo docker volume prune -f 2>/dev/null || true
    log_success "Docker volumes cleaned"
fi

# Final output
echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ KhongAI has been successfully uninstalled!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Note: The following items were NOT removed:${NC}"
echo "  - Node.js (if installed separately)"
echo "  - Docker (if installed separately)"
echo "  - npm packages (system-wide)"
echo ""
echo -e "${CYAN}To manually remove Docker:${NC}"
echo "  https://docs.docker.com/engine/install/ubuntu/#uninstall-docker-engine"
echo ""
echo -e "${CYAN}To manually remove Node.js:${NC}"
echo "  sudo apt-get remove nodejs npm"
echo ""

log_success "Uninstall complete!"f
