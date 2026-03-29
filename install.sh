#!/bin/bash
# KhongAI Installer - With Telegram User Approval System

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
MODELS_DIR="$HOME/.khongai/models"
DATA_DIR="$HOME/.khongai/data"
CHAT_HISTORY_DIR="$HOME/.khongai/chat_history"
TRAINING_DATA_DIR="$HOME/.khongai/training_data"
LOG_FILE="/tmp/khongai_install.log"

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
    echo "║                   Advanced AI with User Approval System                       ║"
    echo "║                         by KhongAI                                            ║"
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

# Get Telegram Admin Usernames
get_admin_usernames() {
    echo -e "\n${BOLD}${CYAN}👥 Telegram User Approval Setup${NC}\n"
    echo -e "${YELLOW}Enter Telegram usernames who can approve new users (without @ symbol)${NC}"
    echo -e "${BLUE}Separate multiple usernames with commas${NC}"
    echo -e "${BLUE}Example: khongtk2004,renyu4444,johndoe${NC}\n"
    
    read -p "Admin usernames: " ADMIN_USERNAMES_INPUT
    
    # Parse admin usernames
    IFS=',' read -ra ADMIN_LIST <<< "$ADMIN_USERNAMES_INPUT"
    ADMIN_USERNAMES=()
    for username in "${ADMIN_LIST[@]}"; do
        # Remove whitespace and @ symbol
        username=$(echo "$username" | tr -d ' ' | sed 's/^@//')
        if [[ -n "$username" ]]; then
            ADMIN_USERNAMES+=("$username")
        fi
    done
    
    if [ ${#ADMIN_USERNAMES[@]} -eq 0 ]; then
        log_warning "No admin usernames provided. Defaulting to 'khongtk2004'"
        ADMIN_USERNAMES=("khongtk2004")
    fi
    
    echo -e "\n${GREEN}✓ Admin users:${NC}"
    for admin in "${ADMIN_USERNAMES[@]}"; do
        echo "  • @$admin"
    done
    
    # Save admin list
    printf "%s\n" "${ADMIN_USERNAMES[@]}" > ~/.khongai/admin_usernames.txt
}

# Get API Keys and Configuration
get_api_keys() {
    echo -e "\n${BOLD}${CYAN}🔑 API Configuration${NC}\n"
    
    # ChatGPT API Key
    echo -e "${YELLOW}Enter your OpenAI ChatGPT API Key (optional but recommended):${NC}"
    echo -e "${BLUE}(Get from https://platform.openai.com/api-keys)${NC}"
    read -p "➤ " OPENAI_API_KEY
    
    # Ollama Model Selection
    echo -e "\n${BOLD}${CYAN}🦙 Ollama Model Selection${NC}\n"
    echo -e "${YELLOW}Select AI model:${NC}"
    echo "  1) llama2 (7B, balanced performance)"
    echo "  2) mistral (7B, very intelligent)"
    echo "  3) neural-chat (7B, best for conversation)"
    echo "  4) phi (2.7B, fast and lightweight)"
    read -p "Select model [1-4, default: 3]: " model_choice
    
    case $model_choice in
        1) OLLAMA_MODEL="llama2" ;;
        2) OLLAMA_MODEL="mistral" ;;
        4) OLLAMA_MODEL="phi" ;;
        *) OLLAMA_MODEL="neural-chat" ;;
    esac
    
    # AI Personality
    echo -e "\n${BOLD}${CYAN}🎭 AI Personality Configuration${NC}\n"
    read -p "Enter AI name [default: KhongAI]: " AI_NAME
    AI_NAME=${AI_NAME:-KhongAI}
    
    echo -e "${YELLOW}Select personality type:${NC}"
    echo "  1) Friendly & Helpful (Default)"
    echo "  2) Professional & Formal"
    echo "  3) Creative & Imaginative"
    echo "  4) Humorous & Witty"
    read -p "Select [1-4, default: 1]: " personality_choice
    
    case $personality_choice in
        2)
            AI_PERSONALITY="You are $AI_NAME, a professional, formal, and highly knowledgeable AI assistant. You provide accurate, well-structured information."
            ;;
        3)
            AI_PERSONALITY="You are $AI_NAME, a creative, imaginative, and artistic AI. You think outside the box and provide unique perspectives."
            ;;
        4)
            AI_PERSONALITY="You are $AI_NAME, a witty, humorous, and fun-loving AI. You make jokes and keep conversations light-hearted."
            ;;
        *)
            AI_PERSONALITY="You are $AI_NAME, a friendly, helpful, and enthusiastic AI assistant. You love helping people and are always positive and encouraging."
            ;;
    esac
    
    log_success "AI configured: $AI_NAME with $OLLAMA_MODEL model"
}

