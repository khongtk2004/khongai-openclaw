#!/bin/bash
# KhongAI Uninstaller

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${KHONGAI_INSTALL_DIR:-$HOME/khongai}"
IMAGE="ghcr.io/khongtk2004/khongai-openclaw:latest"

KEEP_DATA=false
KEEP_IMAGE=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --keep-image)
            KEEP_IMAGE=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "KhongAI Uninstaller"
            echo ""
            echo "Usage: uninstall.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR   Installation directory (default: ~/khongai)"
            echo "  --keep-data         Keep configuration and workspace data"
            echo "  --keep-image        Keep Docker image"
            echo "  --force, -f         Skip confirmation prompts"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

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
    echo "║            Docker Uninstaller by KhongAI                      ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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

log_step() {
    echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    while true; do
        read -p "$(echo -e "${YELLOW}$prompt${NC}")" -r response
        response=${response:-$default}
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

print_banner

echo -e "${YELLOW}This will uninstall KhongAI from your system.${NC}"
echo ""

log_step "Stopping and removing containers..."

CONTAINERS_REMOVED=false
if docker ps -a --format '{{.Names}}' | grep -q "khongai"; then
    docker stop khongai 2>/dev/null || true
    docker rm khongai 2>/dev/null || true
    log_success "Removed khongai container"
    CONTAINERS_REMOVED=true
fi

if [ "$CONTAINERS_REMOVED" = false ]; then
    log_warning "No KhongAI containers found"
fi

USER_HOME=$(get_user_home)
KHONGAI_DIR="$USER_HOME/.khongai"

if [ "$KEEP_DATA" = false ] && [ -d "$KHONGAI_DIR" ]; then
    log_step "Data directories found at $KHONGAI_DIR"
    
    if confirm "Remove configuration and workspace data? (This cannot be undone)"; then
        rm -rf "$KHONGAI_DIR"
        log_success "Removed data directory: $KHONGAI_DIR"
    else
        log_warning "Keeping data directory: $KHONGAI_DIR"
    fi
elif [ "$KEEP_DATA" = true ] && [ -d "$KHONGAI_DIR" ]; then
    log_warning "Keeping data directory: $KHONGAI_DIR"
fi

if [ "$KEEP_IMAGE" = false ]; then
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$IMAGE"; then
        log_step "Docker image found: $IMAGE"
        
        if confirm "Remove Docker image? (You can re-download it later)"; then
            docker rmi "$IMAGE" 2>/dev/null || log_warning "Could not remove image (may be in use)"
            log_success "Removed Docker image"
        else
            log_warning "Keeping Docker image: $IMAGE"
        fi
    else
        log_warning "No Docker image found: $IMAGE"
    fi
else
    log_warning "Keeping Docker image: $IMAGE"
fi

if [ -d "$INSTALL_DIR" ]; then
    log_step "Installation directory found at $INSTALL_DIR"
    
    if confirm "Remove installation directory?"; then
        rm -rf "$INSTALL_DIR"
        log_success "Removed installation directory: $INSTALL_DIR"
    else
        log_warning "Keeping installation directory: $INSTALL_DIR"
    fi
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║         KhongAI has been uninstalled successfully! 👋        ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

if [ "$KEEP_DATA" = true ] || [ -d "$KHONGAI_DIR" ]; then
    echo -e "\n${BOLD}Data preserved:${NC}"
    echo -e "  ${CYAN}Config:${NC}         $KHONGAI_DIR"
fi

echo -e "\n${BOLD}To reinstall KhongAI:${NC}"
echo -e "  ${CYAN}bash <(curl -fsSL https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.sh)${NC}"

echo -e "\n${YELLOW}Thank you for using KhongAI! 🦙${NC}\n"