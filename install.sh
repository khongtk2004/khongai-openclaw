#!/bin/bash
set -euo pipefail

# OpenClaw Installer for macOS and Linux with Khong AI integration
# Fixed for CentOS Stream 10

BOLD='\033[1m'
ACCENT='\033[38;2;255;77;77m'
ACCENT_BRIGHT='\033[38;2;255;110;110m'
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
SELECTED_MODEL=""

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
ui_stage() { echo -e "\n${ACCENT}${BOLD}[$1/3] $2${NC}"; }
ui_kv() { echo -e "${MUTED}$1:${NC} $2"; }
ui_celebrate() { echo -e "${SUCCESS}${BOLD}$*${NC}"; }

print_installer_banner() {
    echo -e "$KHONG_BANNER"
    echo -e "${INFO}${DEFAULT_TAGLINE}${NC}\n"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -f /etc/os-release ]]; then
        OS="linux"
        if grep -qi "centos\|rhel\|fedora" /etc/os-release 2>/dev/null; then
            DISTRO="rhel"
            ui_success "Detected: RHEL-based Linux (CentOS/RHEL/Fedora)"
        elif grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
            DISTRO="debian"
            ui_success "Detected: Debian-based Linux (Debian/Ubuntu)"
        else
            DISTRO="other"
            ui_success "Detected: Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        ui_success "Detected: macOS"
    else
        ui_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
}

# Install build tools for CentOS/RHEL
install_build_tools_rhel() {
    ui_info "Installing build tools for RHEL/CentOS..."
    
    # Check if we have sudo access
    if ! command -v sudo &> /dev/null && [[ "$EUID" -ne 0 ]]; then
        ui_error "sudo is required but not installed. Please run as root or install sudo."
        exit 1
    fi
    
    local sudo_cmd=""
    if [[ "$EUID" -ne 0 ]] && command -v sudo &> /dev/null; then
        sudo_cmd="sudo"
    fi
    
    # Install build tools and dependencies
    $sudo_cmd dnf install -y \
        gcc \
        gcc-c++ \
        make \
        cmake \
        python3 \
        python3-pip \
        git \
        curl \
        wget \
        tar \
        gzip \
        which \
        openssl-devel \
        bzip2-devel \
        libffi-devel \
        zlib-devel \
        readline-devel \
        sqlite-devel \
        || true
    
    # Also try yum if dnf fails (for older systems)
    if ! command -v dnf &> /dev/null; then
        $sudo_cmd yum install -y \
            gcc \
            gcc-c++ \
            make \
            cmake \
            python3 \
            git \
            curl \
            wget \
            tar \
            gzip || true
    fi
    
    ui_success "Build tools installed"
}

# Install build tools for Debian/Ubuntu
install_build_tools_debian() {
    ui_info "Installing build tools for Debian/Ubuntu..."
    
    local sudo_cmd=""
    if [[ "$EUID" -ne 0 ]] && command -v sudo &> /dev/null; then
        sudo_cmd="sudo"
    fi
    
    $sudo_cmd apt-get update -qq
    $sudo_cmd apt-get install -y -qq \
        build-essential \
        gcc \
        g++ \
        make \
        cmake \
        python3 \
        python3-pip \
        git \
        curl \
        wget \
        tar \
        gzip
    
    ui_success "Build tools installed"
}

# Install build tools for macOS
install_build_tools_macos() {
    ui_info "Installing build tools for macOS..."
    
    # Install Xcode Command Line Tools if not present
    if ! xcode-select -p &> /dev/null; then
        ui_info "Installing Xcode Command Line Tools..."
        xcode-select --install || true
        sleep 2
    fi
    
    # Install Homebrew if not present
    if ! command -v brew &> /dev/null; then
        ui_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
    fi
    
    # Install build tools via Homebrew
    brew install gcc make cmake python3 git
    
    ui_success "Build tools installed"
}