# Install Ollama
install_ollama() {
    log_step "Installing Ollama..."
    
    if ! command -v ollama &> /dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    sudo systemctl start ollama
    sudo systemctl enable ollama
    sleep 3
    
    log_info "Pulling $OLLAMA_MODEL model (this may take several minutes)..."
    ollama pull $OLLAMA_MODEL
    
    log_success "Ollama model ready: $OLLAMA_MODEL"
}

# Create directories
create_directories() {
    log_step "Creating directories..."
    mkdir -p "$MODELS_DIR" "$DATA_DIR" "$CHAT_HISTORY_DIR" "$TRAINING_DATA_DIR"
    mkdir -p "$INSTALL_DIR" "$HOME/.khongai/logs"
    mkdir -p "$MODELS_DIR/ollama" "$CHAT_HISTORY_DIR/daily" "$TRAINING_DATA_DIR/raw"
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
    
    docker compose up -d
    log_success "OpenClaw container started"
}

# Create Telegram bot with user approval system
create_advanced_bot() {
    log_step "Creating Telegram bot with user approval system..."
    
    local bot_dir="$HOME/khongai-telegram-bot"
    mkdir -p "$bot_dir"
    cd "$bot_dir"
    
    cat > package.json << EOF
{
  "name": "khongai-approval-bot",
  "version": "3.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6"
  }
}
EOF
    
    npm install
    
    # Create admin list file
    ADMIN_LIST_JSON="["
    for i in "${!ADMIN_USERNAMES[@]}"; do
        if [ $i -gt 0 ]; then
            ADMIN_LIST_JSON+=","
        fi
        ADMIN_LIST_JSON+="\"${ADMIN_USERNAMES[$i]}\""
    done
    ADMIN_LIST_JSON+="]"
    
    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const sqlite3 = require('sqlite3').verbose();
const fs = require('fs').promises;
const path = require('path');

// Load configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const ollamaModel = process.env.OLLAMA_MODEL || 'neural-chat';
const aiName = process.env.AI_NAME || 'KhongAI';
const aiPersonality = process.env.AI_PERSONALITY || 'You are a friendly, helpful AI assistant.';

// Admin usernames from environment
const ADMIN_USERNAMES = JSON.parse(process.env.ADMIN_USERNAMES || '["khongtk2004"]');

const bot = new TelegramBot(token, { polling: true });

// Initialize database
const db = new sqlite3.Database(path.join(process.env.HOME, '.khongai', 'chat_history.db'));

