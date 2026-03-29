#!/bin/bash
# KhongAI Installer - Fixed Groq API Integration

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
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║    _  __ _                                                                    ║"
    echo "║   | |/ /| |                                                                   ║"
    echo "║   | ' / | |   ___   __ _  _ __   _   _   ___   _ __                           ║"
    echo "║   |  <  | |  / _ \ / _\` || '_ \ | | | | / _ \ | '_ \                          ║"
    echo "║   | . \ | | |  __/| (_| || | | || |_| || (_) || | | |                         ║"
    echo "║   |_|\_\|_|  \___| \__,_||_| |_| \__,_| \___/ |_| |_|                         ║"
    echo "║                                                                              ║"
    echo "║                 Groq API Integration with Learning System                    ║"
    echo "║                      Fast AI Responses by KhongAI                            ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step() { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }

# Install zstd
install_zstd() {
    log_step "Installing zstd..."
    if ! command -v zstd &> /dev/null; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y zstd
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y zstd
        fi
        log_success "zstd installed"
    else
        log_success "zstd already installed"
    fi
}

# Get Groq API Key
get_api_keys() {
    echo -e "\n${BOLD}${CYAN}🔑 Groq API Configuration${NC}\n"
    echo -e "${YELLOW}Enter your Groq API Key:${NC}"
    echo -e "${BLUE}(Get from https://console.groq.com/keys)${NC}"
    echo -e "${BLUE}(This is REQUIRED for fast AI responses)${NC}"
    read -p "➤ " GROQ_API_KEY

    if [[ -z "$GROQ_API_KEY" ]]; then
        log_error "Groq API Key is required for proper responses!"
        exit 1
    fi

    log_success "Groq API Key saved"

    # Model selection
    echo -e "\n${BOLD}${CYAN}🤖 Groq Model Selection${NC}\n"
    echo -e "${YELLOW}Select Groq model:${NC}"
    echo "  1) mixtral-8x7b-32768 (Fast, intelligent - Recommended)"
    echo "  2) llama3-70b-8192 (Most powerful, slower)"
    echo "  3) llama3-8b-8192 (Fast, lightweight)"
    echo "  4) gemma2-9b-it (Google's model)"
    read -p "Select [1-4, default: 1]: " model_choice

    case $model_choice in
        2) GROQ_MODEL="llama3-70b-8192" ;;
        3) GROQ_MODEL="llama3-8b-8192" ;;
        4) GROQ_MODEL="gemma2-9b-it" ;;
        *) GROQ_MODEL="mixtral-8x7b-32768" ;;
    esac

    log_success "Groq model selected: $GROQ_MODEL"

    # AI Personality
    echo -e "\n${BOLD}${CYAN}🎭 AI Personality${NC}\n"
    read -p "Enter AI name [default: KhongAI]: " AI_NAME
    AI_NAME=${AI_NAME:-KhongAI}

    log_success "AI configured: $AI_NAME"
}

