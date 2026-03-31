#!/bin/bash
set -euo pipefail

# ClawBot Installer - Professional Edition
# Usage: curl -fsSL https://yourdomain.com/install.sh | bash

BOLD='\033[1m'
ACCENT='\033[38;2;255;77;77m'       # coral-bright
INFO='\033[38;2;136;146;176m'       # text-secondary
SUCCESS='\033[38;2;0;229;204m'      # cyan-bright
WARN='\033[38;2;255;176;32m'        # amber
ERROR='\033[38;2;230;57;70m'        # coral-mid
MUTED='\033[38;2;90;100;128m'       # text-muted
NC='\033[0m'

# Configuration
DEFAULT_BOT_NAME="Khong"
DEFAULT_PERSONALITY="Friendly AI assistant from Cambodia"
OLLAMA_MODEL="llama2"
GUM_VERSION="0.17.0"

# Global variables
OS=""
GUM=""
VERBOSE=0
DRY_RUN=0
NO_ONBOARD=0
NO_PROMPT=0
TELEGRAM_BOT_TOKEN=""
AI_NAME=""
PERSONALITY=""
ADMIN_USERNAME=""

TMPFILES=()
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

# UI Functions
ui_info() { echo -e "${MUTED}·${NC} $*"; }
ui_warn() { echo -e "${WARN}!${NC} $*"; }
ui_success() { echo -e "${SUCCESS}✓${NC} $*"; }
ui_error() { echo -e "${ERROR}✗${NC} $*"; }

print_banner() {
    echo -e "${ACCENT}${BOLD}"
    echo "  🦞 ClawBot Installer"
    echo -e "${NC}${INFO}  Your AI assistant with memory and PDF learning${NC}"
    echo ""
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        OS="linux"
    else
        ui_error "Unsupported operating system"
        echo "This installer supports macOS and Linux (including WSL)."
        exit 1
    fi
    ui_success "Detected: $OS"
}

# Gum UI for interactive prompts
bootstrap_gum() {
    if command -v gum &> /dev/null; then
        GUM="gum"
        return 0
    fi

    if ! command -v tar &> /dev/null; then
        return 1
    fi

    local os arch asset base gum_tmpdir gum_path
    case "$OS" in
        macos) os="Darwin" ;;
        linux) os="Linux" ;;
        *) return 1 ;;
    esac

    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) arch="x86_64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) return 1 ;;
    esac

    asset="gum_${GUM_VERSION}_${os}_${arch}.tar.gz"
    base="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}"

    gum_tmpdir="$(mktemp -d)"
    TMPFILES+=("$gum_tmpdir")

    if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$gum_tmpdir/$asset" "$base/$asset"; then
        return 1
    fi

    tar -xzf "$gum_tmpdir/$asset" -C "$gum_tmpdir" >/dev/null 2>&1
    gum_path="$(find "$gum_tmpdir" -type f -name gum 2>/dev/null | head -n1)"
    if [[ -z "$gum_path" ]]; then
        return 1
    fi

    chmod +x "$gum_path"
    GUM="$gum_path"
    return 0
}

# Installation Functions
install_deps() {
    ui_info "Installing system dependencies..."
    
    if ! command -v curl &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y curl
        fi
    fi
    
    if ! command -v node &> /dev/null; then
        ui_info "Installing Node.js v20..."
        if command -v apt-get &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v dnf &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
        elif [[ "$OS" == "macos" ]]; then
            brew install node@20
        fi
    fi
    
    ui_success "Dependencies installed"
}

check_ollama() {
    ui_info "Checking Ollama..."
    
    if ! command -v ollama &> /dev/null; then
        ui_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    # Check if Ollama is running
    if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        ui_info "Starting Ollama..."
        nohup ollama serve > ~/.clawbot/ollama.log 2>&1 &
        sleep 5
    fi
    
    # Check if llama2 model is available
    if ! ollama list | grep -q "llama2"; then
        ui_info "Pulling llama2 model (this may take a few minutes)..."
        ollama pull llama2
    fi
    
    ui_success "Ollama ready with llama2 model"
}

create_bot() {
    ui_info "Creating ClawBot..."

    mkdir -p ~/clawbot-telegram
    cd ~/clawbot-telegram

    cat > package.json << 'EOF'
{
  "name": "clawbot",
  "version": "1.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0"
  }
}
EOF

    npm install --silent 2>/dev/null || npm install

    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const aiName = process.env.AI_NAME || 'Khong';
const personality = process.env.PERSONALITY || 'Friendly AI assistant from Cambodia';
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'khongtk2004';

console.log('🦞 Starting ClawBot...');
console.log(`Bot name: ${aiName}`);
console.log(`Admin: @${ADMIN_USERNAME}`);

const bot = new TelegramBot(token, { polling: true });
const approvedUsers = new Set();
const userHistory = new Map();

// Auto-approve admin
approvedUsers.add(ADMIN_USERNAME);