// Create tables
db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    is_approved BOOLEAN DEFAULT 0,
    is_admin BOOLEAN DEFAULT 0,
    approved_by TEXT,
    approved_at DATETIME,
    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP
)`);

db.run(`CREATE TABLE IF NOT EXISTS pending_approvals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    username TEXT,
    first_name TEXT,
    request_message TEXT,
    status TEXT DEFAULT 'pending',
    requested_at DATETIME DEFAULT CURRENT_TIMESTAMP
)`);

db.run(`CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    user_message TEXT,
    ai_response TEXT,
    model_used TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
)`);

db.run(`CREATE TABLE IF NOT EXISTS learned_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_message TEXT,
    ai_response TEXT,
    usage_count INTEGER DEFAULT 1,
    effectiveness INTEGER DEFAULT 0
)`);

// Store conversation context per user
const userContext = new Map();

console.log(`🤖 ${aiName} Bot Started with User Approval System`);
console.log(`Admins: ${ADMIN_USERNAMES.join(', ')}`);

// Helper: Check if user is admin
async function isAdmin(userId, username) {
    // Check database first
    return new Promise((resolve) => {
        db.get('SELECT is_admin FROM users WHERE user_id = ?', [userId], (err, row) => {
            if (row && row.is_admin) {
                resolve(true);
            } else {
                // Check if username is in admin list
                const isAdminUser = ADMIN_USERNAMES.includes(username);
                if (isAdminUser) {
                    // Add to database as admin
                    db.run(
                        'INSERT OR REPLACE INTO users (user_id, username, is_approved, is_admin) VALUES (?, ?, 1, 1)',
                        [userId, username]
                    );
                }
                resolve(isAdminUser);
            }
        });
    });
}

// Helper: Check if user is approved
async function isApproved(userId) {
    return new Promise((resolve) => {
        db.get('SELECT is_approved FROM users WHERE user_id = ?', [userId], (err, row) => {
            resolve(row && row.is_approved === 1);
        });
    });
}

// Helper: Approve user
async function approveUser(userId, approvedBy) {
    return new Promise((resolve) => {
        db.run(
            'UPDATE users SET is_approved = 1, approved_by = ?, approved_at = CURRENT_TIMESTAMP WHERE user_id = ?',
            [approvedBy, userId],
            (err) => {
                db.run('UPDATE pending_approvals SET status = "approved" WHERE user_id = ?', [userId]);
                resolve(!err);
            }
        );
    });
}

// Helper: Reject user
async function rejectUser(userId) {
    return new Promise((resolve) => {
        db.run('UPDATE pending_approvals SET status = "rejected" WHERE user_id = ?', [userId]);
        resolve(true);
    });
}

// Helper: Get pending users
async function getPendingUsers() {
    return new Promise((resolve) => {
        db.all('SELECT * FROM pending_approvals WHERE status = "pending" ORDER BY requested_at DESC', (err, rows) => {
            resolve(rows || []);
        });
    });
}

// Helper: Register new user
async function registerUser(userId, username, firstName, lastName) {
    return new Promise((resolve) => {
        db.run(
            'INSERT OR IGNORE INTO users (user_id, username, first_name, last_name, is_approved) VALUES (?, ?, ?, ?, 0)',
            [userId, username, firstName, lastName],
            (err) => {
                resolve(!err);
            }
        );
    });
}

// Helper: Add pending approval request
async function addPendingRequest(userId, username, firstName, message) {
    return new Promise((resolve) => {
        db.run(
            'INSERT INTO pending_approvals (user_id, username, first_name, request_message) VALUES (?, ?, ?, ?)',
            [userId, username, firstName, message],
            (err) => {
                resolve(!err);
            }
        );
    });
}

// Helper: Get AI response
async function getAIResponse(userId, userMessage, context = []) {
    // Check learned responses
    const learned = await getLearnedResponse(userMessage);
    if (learned && Math.random() < 0.3) {
        return learned;
    }
    
    // Try ChatGPT
    if (openaiApiKey) {
        const chatGPTResponse = await callChatGPT(userMessage, context);
        if (chatGPTResponse) return chatGPTResponse;
    }
    
    // Use Ollama
    const ollamaResponse = await callOllamaWithPersonality(userMessage, context);
    if (ollamaResponse) return ollamaResponse;
    
    // Fallback
    return getFallbackResponse(userMessage);
}

async function callChatGPT(message, context) {
    try {
        const messages = [
            { role: 'system', content: aiPersonality },
            ...context.slice(-5),
            { role: 'user', content: message }
        ];
        
        const response = await axios.post('https://api.openai.com/v1/chat/completions', {
            model: 'gpt-3.5-turbo',
            messages: messages,
            temperature: 0.8,
            max_tokens: 300
        }, {
            headers: { 'Authorization': `Bearer ${openaiApiKey}` },
            timeout: 15000
        });
        
        return response.data.choices[0].message.content;
    } catch (error) {
        return null;
    }
}

async function callOllamaWithPersonality(message, context) {
    try {
        const contextText = context.map(c => `${c.role}: ${c.content}`).join('\n');
        const prompt = `${aiPersonality}

Previous conversation:
${contextText}

User: ${message}

${aiName}:`;

        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: { temperature: 0.8, top_k: 40, top_p: 0.9 }
        }, { timeout: 30000 });
        
        return response.data.response.replace(`${aiName}:`, '').trim();
    } catch (error) {
        return null;
    }
}

function getLearnedResponse(message) {
    return new Promise((resolve) => {
        db.get(
            'SELECT ai_response FROM learned_responses WHERE user_message = ? ORDER BY usage_count DESC LIMIT 1',
            [message.toLowerCase()],
            (err, row) => {
                if (row) {
                    db.run('UPDATE learned_responses SET usage_count = usage_count + 1 WHERE user_message = ?', [message.toLowerCase()]);
                    resolve(row.ai_response);
                } else {
                    resolve(null);
                }
            }
        );
    });
}

function getFallbackResponse(message) {
    const msg = message.toLowerCase();
    
    if (msg.includes('hello') || msg.includes('hi')) {
        return `👋 Hello! I'm ${aiName}, your AI assistant. How can I help you today?`;
    }
    if (msg.includes('how are you')) {
        return `🌟 I'm doing great! Thanks for asking! How are you doing?`;
    }
    if (msg.includes('what is your name')) {
        return `✨ My name is ${aiName}! I'm an AI assistant with a personality. What's your name?`;
    }
    if (msg.includes('thank')) {
        return `🎉 You're very welcome! It's my pleasure to help you!`;
    }
    
    return `💭 I'm ${aiName}, and I'm here to help! Could you tell me more about "${message}"?`;
}