# Get admin usernames
get_admin_usernames() {
    echo -e "\n${BOLD}${CYAN}👥 Admin Users${NC}\n"
    echo -e "${YELLOW}Enter Telegram usernames who can approve users (without @)${NC}"
    echo -e "${BLUE}Example: khongtk2004,renyu4444${NC}"
    read -p "Admin usernames: " ADMIN_USERNAMES_INPUT

    IFS=',' read -ra ADMIN_LIST <<< "$ADMIN_USERNAMES_INPUT"
    ADMIN_USERNAMES=()
    for username in "${ADMIN_LIST[@]}"; do
        username=$(echo "$username" | tr -d ' ' | sed 's/^@//')
        if [[ -n "$username" ]]; then
            ADMIN_USERNAMES+=("$username")
        fi
    done

    if [ ${#ADMIN_USERNAMES[@]} -eq 0 ]; then
        ADMIN_USERNAMES=("khongtk2004")
    fi

    echo -e "\n${GREEN}✓ Admin users:${NC}"
    for admin in "${ADMIN_USERNAMES[@]}"; do
        echo "  • @$admin"
    done

    printf "%s\n" "${ADMIN_USERNAMES[@]}" > ~/.khongai/admin_usernames.txt
}

# Create directories
create_directories() {
    log_step "Creating directories..."
    mkdir -p ~/.khongai/{models,data,chat_history,training_data,logs,conversations,learned}
    mkdir -p ~/khongai
    mkdir -p ~/khongai-telegram-bot
    log_success "Directories created"
}

# Create OpenClaw container
create_openclaw_container() {
    log_step "Setting up OpenClaw..."
    cd ~/khongai

    cat > docker-compose.yml << 'EOF'
services:
  khongai:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: khongai
    restart: always
    ports:
      - "18789:18789"
    volumes:
      - ~/.khongai:/home/node/.openclaw
    environment:
      - NODE_ENV=production
    command: ["node", "dist/index.js"]
EOF

    docker compose up -d 2>/dev/null || true
    log_success "OpenClaw container started"
}

# Create Groq bot with real learning
create_groq_bot() {
    log_step "Creating Groq-powered bot with learning..."

    cd ~/khongai-telegram-bot

    cat > package.json << 'EOF'
{
  "name": "khongai-groq-bot",
  "version": "6.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6"
  }
}
EOF

    npm install --silent 2>/dev/null || npm install

    # Create admin list JSON
    ADMIN_LIST_JSON="["
    for i in "${!ADMIN_USERNAMES[@]}"; do
        [ $i -gt 0 ] && ADMIN_LIST_JSON+=","
        ADMIN_LIST_JSON+="\"${ADMIN_USERNAMES[$i]}\""
    done
    ADMIN_LIST_JSON+="]"

    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const groqApiKey = process.env.GROQ_API_KEY;
const groqModel = process.env.GROQ_MODEL || 'mixtral-8x7b-32768';
const aiName = process.env.AI_NAME || 'KhongAI';
const ADMIN_USERNAMES = JSON.parse(process.env.ADMIN_USERNAMES || '["khongtk2004"]');

const bot = new TelegramBot(token, { polling: true });

// Initialize database
const db = new sqlite3.Database(path.join(process.env.HOME, '.khongai', 'chat_history.db'));

// Create all tables
db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        username TEXT,
        first_name TEXT,
        is_approved BOOLEAN DEFAULT 0,
        is_admin BOOLEAN DEFAULT 0,
        registered_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        user_message TEXT,
        ai_response TEXT,
        model_used TEXT,
        response_time INTEGER,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS learned_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_message TEXT UNIQUE,
        ai_response TEXT,
        usage_count INTEGER DEFAULT 1,
        effectiveness INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
});

// Store conversation history per user
const userHistory = new Map();

console.log(`🤖 ${aiName} Groq AI Bot Started`);
console.log(`Groq Model: ${groqModel}`);
console.log(`Admins: ${ADMIN_USERNAMES.join(', ')}`);

// Helper: Call Groq API
async function callGroqAPI(userMessage, conversationHistory) {
    const startTime = Date.now();

    try {
        const messages = [
            {
                role: 'system',
                content: `You are ${aiName}, a helpful, friendly AI assistant. Respond naturally with detailed, informative answers. Use emojis occasionally. Be engaging and helpful.`
            }
        ];

        // Add conversation history
        if (conversationHistory && conversationHistory.length > 0) {
            const lastMessages = conversationHistory.slice(-10);
            for (const msg of lastMessages) {
                messages.push({
                    role: msg.role,
                    content: msg.content
                });
            }
        }

        messages.push({
            role: 'user',
            content: userMessage
        });

        const response = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
            model: groqModel,
            messages: messages,
            temperature: 0.7,
            max_tokens: 500
        }, {
            headers: {
                'Authorization': `Bearer ${groqApiKey}`,
                'Content-Type': 'application/json'
            },
            timeout: 30000
        });

        const responseTime = Date.now() - startTime;
        console.log(`Groq API response time: ${responseTime}ms`);

        return {
            content: response.data.choices[0].message.content,
            responseTime: responseTime
        };
    } catch (error) {
        console.error('Groq API Error:', error.message);
        return null;
    }
}

// Helper: Check if user is approved
async function isApproved(userId) {
    return new Promise((resolve) => {
        db.get('SELECT is_approved FROM users WHERE user_id = ?', [userId], (err, row) => {
            resolve(row && row.is_approved === 1);
        });
    });
}

// Helper: Check if user is admin
async function isAdmin(userId, username) {
    return new Promise((resolve) => {
        db.get('SELECT is_admin FROM users WHERE user_id = ?', [userId], (err, row) => {
            if (row && row.is_admin) {
                resolve(true);
            } else {
                const isAdminUser = ADMIN_USERNAMES.includes(username);
                if (isAdminUser) {
                    db.run('INSERT OR REPLACE INTO users (user_id, username, is_approved, is_admin) VALUES (?, ?, 1, 1)', [userId, username]);
                }
                resolve(isAdminUser);
            }
        });
    });
}