async function callOllama(prompt) {
    try {
        const response = await axios.post('http://localhost:11434/api/generate', {
            model: 'llama2',
            prompt: prompt,
            stream: false,
            options: { temperature: 0.7, num_predict: 500 }
        }, { timeout: 60000 });
        return response.data.response.trim();
    } catch (error) {
        console.error('Ollama error:', error.message);
        return null;
    }
}

async function getAIResponse(userMessage, history, username) {
    const prompt = `You are ${aiName}, ${personality}. You are knowledgeable, friendly, and helpful.

Previous conversation:
${history.slice(-5).map(h => `${h.role === 'user' ? username : aiName}: ${h.content}`).join('\n')}

${username}: ${userMessage}

${aiName}:`;

    let response = await callOllama(prompt);
    
    if (!response) {
        response = `I'm ${aiName}, your AI assistant. I'm having trouble connecting. Please check if Ollama is running with: ollama serve`;
    }
    
    return response;
}

// Commands
bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const username = msg.from.username || '';
    const firstName = msg.from.first_name || '';
    
    if (approvedUsers.has(username) || username === ADMIN_USERNAME) {
        approvedUsers.add(username);
        
        const welcomeMessage = `🦞 *Welcome to ${aiName}!* 🦞

I'm an AI assistant powered by Ollama (llama2 model). I can answer questions, have conversations, and help with anything!

━━━━━━━━━━━━━━━━━━━━━

✨ *What I can do:*
• Answer questions about Cambodia and beyond
• Have natural conversations
• Remember our discussions

📋 *Commands:*
/chat <message> - Chat with me
/help - Show this help

━━━━━━━━━━━━━━━━━━━━━

*Try: /chat Tell me about Cambodia* 🦞`;

        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `⏳ *Hey ${firstName}!*\n\nYou need admin approval. Ask @${ADMIN_USERNAME} to approve you.\n\nSend: /approve @${username}`);
        bot.sendMessage(chatId, `👤 *New user request*\n\nUser: @${username || firstName}\n\nTo approve: /approve @${username}`);
    }
});

bot.onText(/\/chat\s+(.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const username = msg.from.username || '';
    const userMessage = match[1];
    
    if (!approvedUsers.has(username) && username !== ADMIN_USERNAME) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nAsk admin to approve you!", { parse_mode: 'Markdown' });
        return;
    }
    
    if (username === ADMIN_USERNAME) approvedUsers.add(username);
    
    bot.sendChatAction(chatId, 'typing');
    
    let history = userHistory.get(username) || [];
    const response = await getAIResponse(userMessage, history, username);
    
    history.push({ role: 'user', content: userMessage });
    history.push({ role: 'assistant', content: response });
    if (history.length > 20) history = history.slice(-20);
    userHistory.set(username, history);
    
    bot.sendMessage(chatId, `💬 *${aiName}* (llama2)\n\n${response}`, { parse_mode: 'Markdown' });
});

bot.onText(/\/chat$/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, `💬 *How to chat with ${aiName}*\n\n*Usage:* /chat <your message>\n\n*Examples:*\n/chat Tell me about Cambodia\n/chat What is Angkor Wat?\n/chat Tell me a joke`, { parse_mode: 'Markdown' });
});

bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, `🦞 *${aiName} Help* 🦞\n\n*Commands:*\n/chat <message> - Chat with me\n/start - Show welcome\n/help - Show this help\n\n*I use llama2 AI to chat with you!*`, { parse_mode: 'Markdown' });
});

bot.onText(/\/approve @(\w+)/, (msg, match) => {
    const chatId = msg.chat.id;
    const username = msg.from.username || '';
    const targetUser = match[1];
    
    if (username !== ADMIN_USERNAME) {
        bot.sendMessage(chatId, "❌ *Access Denied* - Admin only", { parse_mode: 'Markdown' });
        return;
    }
    
    approvedUsers.add(targetUser);
    bot.sendMessage(chatId, `✅ *User Approved*\n\n@${targetUser} can now use the bot!`);
});

bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    const username = msg.from.username || '';
    
    if (username !== ADMIN_USERNAME) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    let ollamaStatus = '❌ Not running';
    try {
        await axios.get('http://localhost:11434/api/tags', { timeout: 5000 });
        ollamaStatus = '✅ Running';
    } catch (error) {}
    
    bot.sendMessage(chatId, `📊 *Bot Status*\n\n**Bot:** ✅ Running\n**Ollama:** ${ollamaStatus}\n**Model:** llama2\n**Approved users:** ${approvedUsers.size}\n**Admin:** @${ADMIN_USERNAME}`, { parse_mode: 'Markdown' });
});

bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    const username = msg.from.username || '';

    if (!text || text.startsWith('/')) return;

    if (!approvedUsers.has(username) && username !== ADMIN_USERNAME) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nUse /start to request access.");
        return;
    }

    if (username === ADMIN_USERNAME) approvedUsers.add(username);

    bot.sendChatAction(chatId, 'typing');
    
    let history = userHistory.get(username) || [];
    const response = await getAIResponse(text, history, username);
    
    history.push({ role: 'user', content: text });
    history.push({ role: 'assistant', content: response });
    if (history.length > 20) history = history.slice(-20);
    userHistory.set(username, history);
    
    bot.sendMessage(chatId, response);
});

