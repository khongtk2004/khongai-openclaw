#!/bin/bash
set -euo pipefail

# OpenClaw Installer for macOS and Linux with Khong AI integration
# Fixed for CentOS Stream 10

BOLD='\033[1m'
ACCENT='\033[38;2;255;77;77m'
INFO='\033[38;2;136;146;176m'
SUCCESS='\033[38;2;0;229;204m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;230;57;70m'
MUTED='\033[38;2;90;100;128m'
GOLD='\033[38;2;255;215;0m'
PURPLE='\033[38;2;156;94;222m'
CYAN='\033[38;2;0;255;255m'
NC='\033[0m'

# Khong AI Banner
KHONG_BANNER="${CYAN}${BOLD}
 __   .__                           
|  | _|  |__   ____   ____    ____  
|  |/ /  |  \ /  _ \ /    \  / ___\ 
|    <|   Y  (  <_> )   |  \/ /_/  >
|__|_ \___|  /\____/|___|  /\___  / 
     \/    \/            \//_____/  
${NC}${PURPLE}${BOLD}         AI-Powered Terminal Assistant • Ollama Integrated${NC}
${MUTED}              Empowering your shell with local intelligence${NC}
${GOLD}                    Made with 🦞 for Khong${NC}
"

DEFAULT_TAGLINE="All your chats, one OpenClaw with Khong AI."

ORIGINAL_PATH="${PATH:-}"
TMPFILES=()
OS=""
VERBOSE=0
NO_PROMPT=0
DRY_RUN=0
NO_ONBOARD=0
INSTALL_METHOD="npm"
OPENCLAW_VERSION="latest"
USE_BETA=0
GIT_DIR="${HOME}/openclaw"
GIT_UPDATE=1
SKIP_OLLAMA=0

cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -rf "$f" 2>/dev/null || true
    done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

detect_downloader() {
    if command -v curl &> /dev/null; then
        echo "curl"
        return 0
    fi
    if command -v wget &> /dev/null; then
        echo "wget"
        return 0
    fi
    return 1
}

download_file() {
    local url="$1"
    local output="$2"
    local downloader
    downloader="$(detect_downloader)"
    if [[ "$downloader" == "curl" ]]; then
        curl -fsSL --retry 3 -o "$output" "$url"
    elif [[ "$downloader" == "wget" ]]; then
        wget -q --tries=3 -O "$output" "$url"
    else
        return 1
    fi
}

ui_info() { echo -e "${MUTED}·${NC} $*"; }
ui_warn() { echo -e "${WARN}!${NC} $*"; }
ui_success() { echo -e "${SUCCESS}✓${NC} $*"; }
ui_error() { echo -e "${ERROR}✗${NC} $*"; }
ui_section() { echo -e "\n${ACCENT}${BOLD}$*${NC}"; }
ui_stage() { echo -e "\n${ACCENT}${BOLD}$*${NC}"; }
ui_kv() { echo -e "${MUTED}$1:${NC} $2"; }

print_installer_banner() {
    echo -e "$KHONG_BANNER"
    echo -e "${INFO}${DEFAULT_TAGLINE}${NC}\n"
}

# Fixed Node.js installation for CentOS Stream 10
install_node_centos() {
    ui_info "Installing Node.js 22+ on CentOS Stream 10..."
    
    # Install Node.js 22.x from NodeSource
    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
    
    # Install Node.js
    dnf install -y nodejs
    
    # Verify installation
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node -v)
        ui_success "Node.js ${node_version} installed successfully"
        return 0
    else
        ui_error "Node.js installation failed"
        return 1
    fi
}

# Install Node.js based on OS
install_node() {
    if [[ "$OS" == "macos" ]]; then
        ui_info "Installing Node.js via Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
        brew install node@22
        brew link node@22 --overwrite --force
        export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
    elif [[ "$OS" == "linux" ]]; then
        # Detect distribution
        if grep -qi "centos\|rhel\|fedora" /etc/os-release 2>/dev/null; then
            install_node_centos
        elif command -v apt-get &> /dev/null; then
            ui_info "Installing Node.js via NodeSource (Debian/Ubuntu)"
            curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
            apt-get install -y nodejs
        else
            ui_error "Unsupported Linux distribution"
            return 1
        fi
    fi
    
    # Refresh PATH
    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
    hash -r
    
    # Verify Node.js is available
    if command -v node &> /dev/null; then
        ui_success "Node.js $(node -v) installed and available"
        return 0
    else
        ui_error "Node.js installation failed - command not found"
        return 1
    fi
}

# Check Node.js version
check_node() {
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$node_version" -ge 22 ]]; then
            ui_success "Node.js $(node -v) found"
            return 0
        else
            ui_info "Node.js $(node -v) found, upgrading to v22+"
            return 1
        fi
    fi
    ui_info "Node.js not found, installing..."
    return 1
}

# Install build tools for CentOS
install_build_tools_centos() {
    ui_info "Installing build tools..."
    dnf install -y gcc gcc-c++ make cmake python3 git curl
    ui_success "Build tools installed"
}