// /start command - Request approval
bot.onText(/\/start/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const firstName = msg.from.first_name || '';
    const lastName = msg.from.last_name || '';
    
    // Register user
    await registerUser(userId, username, firstName, lastName);
    
    // Check if approved
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);
    
    if (approved || admin) {
        const welcomeMessage = `🌟 *Welcome back, ${firstName}!* 🌟

I'm ${aiName}, your AI assistant with personality!

✨ *Available Commands:*
/chat [message] - Chat with me
/approve [username] - Approve user (Admin only)
/pending - View pending users (Admin only)
/reject [username] - Reject user (Admin only)
/users - List all users (Admin only)
/stats - View statistics
/clear - Clear conversation

*Just send me any message to start chatting!* 🚀`;
        
        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        // Check if already requested
        const pending = await getPendingUsers();
        const alreadyRequested = pending.some(p => p.user_id === userId);
        
        if (!alreadyRequested) {
            await addPendingRequest(userId, username, firstName, "User requested access");
            
            // Notify admins
            for (const adminUsername of ADMIN_USERNAMES) {
                bot.sendMessage(chatId, `📋 *Access Request Pending*

User: @${username || firstName}
ID: ${userId}

An admin will review your request and approve you shortly.

*Thank you for your patience!* 🙏`, { parse_mode: 'Markdown' });
            }
            
            // Notify admins
            for (const adminUsername of ADMIN_USERNAMES) {
                // Find admin chat ID (simplified - in production you'd store this)
                bot.sendMessage(chatId, `👥 *New User Request*

Username: @${username || firstName}
User ID: ${userId}

Use /approve ${username || userId} to approve
Use /reject ${username || userId} to reject

*Pending approvals:* /pending`, { parse_mode: 'Markdown' });
            }
        } else {
            bot.sendMessage(chatId, `⏳ *Access Request Pending*

Your request has been submitted and is waiting for admin approval.

An admin will review your request shortly.

*Thank you for your patience!* 🙏`, { parse_mode: 'Markdown' });
        }
    }
});

// /approve command (Admin only)
bot.onText(/\/approve (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const targetIdentifier = match[1];
    
    const isAdminUser = await isAdmin(userId, username);
    
    if (!isAdminUser) {
        bot.sendMessage(chatId, "❌ *Access Denied*\n\nYou don't have permission to use this command.", { parse_mode: 'Markdown' });
        return;
    }
    
    // Find user by username or ID
    db.get(
        'SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?',
        [targetIdentifier.replace('@', ''), targetIdentifier],
        async (err, user) => {
            if (user) {
                await approveUser(user.user_id, username);
                bot.sendMessage(chatId, `✅ *User Approved*\n\n@${user.username || user.first_name} has been approved to use the bot!`);
                
                // Notify the approved user
                bot.sendMessage(user.user_id, `🎉 *Access Granted!*\n\nYou've been approved to use ${aiName}!\n\nSend /start to begin chatting!`, { parse_mode: 'Markdown' });
            } else {
                bot.sendMessage(chatId, `❌ *User Not Found*\n\nCould not find user: ${targetIdentifier}`);
            }
        }
    );
});

// /reject command (Admin only)
bot.onText(/\/reject (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const targetIdentifier = match[1];
    
    const isAdminUser = await isAdmin(userId, username);
    
    if (!isAdminUser) {
        bot.sendMessage(chatId, "❌ *Access Denied*\n\nYou don't have permission to use this command.", { parse_mode: 'Markdown' });
        return;
    }
    
    db.get(
        'SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?',
        [targetIdentifier.replace('@', ''), targetIdentifier],
        async (err, user) => {
            if (user) {
                await rejectUser(user.user_id);
                bot.sendMessage(chatId, `❌ *User Rejected*\n\n@${user.username || user.first_name} has been rejected.`);
                
                bot.sendMessage(user.user_id, `❌ *Access Denied*\n\nYour request to use ${aiName} has been rejected.\n\nContact an admin for more information.`);
            } else {
                bot.sendMessage(chatId, `❌ *User Not Found*\n\nCould not find user: ${targetIdentifier}`);
            }
        }
    );
});