# Install Node.js on RHEL/CentOS
install_node_rhel() {
    ui_info "Installing Node.js 22+ on RHEL/CentOS..."
    
    local sudo_cmd=""
    if [[ "$EUID" -ne 0 ]] && command -v sudo &> /dev/null; then
        sudo_cmd="sudo"
    fi
    
    # Add NodeSource repository
    curl -fsSL https://rpm.nodesource.com/setup_22.x | $sudo_cmd bash -
    
    # Install Node.js
    $sudo_cmd dnf install -y nodejs || $sudo_cmd yum install -y nodejs
    
    # Refresh PATH
    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
    hash -r
    
    # Verify installation
    if command -v node &> /dev/null; then
        ui_success "Node.js $(node -v) installed"
        return 0
    else
        ui_error "Node.js installation failed"
        return 1
    fi
}

# Install Node.js on Debian/Ubuntu
install_node_debian() {
    ui_info "Installing Node.js 22+ on Debian/Ubuntu..."
    
    local sudo_cmd=""
    if [[ "$EUID" -ne 0 ]] && command -v sudo &> /dev/null; then
        sudo_cmd="sudo"
    fi
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_22.x | $sudo_cmd bash -
    
    # Install Node.js
    $sudo_cmd apt-get install -y nodejs
    
    # Refresh PATH
    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
    hash -r
    
    # Verify installation
    if command -v node &> /dev/null; then
        ui_success "Node.js $(node -v) installed"
        return 0
    else
        ui_error "Node.js installation failed"
        return 1
    fi
}

# Install Node.js on macOS
install_node_macos() {
    ui_info "Installing Node.js 22+ on macOS..."
    
    # Ensure Homebrew is installed
    if ! command -v brew &> /dev/null; then
        ui_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
    fi
    
    # Install Node.js
    brew install node@22
    brew link node@22 --overwrite --force
    
    # Add to PATH
    export PATH="/opt/homebrew/opt/node@22/bin:/usr/local/opt/node@22/bin:$PATH"
    hash -r
    
    # Verify installation
    if command -v node &> /dev/null; then
        ui_success "Node.js $(node -v) installed"
        return 0
    else
        ui_error "Node.js installation failed"
        return 1
    fi
}

# Check Node.js version
check_node() {
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node -v 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ -n "$node_version" ]] && [[ "$node_version" -ge 22 ]]; then
            ui_success "Node.js $(node -v) found"
            return 0
        else
            ui_info "Node.js $(node -v 2>/dev/null || echo 'unknown') found, upgrading to v22+"
            return 1
        fi
    fi
    ui_info "Node.js not found, installing..."
    return 1
}

# Install Node.js based on OS
install_node() {
    case "${DISTRO:-}" in
        rhel)
            install_node_rhel
            ;;
        debian)
            install_node_debian
            ;;
        macos)
            install_node_macos
            ;;
        *)
            ui_error "Unsupported distribution for automatic Node.js installation"
            ui_info "Please install Node.js 22+ manually: https://nodejs.org"
            exit 1
            ;;
    esac
    
    # Final verification
    if ! command -v node &> /dev/null; then
        ui_error "Node.js still not found after installation"
        ui_info "Please install Node.js 22+ manually: https://nodejs.org"
        exit 1
    fi
}

# System-specific model recommendations
get_system_model_recommendation() {
    local total_ram total_cores
    total_ram=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    total_cores=$(nproc 2>/dev/null || echo "1")
    total_ram_gb=$((total_ram / 1024 / 1024))
    
    if [[ $total_ram_gb -ge 32 ]]; then
        echo "llama3.3:70b|qwen2.5:72b|deepseek-r1:67b"
    elif [[ $total_ram_gb -ge 16 ]]; then
        echo "llama3.3:70b|qwen2.5:32b|mixtral:8x7b"
    elif [[ $total_ram_gb -ge 8 ]]; then
        echo "qwen2.5:14b|llama3.3:8b|mistral:7b|phi4:14b"
    elif [[ $total_ram_gb -ge 4 ]]; then
        echo "qwen2.5:7b|llama3.2:3b|phi3:3.8b|gemma2:9b"
    else
        echo "llama3.2:1b|phi3:3.8b|qwen2.5:1.5b|tinyllama:1.1b"
    fi
}