# System-specific model recommendations
get_system_model_recommendation() {
    local total_ram total_cores
    total_ram=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    total_cores=$(nproc 2>/dev/null || echo "1")
    total_ram_gb=$((total_ram / 1024 / 1024))
    
    if [[ $total_ram_gb -ge 16 ]]; then
        echo "qwen2.5:14b|llama3.3:8b|mistral:7b"
    elif [[ $total_ram_gb -ge 8 ]]; then
        echo "qwen2.5:7b|llama3.2:3b|phi3:3.8b"
    else
        echo "llama3.2:1b|phi3:3.8b|qwen2.5:1.5b"
    fi
}

# Ollama setup
setup_ollama() {
    ui_section "🦙 Khong AI - Ollama Integration"
    
    # Install Ollama
    if ! command -v ollama &> /dev/null; then
        ui_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        ui_success "Ollama installed"
    else
        ui_success "Ollama already installed"
    fi
    
    # Start Ollama
    ui_info "Starting Ollama service..."
    systemctl start ollama 2>/dev/null || ollama serve >/dev/null 2>&1 &
    sleep 5
    
    # Detect system
    local total_ram total_cores
    total_ram=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    total_cores=$(nproc 2>/dev/null || echo "1")
    total_ram_gb=$((total_ram / 1024 / 1024))
    
    echo ""
    ui_info "${GOLD}System Hardware:${NC}"
    ui_kv "RAM" "${total_ram_gb}GB"
    ui_kv "CPU Cores" "$total_cores"
    
    # Get recommended models
    local recommended_models
    recommended_models=$(get_system_model_recommendation)
    IFS='|' read -ra MODELS <<< "$recommended_models"
    
    echo ""
    ui_info "${GOLD}Recommended models for your system:${NC}"
    for i in "${!MODELS[@]}"; do
        echo "  $((i+1))) ${MODELS[$i]}"
    done
    
    # Select model
    local selected_model=""
    if [[ "$NO_PROMPT" != "1" ]]; then
        echo ""
        echo -e "${INFO}Select model (1-${#MODELS[@]}):${NC}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#MODELS[@]} ]; then
            selected_model="${MODELS[$((choice-1))]}"
        else
            selected_model="${MODELS[0]}"
        fi
    else
        selected_model="${MODELS[0]}"
        ui_info "Auto-selecting: $selected_model"
    fi
    
    # Install model
    if [[ -n "$selected_model" ]]; then
        ui_info "Installing $selected_model (this may take a few minutes)..."
        ollama pull "$selected_model"
        ui_success "Model installed: $selected_model"
    fi
    
    # Configure OpenClaw
    mkdir -p "$HOME/.openclaw"
    cat > "$HOME/.openclaw/ollama.json" << EOF
{
  "ollama": {
    "host": "http://localhost:11434",
    "default_model": "$selected_model"
  },
  "khong_ai": {
    "enabled": true,
    "model": "$selected_model"
  }
}
EOF
    
    echo ""
    ui_success "Khong AI configured with $selected_model"
    echo -e "\n${GOLD}Quick commands:${NC}"
    echo "  ollama run $selected_model  # Chat with Khong AI"
    echo "  ollama list                  # List installed models"
}

# Install OpenClaw via npm
install_openclaw() {
    ui_section "Installing OpenClaw"
    
    # Install OpenClaw globally
    npm install -g openclaw@latest
    
    if command -v openclaw &> /dev/null; then
        ui_success "OpenClaw installed: $(openclaw --version)"
    else
        ui_warn "OpenClaw installed but not in PATH"
        export PATH="$HOME/.npm-global/bin:$PATH"
    fi
}

# Main installation
main() {
    print_installer_banner
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        ui_success "Detected: CentOS Stream 10 / Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        ui_success "Detected: macOS"
    else
        ui_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    
    # Install build tools for CentOS
    if [[ "$OS" == "linux" ]]; then
        if grep -qi "centos\|rhel\|fedora" /etc/os-release 2>/dev/null; then
            install_build_tools_centos
        fi
    fi
    
    # Install Node.js
    ui_stage "[1/3] Installing Node.js"
    if ! check_node; then
        if ! install_node; then
            ui_error "Failed to install Node.js"
            ui_info "Please install Node.js 22+ manually: https://nodejs.org"
            exit 1
        fi
    fi
    
    # Setup Ollama
    if [[ "$SKIP_OLLAMA" != "1" ]]; then
        ui_stage "[2/3] Setting up Ollama"
        setup_ollama
    fi
    
    # Install OpenClaw
    ui_stage "[3/3] Installing OpenClaw"
    install_openclaw
    
    # Final message
    echo ""
    ui_celebrate "🎉 Khong AI + OpenClaw installed successfully!"
    echo ""
    ui_info "Next steps:"
    echo "  1. Run 'openclaw onboard' to configure"
    echo "  2. Run 'ollama list' to see available models"
    echo "  3. Run 'ollama run <model>' to chat with Khong AI"
    echo ""
    ui_info "Need help? https://docs.openclaw.ai"
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-prompt) NO_PROMPT=1 ;;
            --no-onboard) NO_ONBOARD=1 ;;
            --skip-ollama) SKIP_OLLAMA=1 ;;
            --verbose) VERBOSE=1; set -x ;;
            --help|-h) echo "Usage: $0 [--no-prompt] [--skip-ollama] [--verbose]"; exit 0 ;;
            *) ;;
        esac
        shift
    done
}

ui_celebrate() {
    echo -e "${SUCCESS}${BOLD}$*${NC}"
}

# Run main
parse_args "$@"
main