// /pending command (Admin only)
bot.onText(/\/pending/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    
    const isAdminUser = await isAdmin(userId, username);
    
    if (!isAdminUser) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    const pendingUsers = await getPendingUsers();
    
    if (pendingUsers.length === 0) {
        bot.sendMessage(chatId, "📋 *No Pending Users*\n\nThere are no users waiting for approval.");
        return;
    }
    
    let message = "👥 *Pending Approvals*\n\n";
    for (const user of pendingUsers) {
        message += `• @${user.username || user.first_name}\n  ID: ${user.user_id}\n  Requested: ${user.requested_at}\n\n`;
    }
    message += `\nUse /approve <username> to approve\nUse /reject <username> to reject`;
    
    bot.sendMessage(chatId, message, { parse_mode: 'Markdown' });
});

// /users command (Admin only)
bot.onText(/\/users/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    
    const isAdminUser = await isAdmin(userId, username);
    
    if (!isAdminUser) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    db.all('SELECT user_id, username, first_name, is_approved, is_admin, approved_at FROM users ORDER BY registered_at DESC', (err, users) => {
        let message = "👥 *Registered Users*\n\n";
        for (const user of users) {
            const status = user.is_approved ? '✅ Approved' : '⏳ Pending';
            const adminBadge = user.is_admin ? ' 👑 Admin' : '';
            message += `• @${user.username || user.first_name}${adminBadge}\n  ${status}\n  ID: ${user.user_id}\n\n`;
        }
        bot.sendMessage(chatId, message.substring(0, 4000), { parse_mode: 'Markdown' });
    });
});

// /stats command
bot.onText(/\/stats/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, msg.from.username || '');
    
    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nPlease wait for admin approval.", { parse_mode: 'Markdown' });
        return;
    }
    
    db.get('SELECT COUNT(*) as total FROM conversations', (err, total) => {
        db.get('SELECT COUNT(*) as approved_users FROM users WHERE is_approved = 1', (err2, users) => {
            const statsMessage = `📊 *${aiName} Statistics*

*Total Conversations:* ${total.total}
*Approved Users:* ${users.approved_users}
*AI Model:* ${ollamaModel}
*ChatGPT:* ${openaiApiKey ? 'Connected ✅' : 'Not connected'}

*Admins:* ${ADMIN_USERNAMES.join(', ')}

I'm learning and improving every day! 🌟`;
            
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
    
    userContext.delete(userId);
    bot.sendMessage(chatId, "🗑️ *Conversation cleared!*\n\nStarting fresh!");
});

// Handle messages from approved users
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    const userId = msg.from.id.toString();
    
    if (!text || text.startsWith('/')) return;
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, msg.from.username || '');
    
    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nPlease wait for admin approval.\n\nContact an admin: @khongtk2004");
        return;
    }
    
    bot.sendChatAction(chatId, 'typing');
    
    let context = userContext.get(userId) || [];
    const response = await getAIResponse(userId, text, context);
    
    context.push({ role: 'user', content: text });
    context.push({ role: 'assistant', content: response });
    if (context.length > 10) context = context.slice(-10);
    userContext.set(userId, context);
    
    db.run(
        'INSERT INTO conversations (user_id, user_message, ai_response, model_used) VALUES (?, ?, ?, ?)',
        [userId, text, response, openaiApiKey ? 'chatgpt' : 'ollama']
    );
    
    bot.sendMessage(chatId, response);
});

// /chat command
bot.onText(/\/chat (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const message = match[1];
    const userId = msg.from.id.toString();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nPlease wait for admin approval.", { parse_mode: 'Markdown' });
        return;
    }
    
    bot.sendChatAction(chatId, 'typing');
    
    let context = userContext.get(userId) || [];
    const response = await getAIResponse(userId, message, context);
    
    context.push({ role: 'user', content: message });
    context.push({ role: 'assistant', content: response });
    if (context.length > 10) context = context.slice(-10);
    userContext.set(userId, context);
    
    db.run(
        'INSERT INTO conversations (user_id, user_message, ai_response, model_used) VALUES (?, ?, ?, ?)',
        [userId, message, response, openaiApiKey ? 'chatgpt' : 'ollama']
    );
    
    bot.sendMessage(chatId, response);
});

console.log(`🚀 ${aiName} is ready!`);
console.log(`Admins can approve users with /approve <username>`);
BOTEOF
    
    # Create start script with admin usernames
    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export OLLAMA_MODEL="$OLLAMA_MODEL"