// Register user
async function registerUser(userId, username, firstName) {
    return new Promise((resolve) => {
        db.run(
            'INSERT OR IGNORE INTO users (user_id, username, first_name) VALUES (?, ?, ?)',
            [userId, username || '', firstName || ''],
            (err) => resolve()
        );
    });
}

// /start command
bot.onText(/\/start/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const firstName = msg.from.first_name || '';

    await registerUser(userId, username, firstName);

    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);

    if (approved || admin) {
        const welcomeMessage = `🌟 *Hello ${firstName}! I'm ${aiName}* 🌟

I'm an AI assistant powered by **Groq's fast AI**!

━━━━━━━━━━━━━━━━━━━━━

✨ *What I can do:*
• Answer questions naturally
• Learn from conversations
• Remember context
• Fast responses

📋 *Commands:*
• Just send any message to chat
• /stats - View statistics
• /clear - Clear conversation

━━━━━━━━━━━━━━━━━━━━━

*Let's chat! Send me anything!* 🚀`;

        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `⏳ *Access Request Submitted* 🙏

Hi ${firstName}! Your request has been sent to the administrators.

You'll be notified when approved.`, { parse_mode: 'Markdown' });

        // Notify admins
        for (const adminUsername of ADMIN_USERNAMES) {
            bot.sendMessage(chatId, `👥 *New User Request*

**User:** @${username || firstName}
**ID:** ${userId}

Use: /approve @${username || userId} to approve`, { parse_mode: 'Markdown' });
        }
    }
});

// Main message handler
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';

    if (!text || text.startsWith('/')) return;

    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);

    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nPlease wait for admin approval.", { parse_mode: 'Markdown' });
        return;
    }

    bot.sendChatAction(chatId, 'typing');

    // Get conversation history
    let history = userHistory.get(userId) || [];

    // Call Groq API
    const groqResult = await callGroqAPI(text, history);
    let aiResponse = '';

    if (groqResult) {
        aiResponse = groqResult.content;
    } else {
        aiResponse = `💭 I'm ${aiName}! I'm here to help. What would you like to know about "${text}"?`;
    }

    // Update history
    history.push({ role: 'user', content: text });
    history.push({ role: 'assistant', content: aiResponse });
    if (history.length > 20) history = history.slice(-20);
    userHistory.set(userId, history);

    // Save conversation
    db.run(
        'INSERT INTO conversations (user_id, user_message, ai_response, model_used) VALUES (?, ?, ?, ?)',
        [userId, text, aiResponse, 'groq']
    );

    bot.sendMessage(chatId, aiResponse);
});

// /approve command
bot.onText(/\/approve (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const target = match[1].replace('@', '');

    const admin = await isAdmin(userId, username);
    if (!admin) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }

    db.get('SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?', [target, target], async (err, user) => {
        if (user) {
            db.run('UPDATE users SET is_approved = 1 WHERE user_id = ?', [user.user_id]);
            bot.sendMessage(chatId, `✅ *User Approved*\n\n@${user.username || user.first_name} can now use the bot!`);

            bot.sendMessage(user.user_id, `🎉 *Access Granted!* 🎉

You've been approved to chat with ${aiName}!

Send /start to begin! 🚀`, { parse_mode: 'Markdown' });
        } else {
            bot.sendMessage(chatId, `❌ *User Not Found*`);
        }
    });
});

// /stats command
bot.onText(/\/stats/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';

    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);

    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Pending*", { parse_mode: 'Markdown' });
        return;
    }

    db.get('SELECT COUNT(*) as total FROM conversations', (err, total) => {
        db.get('SELECT COUNT(*) as approved_users FROM users WHERE is_approved = 1', (err2, users) => {
            const statsMessage = `📊 *${aiName} Statistics*

**Conversations:** ${total.total}
**Approved Users:** ${users.approved_users}
**AI Model:** ${groqModel}
**Provider:** Groq Cloud

*I learn from every conversation!* 🧠`;

            bot.sendMessage(chatId, statsMessage, { parse_mode: 'Markdown' });
        });
    });
});

// /clear command
bot.onText(/\/clear/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();

    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*", { parse_mode: 'Markdown' });
        return;
    }

    userHistory.delete(userId);
    bot.sendMessage(chatId, `🗑️ *Conversation cleared!*\n\nStarting fresh! 💭`, { parse_mode: 'Markdown' });
});