console.log(`🦞 ${aiName} is ready!`);
console.log(`Commands: /chat, /start, /help, /status (admin)`);
BOTEOF

    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export AI_NAME="$AI_NAME"
export PERSONALITY="$PERSONALITY"
export ADMIN_USERNAME="$ADMIN_USERNAME"

cd "$HOME/clawbot-telegram"
pkill -f "node bot.js" 2>/dev/null || true
sleep 1
nohup node bot.js > bot.log 2>&1 &
echo \$! > bot.pid
sleep 2
echo "✅ ${AI_NAME} started!"
EOF

    chmod +x start.sh

    cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "node bot.js"
echo "Bot stopped"
EOF

    chmod +x stop.sh

    ui_success "ClawBot created!"
}

create_manager() {
    cat > ~/clawbot-manager.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${BLUE}Starting ClawBot...${NC}"
        cd ~/clawbot-telegram && ./start.sh
        ;;
    stop)
        echo -e "${BLUE}Stopping ClawBot...${NC}"
        cd ~/clawbot-telegram && ./stop.sh
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        echo -e "${BLUE}════════════════════════════════${NC}"
        echo -e "ClawBot Status"
        echo -e "${BLUE}════════════════════════════════${NC}"
        echo ""
        
        if pgrep -f "node bot.js" > /dev/null; then
            echo -e "${GREEN}✓ Bot is running${NC}"
        else
            echo -e "${RED}✗ Bot is stopped${NC}"
        fi
        
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Ollama is running${NC}"
            echo "  Models:"
            ollama list
        else
            echo -e "${RED}✗ Ollama is not running${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}Logs:${NC}"
        tail -5 ~/clawbot-telegram/bot.log 2>/dev/null || echo "No logs yet"
        ;;
    logs)
        tail -f ~/clawbot-telegram/bot.log
        ;;
    test)
        echo -e "${BLUE}Testing Ollama...${NC}"
        curl -s -X POST http://localhost:11434/api/generate -d '{"model": "llama2", "prompt": "Say hello in one word", "stream": false}' | grep -o '"response":"[^"]*"'
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|test}"
        exit 1
        ;;
esac
EOF

    chmod +x ~/clawbot-manager.sh
    ui_success "Management script created"
}

# Main installation
main() {
    print_banner
    detect_os
    
    # Bootstrap gum for better UI if available
    bootstrap_gum || true
    
    # Get Telegram token
    echo ""
    echo -e "${INFO}📱 Telegram Bot Setup${NC}"
    echo -e "${MUTED}1. Open Telegram and search for @BotFather${NC}"
    echo -e "${MUTED}2. Send: /newbot${NC}"
    echo -e "${MUTED}3. Give it a name (e.g., MyClawBot)${NC}"
    echo -e "${MUTED}4. Give it a username (e.g., myclawbot_bot)${NC}"
    echo -e "${MUTED}5. Copy the token${NC}"
    echo ""
    
    while true; do
        read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        if [[ "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            break
        else
            ui_error "Invalid token format. Get it from @BotFather"
        fi
    done
    
    # Get bot name
    echo ""
    read -p "Enter bot name [default: Khong]: " AI_NAME
    AI_NAME=${AI_NAME:-Khong}
    
    # Get personality
    echo ""
    read -p "Enter bot personality [default: Friendly AI assistant from Cambodia]: " PERSONALITY
    PERSONALITY=${PERSONALITY:-"Friendly AI assistant from Cambodia"}
    
    # Get admin username
    echo ""
    read -p "Enter your Telegram username (without @) for admin access: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-"khongtk2004"}
    
    # Install everything
    install_deps
    check_ollama
    create_bot
    create_manager
    
    # Start bot
    cd ~/clawbot-telegram && ./start.sh
    
    echo ""
    echo -e "${SUCCESS}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${SUCCESS}✅ ${AI_NAME} (ClawBot) installed successfully!${NC}"
    echo -e "${SUCCESS}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${INFO}🦞 Next steps:${NC}"
    echo ""
    echo "1. Open Telegram and find your bot"
    echo "2. Send: /start"
    echo "3. Approve yourself: /approve @${ADMIN_USERNAME}"
    echo "4. Start chatting: /chat Tell me about Cambodia"
    echo ""
    echo -e "${INFO}📋 Commands:${NC}"
    echo "  /chat <message> - Chat with AI"
    echo "  /status - Check bot status (admin)"
    echo "  /help - Show help"
    echo ""
    echo -e "${INFO}🛠️ Management:${NC}"
    echo "  ~/clawbot-manager.sh status  - Check status"
    echo "  ~/clawbot-manager.sh logs    - View logs"
    echo "  ~/clawbot-manager.sh test    - Test Ollama"
    echo ""
    echo -e "${SUCCESS}🎉 Try: /chat What is Cambodia famous for?${NC}"
    echo ""
}

# Run main function
if [[ "${CLAWBOT_INSTALL_SH_NO_RUN:-0}" != "1" ]]; then
    main "$@"
fi