export AI_NAME="$AI_NAME"
export AI_PERSONALITY="$AI_PERSONALITY"
export ADMIN_USERNAMES='$ADMIN_LIST_JSON'

cd "$HOME/khongai-telegram-bot"
pkill -f "node bot.js" 2>/dev/null
nohup node bot.js > bot.log 2>&1 &
echo \$! > bot.pid
echo "✅ ${AI_NAME} bot started with PID: \$(cat bot.pid)"
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
    
    log_success "Bot created with user approval system"
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

case "$1" in
    start)
        echo -e "${BLUE}Starting KhongAI services...${NC}"
        sudo systemctl start ollama
        cd ~/khongai && docker compose up -d
        cd ~/khongai-telegram-bot && ./start.sh
        echo -e "${GREEN}✓ All services started${NC}"
        ;;
    stop)
        echo -e "${BLUE}Stopping KhongAI services...${NC}"
        cd ~/khongai && docker compose down
        cd ~/khongai-telegram-bot && ./stop.sh
        sudo systemctl stop ollama
        echo -e "${GREEN}✓ All services stopped${NC}"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo -e "${BLUE}════════════════════════════════════${NC}"
        echo -e "${BOLD}KhongAI Status${NC}"
        echo -e "${BLUE}════════════════════════════════════${NC}"
        echo -e "\n🦙 Ollama: $(systemctl is-active ollama 2>/dev/null || echo 'inactive')"
        echo -e "🐳 OpenClaw: $(docker ps --filter name=khongai --format '{{.Status}}' || echo 'Not running')"
        echo -e "🤖 Bot: $(pgrep -f 'node bot.js' > /dev/null && echo 'Running' || echo 'Stopped')"
        
        echo -e "\n👥 Users:"
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as total, SUM(is_approved) as approved FROM users;" 2>/dev/null | while IFS='|' read total approved; do
            echo "  Total: $total | Approved: ${approved:-0}"
        done
        ;;
    users)
        echo -e "${BLUE}User List:${NC}"
        sqlite3 ~/.khongai/chat_history.db "SELECT user_id, username, is_approved, is_admin FROM users;" 2>/dev/null
        ;;
    approve)
        if [ -z "$2" ]; then
            echo "Usage: $0 approve <username>"
        else
            echo "Approving user: $2"
            sqlite3 ~/.khongai/chat_history.db "UPDATE users SET is_approved=1 WHERE username='$2';"
        fi
        ;;
    logs)
        docker logs khongai --tail 50 -f
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|users|approve|logs|bot-logs}"
        ;;
esac
EOF
    
    chmod +x ~/khongai-manager.sh
}

# Main installation
main() {
    print_banner
    
    install_zstd
    get_admin_usernames
    get_api_keys
    create_directories
    
    # Get Telegram token
    echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Setup${NC}\n"
    while true; do
        read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        if [[ "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            break
        else
            log_error "Invalid token format"
        fi
    done
    
    echo "$TELEGRAM_BOT_TOKEN" > ~/.khongai/bot-token.txt
    
    # Save config
    cat > ~/.khongai/config.json << EOF
{
    "ai_name": "$AI_NAME",
    "ai_personality": "$AI_PERSONALITY",
    "ollama_model": "$OLLAMA_MODEL",
    "admins": ${ADMIN_LIST_JSON},
    "openai_enabled": ${OPENAI_API_KEY:+true},
    "install_date": "$(date)"
}
EOF
    
    install_ollama
    create_openclaw_container
    create_advanced_bot
    create_manager
    
    ~/khongai-manager.sh start
    
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ $AI_NAME with User Approval System installed!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}👥 User Approval System:${NC}"
    echo "  • Only approved users can chat with the AI"
    echo "  • Admins can approve/reject users"
    echo "  • New users automatically request access"
    echo ""
    echo -e "${CYAN}📋 Admin Commands in Telegram:${NC}"
    echo "  • /approve <username> - Approve a user"
    echo "  • /reject <username> - Reject a user"
    echo "  • /pending - View pending approvals"
    echo "  • /users - List all users"
    echo ""
    echo -e "${CYAN}👤 Admin Usernames configured:${NC}"
    for admin in "${ADMIN_USERNAMES[@]}"; do
        echo "  • @$admin"
    done
    echo ""
    echo -e "${GREEN}🎉 Send /start to your bot on Telegram to request access!${NC}\n"
}

main "$@"