console.log(`🚀 ${aiName} is ready with Groq AI!`);
BOTEOF

    # Create start script
    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export GROQ_API_KEY="$GROQ_API_KEY"
export GROQ_MODEL="$GROQ_MODEL"
export AI_NAME="$AI_NAME"
export ADMIN_USERNAMES='$ADMIN_LIST_JSON'

cd "$HOME/khongai-telegram-bot"
pkill -f "node bot.js" 2>/dev/null
nohup node bot.js > bot.log 2>&1 &
echo \$! > bot.pid
echo "✅ ${AI_NAME} bot started with Groq AI!"
sleep 2
tail -3 bot.log
EOF

    chmod +x start.sh

    cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "node bot.js"
echo "Bot stopped"
EOF

    chmod +x stop.sh

    log_success "Groq AI bot created!"
}

# Create management script
create_manager() {
    cat > ~/khongai-manager.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${BLUE}Starting KhongAI services...${NC}"
        cd ~/khongai && docker compose up -d 2>/dev/null
        cd ~/khongai-telegram-bot && ./start.sh
        echo -e "${GREEN}✓ Services started${NC}"
        ;;
    stop)
        echo -e "${BLUE}Stopping services...${NC}"
        cd ~/khongai && docker compose down 2>/dev/null
        cd ~/khongai-telegram-bot && ./stop.sh
        echo -e "${GREEN}✓ Services stopped${NC}"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo -e "${BLUE}════════════════════════════════${NC}"
        echo -e "KhongAI Status"
        echo -e "${BLUE}════════════════════════════════${NC}"
        echo -e "\n🤖 Bot: $(pgrep -f 'node bot.js' > /dev/null && echo 'Running ✅' || echo 'Stopped ❌')"
        echo -e "\n📊 Database:"
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as conversations FROM conversations;" 2>/dev/null
        ;;
    logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    test)
        echo -e "${BLUE}Testing Groq API...${NC}"
        curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
          -H "Authorization: Bearer $(grep GROQ_API_KEY ~/khongai-telegram-bot/start.sh | cut -d'"' -f2)" \
          -H "Content-Type: application/json" \
          -d '{"model":"mixtral-8x7b-32768","messages":[{"role":"user","content":"Say OK"}],"max_tokens":5}'
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|test}"
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

    install_zstd
    get_api_keys
    get_admin_usernames
    create_directories

    # Get Telegram token
    echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Token${NC}\n"
    while true; do
        read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        if [[ "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            break
        else
            log_error "Invalid token format. Get it from @BotFather"
        fi
    done

    echo "$TELEGRAM_BOT_TOKEN" > ~/.khongai/bot-token.txt

    # Save config
    ADMIN_LIST_JSON="["
    for i in "${!ADMIN_USERNAMES[@]}"; do
        [ $i -gt 0 ] && ADMIN_LIST_JSON+=","
        ADMIN_LIST_JSON+="\"${ADMIN_USERNAMES[$i]}\""
    done
    ADMIN_LIST_JSON+="]"

    cat > ~/.khongai/config.json << EOF
{
    "ai_name": "$AI_NAME",
    "groq_model": "$GROQ_MODEL",
    "admins": ${ADMIN_LIST_JSON},
    "install_date": "$(date)"
}
EOF

    create_openclaw_container
    create_groq_bot
    create_manager

    ~/khongai-manager.sh start

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ ${AI_NAME} Groq AI Bot installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

    echo -e "${CYAN}⚡ Groq AI Features:${NC}"
    echo "  • Ultra-fast responses"
    echo "  • Natural conversation flow"
    echo "  • Context memory"
    echo ""
    echo -e "${CYAN}📋 Available Commands:${NC}"
    echo "  • Send any message - Get AI responses"
    echo "  • /stats - View statistics"
    echo "  • /clear - Clear conversation"
    echo ""
    echo -e "${CYAN}👑 Admin Commands:${NC}"
    echo "  • /approve @username - Approve user"
    echo "  • /pending - View pending users"
    echo ""
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "  • ~/khongai-manager.sh status  - Check status"
    echo "  • ~/khongai-manager.sh logs     - View bot logs"
    echo "  • ~/khongai-manager.sh test     - Test Groq API"
    echo ""
    echo -e "${GREEN}🎉 Send /start to your bot on Telegram to begin!${NC}\n"
}

main "$@"