# Install Ollama
install_ollama() {
    ui_info "Installing Ollama..."
    
    if [[ "$OS" == "linux" ]]; then
        curl -fsSL https://ollama.com/install.sh | sh
    elif [[ "$OS" == "macos" ]]; then
        brew install ollama
    fi
    
    ui_success "Ollama installed"
}

# Start Ollama service
start_ollama() {
    ui_info "Starting Ollama service..."
    
    if [[ "$OS" == "linux" ]]; then
        systemctl start ollama 2>/dev/null || (ollama serve >/dev/null 2>&1 &)
        systemctl enable ollama 2>/dev/null || true
    else
        ollama serve >/dev/null 2>&1 &
    fi
    
    # Wait for service to be ready
    local max_attempts=30
    local attempt=1
    while ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; do
        if [[ $attempt -ge $max_attempts ]]; then
            ui_warn "Ollama service not responding, continuing anyway"
            break
        fi
        sleep 1
        ((attempt++))
    done
    
    ui_success "Ollama service started"
}

# Setup Ollama and select model
setup_ollama() {
    ui_section "🦙 Khong AI - Ollama Integration"
    
    # Install Ollama if not present
    if ! command -v ollama &> /dev/null; then
        install_ollama
    else
        ui_success "Ollama already installed"
    fi
    
    # Start Ollama service
    start_ollama
    
    # Detect system specs
    local total_ram total_cores cpu_model
    total_ram=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    total_cores=$(nproc 2>/dev/null || echo "1")
    cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "Unknown")
    total_ram_gb=$((total_ram / 1024 / 1024))
    
    echo ""
    ui_info "${GOLD}⚙️  System Hardware Detection:${NC}"
    ui_kv "CPU" "${cpu_model}"
    ui_kv "Cores" "$total_cores"
    ui_kv "RAM" "${total_ram_gb}GB"
    
    if command -v nvidia-smi &> /dev/null; then
        local gpu_model
        gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        ui_kv "GPU" "$gpu_model (NVIDIA)"
    else
        ui_kv "GPU" "CPU-only mode"
    fi
    
    # Get recommended models
    local recommended_models
    recommended_models=$(get_system_model_recommendation)
    IFS='|' read -ra MODELS <<< "$recommended_models"
    
    echo ""
    ui_info "${GOLD}📦 Recommended Ollama models for your system:${NC}"
    for i in "${!MODELS[@]}"; do
        local model_size=""
        case "${MODELS[$i]}" in
            *"70b"*|*"72b"*) model_size="~40-45GB" ;;
            *"32b"*) model_size="~20GB" ;;
            *"14b"*) model_size="~8-9GB" ;;
            *"8b"*|*"9b"*) model_size="~4.5-5GB" ;;
            *"7b"*) model_size="~4GB" ;;
            *"3b"*|*"3.8b"*|*"1.5b"*|*"1.1b"*) model_size="~1.5-2GB" ;;
            *) model_size="varies" ;;
        esac
        echo -e "  ${CYAN}$((i+1)))${NC} ${BOLD}${MODELS[$i]}${NC} ${MUTED}(${model_size})${NC}"
    done
    
    # Interactive model selection
    if [[ "$NO_PROMPT" != "1" ]] && [[ -t 0 ]]; then
        echo ""
        echo -e "${INFO}Select model number (1-${#MODELS[@]}) or press Enter for default:${NC}"
        read -r model_choice
        
        if [[ -z "$model_choice" ]]; then
            SELECTED_MODEL="${MODELS[0]}"
        elif [[ "$model_choice" =~ ^[0-9]+$ ]] && [ "$model_choice" -ge 1 ] && [ "$model_choice" -le ${#MODELS[@]} ]; then
            SELECTED_MODEL="${MODELS[$((model_choice-1))]}"
        else
            SELECTED_MODEL="$model_choice"
        fi
    else
        SELECTED_MODEL="${MODELS[0]}"
        ui_info "Auto-selecting: ${SELECTED_MODEL}"
    fi
    
    # Install selected model
    if [[ -n "$SELECTED_MODEL" ]]; then
        echo ""
        ui_info "📥 Installing Ollama model: ${SELECTED_MODEL}"
        ui_info "This may take several minutes depending on model size and network speed..."
        
        if ollama pull "$SELECTED_MODEL" 2>&1; then
            ui_success "✓ Model ${SELECTED_MODEL} installed successfully!"
            
            # Quick test
            ui_info "Testing model..."
            if timeout 30 ollama run "$SELECTED_MODEL" "Hello" --keep-alive 5s >/dev/null 2>&1; then
                ui_success "✓ Model verified and ready!"
            else
                ui_warn "Model test timed out, but installation completed"
            fi
        else
            ui_error "Failed to install ${SELECTED_MODEL}"
            ui_info "Try: ollama pull ${SELECTED_MODEL}"
        fi
    fi
    
    # Configure OpenClaw
    mkdir -p "$HOME/.openclaw"
    cat > "$HOME/.openclaw/ollama.json" << EOF
{
  "ollama": {
    "host": "http://localhost:11434",
    "default_model": "${SELECTED_MODEL}",
    "models": {
      "${SELECTED_MODEL}": {
        "context_length": 4096,
        "temperature": 0.7,
        "top_p": 0.9,
        "num_predict": 512,
        "num_ctx": 4096
      }
    }
  },
  "khong_ai": {
    "enabled": true,
    "model": "${SELECTED_MODEL}",
    "system_prompt": "You are Khong AI, a helpful terminal assistant. You help users with command line tasks, automation, and general questions."
  }
}
EOF
    ui_success "✓ Ollama configured for OpenClaw"
    
    # Show status
    echo ""
    ui_info "🦙 Ollama Status:"
    if [[ "$OS" == "linux" ]] && command -v systemctl &> /dev/null; then
        local ollama_status
        ollama_status=$(systemctl is-active ollama 2>/dev/null || echo "unknown")
        ui_kv "Service" "$ollama_status"
    fi
    ui_kv "Active Models" "$(ollama list 2>/dev/null | tail -n +2 | wc -l || echo '0')"
    ui_kv "Default Model" "$SELECTED_MODEL"
    
    # Show usage tips
    echo ""
    ui_info "${GOLD}💡 Quick Start:${NC}"
    echo -e "  ${MUTED}# Run model directly:${NC}"
    echo -e "  ${CYAN}ollama run ${SELECTED_MODEL}${NC}"
    echo -e "  ${MUTED}# List all models:${NC}"
    echo -e "  ${CYAN}ollama list${NC}"
    echo -e "  ${MUTED}# Test with OpenClaw:${NC}"
    echo -e "  ${CYAN}openclaw chat --model ${SELECTED_MODEL}${NC}"
}

# Install OpenClaw via npm
install_openclaw() {
    ui_section "Installing OpenClaw"
    
    # Configure npm for global installs if needed
    if [[ "$OS" == "linux" ]]; then
        local npm_prefix
        npm_prefix=$(npm config get prefix 2>/dev/null || echo "")
        if [[ -n "$npm_prefix" ]] && [[ ! -w "$npm_prefix" ]]; then
            ui_info "Configuring npm for user-local installs"
            mkdir -p "$HOME/.npm-global"
            npm config set prefix "$HOME/.npm-global"
            export PATH="$HOME/.npm-global/bin:$PATH"
            
            # Add to shell rc files
            for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
                if [[ -f "$rc" ]] && ! grep -q ".npm-global" "$rc"; then
                    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$rc"
                fi
            done
        fi
    fi
    
    # Install OpenClaw
    ui_info "Installing OpenClaw via npm..."
    npm install -g openclaw@latest
    
    # Refresh PATH
    hash -r
    
    # Verify installation
    if command -v openclaw &> /dev/null; then
        local openclaw_version
        openclaw_version=$(openclaw --version 2>/dev/null || echo "unknown")
        ui_success "OpenClaw ${openclaw_version} installed"
    else
        ui_warn "OpenClaw installed but not in PATH"
        ui_info "Try: export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
    fi
}

# Run doctor after installation
run_doctor() {
    if command -v openclaw &> /dev/null; then
        ui_info "Running OpenClaw doctor..."
        openclaw doctor --non-interactive || true
    fi
}

# Main installation function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-prompt|--no-prompt)
                NO_PROMPT=1
                shift
                ;;
            --no-onboard|--no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --skip-ollama|--skip-ollama)
                SKIP_OLLAMA=1
                shift
                ;;
            --verbose|--verbose)
                VERBOSE=1
                set -x
                shift
                ;;
            --help|-h)
                echo "Khong AI + OpenClaw Installer"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --no-prompt      Skip interactive prompts"
                echo "  --no-onboard     Skip OpenClaw onboarding"
                echo "  --skip-ollama    Skip Ollama installation"
                echo "  --verbose        Enable verbose output"
                echo "  --help, -h       Show this help message"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Show banner
    print_installer_banner
    
    # Detect OS and distribution
    detect_os
    
    # Install build tools based on OS
    ui_stage "1" "Installing build tools"
    case "${DISTRO:-}" in
        rhel)
            install_build_tools_rhel
            ;;
        debian)
            install_build_tools_debian
            ;;
        macos)
            install_build_tools_macos
            ;;
        *)
            ui_info "Skipping build tools installation for unknown distribution"
            ;;
    esac
    
    # Install Node.js
    ui_stage "2" "Installing Node.js 22+"
    if ! check_node; then
        install_node
    fi
    
    # Setup Ollama (unless skipped)
    if [[ "$SKIP_OLLAMA" != "1" ]]; then
        ui_stage "3" "Setting up Ollama and Khong AI"
        setup_ollama
    fi
    
    # Install OpenClaw
    ui_section "Installing OpenClaw"
    install_openclaw
    
    # Run doctor
    run_doctor
    
    # Final success message
    echo ""
    ui_celebrate "🎉 Khong AI + OpenClaw installed successfully! 🎉"
    echo ""
    ui_info "Next steps:"
    echo "  1. Run 'openclaw onboard' to complete configuration"
    if [[ "$SKIP_OLLAMA" != "1" ]] && [[ -n "$SELECTED_MODEL" ]]; then
        echo "  2. Run 'ollama run $SELECTED_MODEL' to chat with Khong AI"
        echo "  3. Run 'openclaw chat' to use Khong AI with OpenClaw"
    else
        echo "  2. Run 'ollama pull <model>' to download an AI model"
        echo "  3. Run 'openclaw chat' to start using AI"
    fi
    echo ""
    ui_info "Documentation: https://docs.openclaw.ai"
    ui_info "Ollama models: https://ollama.ai/library"
    echo ""
    
    # Show installed versions
    ui_section "Installed versions"
    ui_kv "Node.js" "$(node -v 2>/dev/null || echo 'not found')"
    ui_kv "npm" "$(npm -v 2>/dev/null || echo 'not found')"
    if command -v ollama &> /dev/null; then
        ui_kv "Ollama" "$(ollama --version 2>/dev/null | head -1 || echo 'installed')"
        if [[ -n "$SELECTED_MODEL" ]]; then
            ui_kv "AI Model" "$SELECTED_MODEL"
        fi
    fi
    ui_kv "OpenClaw" "$(openclaw --version 2>/dev/null || echo 'installed')"
    echo ""
}

# Run main function with all arguments
main "$@"
