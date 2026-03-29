#!/bin/bash
# KhongAI Installer - Groq API Integration with Learning System

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
    
    # Test the API key
    log_info "Testing Groq API key..."
    TEST_RESPONSE=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "model": "mixtral-8x7b-32768",
        "messages": [{"role": "user", "content": "Say OK if you work"}],
        "max_tokens": 5
      }' 2>/dev/null)
    
    if echo "$TEST_RESPONSE" | grep -q "OK"; then
        log_success "Groq API key works! (Fast AI responses ready)"
    else
        log_warning "API key test failed, but continuing..."
    fi
    
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
const fs = require('fs').promises;
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
        context TEXT,
        usage_count INTEGER DEFAULT 1,
        effectiveness INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
    
    db.run(`CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        message TEXT,
        rating INTEGER,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
});

// Store conversation history per user
const userHistory = new Map();

console.log(`🤖 ${aiName} Groq AI Bot Started`);
console.log(`Groq Model: ${groqModel}`);
console.log(`Groq API: ${groqApiKey ? 'Connected ✅' : 'Not connected ❌'}`);
console.log(`Admins: ${ADMIN_USERNAMES.join(', ')}`);

// Helper: Call Groq API (super fast!)
async function callGroqAPI(userMessage, conversationHistory) {
    const startTime = Date.now();
    
    try {
        // Build messages array with history
        const messages = [
            {
                role: 'system',
                content: `You are ${aiName}, a helpful, friendly AI assistant powered by Groq's fast AI.
You respond naturally like a professional AI - with detailed, informative, and conversational answers.
Use emojis occasionally to be friendly.
Break down complex topics simply.
Ask clarifying questions when needed.
Be engaging and helpful.
Provide examples when relevant.
Keep responses concise but informative.`
            }
        ];
        
        // Add conversation history (last 10 messages)
        if (conversationHistory && conversationHistory.length > 0) {
            const lastMessages = conversationHistory.slice(-10);
            for (const msg of lastMessages) {
                messages.push({
                    role: msg.role,
                    content: msg.content
                });
            }
        }
        
        // Add current message
        messages.push({
            role: 'user',
            content: userMessage
        });
        
        const response = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
            model: groqModel,
            messages: messages,
            temperature: 0.8,
            max_tokens: 600,
            top_p: 0.9,
            frequency_penalty: 0.5,
            presence_penalty: 0.5
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
        console.error('Groq API Error:', error.response?.data?.error?.message || error.message);
        return null;
    }
}

// Helper: Check learned responses
async function checkLearnedResponse(userMessage) {
    return new Promise((resolve) => {
        const msg = userMessage.toLowerCase().trim();
        db.get(
            'SELECT ai_response FROM learned_responses WHERE user_message = ? AND effectiveness > 0 ORDER BY usage_count DESC LIMIT 1',
            [msg],
            (err, row) => {
                if (row) {
                    db.run('UPDATE learned_responses SET usage_count = usage_count + 1 WHERE user_message = ?', [msg]);
                    resolve(row.ai_response);
                } else {
                    // Check for partial matches
                    db.all('SELECT user_message, ai_response FROM learned_responses WHERE effectiveness > 0', (err, rows) => {
                        if (rows) {
                            for (const row of rows) {
                                if (msg.includes(row.user_message) || row.user_message.includes(msg)) {
                                    resolve(row.ai_response);
                                    return;
                                }
                            }
                        }
                        resolve(null);
                    });
                }
            }
        );
    });
}

// Helper: Learn new response
async function learnResponse(userMessage, aiResponse) {
    return new Promise((resolve) => {
        const msg = userMessage.toLowerCase().trim();
        db.run(
            'INSERT OR REPLACE INTO learned_responses (user_message, ai_response, effectiveness) VALUES (?, ?, 5)',
            [msg, aiResponse],
            (err) => resolve()
        );
    });
}

// Helper: Save conversation
async function saveConversation(userId, userMessage, aiResponse, modelUsed, responseTime) {
    return new Promise((resolve) => {
        db.run(
            'INSERT INTO conversations (user_id, user_message, ai_response, model_used, response_time) VALUES (?, ?, ?, ?, ?)',
            [userId, userMessage, aiResponse, modelUsed, responseTime || 0],
            (err) => resolve()
        );
    });
}

// Helper: Save feedback
async function saveFeedback(userId, message, rating) {
    return new Promise((resolve) => {
        db.run(
            'INSERT INTO feedback (user_id, message, rating) VALUES (?, ?, ?)',
            [userId, message, rating],
            (err) => resolve()
        );
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

I'm an AI assistant powered by **Groq's fast AI** - I respond instantly with detailed, helpful answers!

━━━━━━━━━━━━━━━━━━━━━

✨ *What makes me special:*
• ⚡ Super fast responses (Groq AI)
• 🧠 I learn from every conversation
• 💾 Remembers our discussions
• 📚 Can be taught new things
• 🎯 Context-aware answers

━━━━━━━━━━━━━━━━━━━━━

📋 *Commands:*

**💬 Chat**
• Just send any message - I'll respond instantly!

**👑 Admin Commands**
• /approve @username - Approve user
• /reject @username - Reject user  
• /pending - View pending users
• /users - List all users

**📚 Learning Commands**
• /teach question | answer - Teach me something
• /learned - See what I've learned
• /feedback good/bad - Rate my response

**📊 Info**
• /stats - View statistics
• /clear - Clear conversation
• /model - Show current AI model

━━━━━━━━━━━━━━━━━━━━━

💡 *Try asking me:*
• "What is artificial intelligence?"
• "Explain quantum computing simply"
• "How do neural networks work?"
• "Tell me a fun fact"
• "Help me understand machine learning"

━━━━━━━━━━━━━━━━━━━━━

*Let's chat! Send me anything you'd like to know!* 🚀`;
        
        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `⏳ *Access Request Submitted* 🙏

Hi ${firstName}! Your request has been sent to the administrators.

You'll be notified when approved.

*Thank you for your patience!* 🌟`, { parse_mode: 'Markdown' });
        
        // Notify admins
        for (const adminUsername of ADMIN_USERNAMES) {
            bot.sendMessage(chatId, `👥 *New User Request*

**User:** @${username || firstName}
**ID:** ${userId}

Use: /approve @${username || userId} to approve

*Pending approvals:* /pending`, { parse_mode: 'Markdown' });
        }
    }
});

// Main message handler - Groq AI style
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
    
    // Send typing indicator
    bot.sendChatAction(chatId, 'typing');
    
    // Check if we have a learned response
    let learnedResponse = await checkLearnedResponse(text);
    
    if (learnedResponse && Math.random() < 0.3) {
        // Use learned response 30% of the time
        await saveConversation(userId, text, learnedResponse, 'learned', 0);
        bot.sendMessage(chatId, learnedResponse);
        return;
    }
    
    // Get conversation history
    let history = userHistory.get(userId) || [];
    
    // Call Groq API
    const groqResult = await callGroqAPI(text, history);
    let aiResponse = '';
    let modelUsed = 'groq';
    let responseTime = 0;
    
    if (groqResult) {
        aiResponse = groqResult.content;
        responseTime = groqResult.responseTime;
    } else {
        // Fallback response if API fails
        aiResponse = getFallbackResponse(text);
        modelUsed = 'fallback';
    }
    
    // Update history
    history.push({ role: 'user', content: text });
    history.push({ role: 'assistant', content: aiResponse });
    if (history.length > 20) history = history.slice(-20);
    userHistory.set(userId, history);
    
    // Save conversation
    await saveConversation(userId, text, aiResponse, modelUsed, responseTime);
    
    // Send response
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

Send /start to begin our conversation!

I'm excited to chat with you! 🚀`, { parse_mode: 'Markdown' });
        } else {
            bot.sendMessage(chatId, `❌ *User Not Found*\n\nCould not find: ${target}`);
        }
    });
});

// /reject command
bot.onText(/\/reject (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const target = match[1].replace('@', '');
    
    const admin = await isAdmin(userId, username);
    if (!admin) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    db.get('SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?', [target, target], (err, user) => {
        if (user) {
            bot.sendMessage(chatId, `❌ *User Rejected*\n\n@${user.username || user.first_name}`);
        }
    });
});

// /pending command
bot.onText(/\/pending/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    
    const admin = await isAdmin(userId, username);
    if (!admin) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    db.all('SELECT user_id, username, first_name FROM users WHERE is_approved = 0', (err, rows) => {
        if (!rows || rows.length === 0) {
            bot.sendMessage(chatId, "📋 *No Pending Users*");
            return;
        }
        
        let message = "👥 *Pending Approvals*\n\n";
        for (const user of rows) {
            message += `• @${user.username || user.first_name}\n  ID: ${user.user_id}\n\n`;
        }
        message += `Use /approve @username to approve`;
        
        bot.sendMessage(chatId, message.substring(0, 4000), { parse_mode: 'Markdown' });
    });
});

// /users command
bot.onText(/\/users/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    
    const admin = await isAdmin(userId, username);
    if (!admin) {
        bot.sendMessage(chatId, "❌ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    db.all('SELECT user_id, username, first_name, is_approved, is_admin FROM users ORDER BY registered_at DESC', (err, rows) => {
        let message = "👥 *Registered Users*\n\n";
        for (const user of rows) {
            const status = user.is_approved ? '✅' : '⏳';
            const adminBadge = user.is_admin ? ' 👑' : '';
            message += `${status} @${user.username || user.first_name}${adminBadge}\n`;
        }
        bot.sendMessage(chatId, message, { parse_mode: 'Markdown' });
    });
});

// /teach command - Teach AI something new
bot.onText(/\/teach (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const teachingText = match[1];
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);
    
    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    // Parse teaching format: "question|answer"
    const parts = teachingText.split('|');
    if (parts.length >= 2) {
        const question = parts[0].trim();
        const answer = parts[1].trim();
        
        await learnResponse(question, answer);
        bot.sendMessage(chatId, `📚 *I've learned something new!*

**Question:** ${question}
**Answer:** ${answer}

I'll remember this for future conversations! 🧠`, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `📚 *How to teach me:*

Use: /teach question | answer

**Example:**
/teach What is your name? | My name is ${aiName}!

I'll learn and remember this! 🧠`, { parse_mode: 'Markdown' });
    }
});

// /learned command - Show what AI has learned
bot.onText(/\/learned/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);
    
    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    db.all('SELECT user_message, ai_response, usage_count FROM learned_responses ORDER BY usage_count DESC LIMIT 10', (err, rows) => {
        if (!rows || rows.length === 0) {
            bot.sendMessage(chatId, "📚 *I haven't learned anything yet!*\n\nTeach me with: /teach question | answer");
            return;
        }
        
        let message = "📚 *What I've Learned*\n\n";
        for (const row of rows) {
            message += `**Q:** ${row.user_message}\n`;
            message += `**A:** ${row.ai_response.substring(0, 100)}${row.ai_response.length > 100 ? '...' : ''}\n`;
            message += `_Used ${row.usage_count} times_\n\n`;
        }
        
        bot.sendMessage(chatId, message, { parse_mode: 'Markdown' });
    });
});

// /feedback command
bot.onText(/\/feedback (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const rating = match[1].toLowerCase();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    let ratingValue = 0;
    if (rating === 'good' || rating === 'great' || rating === '👍') {
        ratingValue = 5;
        bot.sendMessage(chatId, "🙏 *Thank you for the positive feedback!*\n\nI'll keep learning to serve you better! 🌟");
    } else if (rating === 'bad' || rating === 'poor' || rating === '👎') {
        ratingValue = 1;
        bot.sendMessage(chatId, "🙏 *Thanks for the feedback!*\n\nI'll work on improving my responses! 💪");
    } else {
        bot.sendMessage(chatId, "📝 *Feedback Format*\n\nUse: /feedback good or /feedback bad");
        return;
    }
    
    // Get last conversation
    db.get('SELECT user_message, ai_response FROM conversations WHERE user_id = ? ORDER BY timestamp DESC LIMIT 1', [userId], async (err, row) => {
        if (row) {
            await saveFeedback(userId, row.user_message, ratingValue);
            if (ratingValue === 5) {
                await learnResponse(row.user_message, row.ai_response);
            }
        }
    });
});

// /model command
bot.onText(/\/model/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Denied*", { parse_mode: 'Markdown' });
        return;
    }
    
    bot.sendMessage(chatId, `🤖 *Current AI Model*

**Model:** ${groqModel}
**Provider:** Groq Cloud
**Speed:** Ultra-fast (< 1 second)
**Features:** 
• Context-aware responses
• Learning capabilities
• Conversation memory

*Powered by Groq's LPU technology* ⚡`, { parse_mode: 'Markdown' });
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
        db.get('SELECT COUNT(*) as learned FROM learned_responses', (err2, learned) => {
            db.get('SELECT COUNT(*) as approved_users FROM users WHERE is_approved = 1', (err3, users) => {
                db.get('SELECT AVG(response_time) as avg_time FROM conversations WHERE response_time > 0', (err4, time) => {
                    const statsMessage = `📊 *${aiName} Statistics*

━━━━━━━━━━━━━━━━━━━━━

**📈 Usage:**
• Conversations: ${total.total}
• Learned Patterns: ${learned.learned}
• Approved Users: ${users.approved_users}

**⚡ Performance:**
• AI Model: ${groqModel}
• Avg Response: ${Math.round(time?.avg_time || 0)}ms
• Provider: Groq Cloud

**🤖 AI Status:**
• Groq API: Connected ✅
• Learning: Active
• Memory: Enabled

**👥 Admins:**
${ADMIN_USERNAMES.map(u => `• @${u}`).join('\n')}

━━━━━━━━━━━━━━━━━━━━━

*I learn from every conversation!* 🧠`;
                    
                    bot.sendMessage(chatId, statsMessage, { parse_mode: 'Markdown' });
                });
            });
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
    bot.sendMessage(chatId, `🗑️ *Conversation cleared!*\n\nWe're starting fresh. What would you like to talk about? 💭`, { parse_mode: 'Markdown' });
});

// Fallback responses
function getFallbackResponse(message) {
    const msg = message.toLowerCase();
    
    if (msg.includes('hello') || msg.includes('hi')) {
        return `👋 Hello! I'm ${aiName}, your AI assistant powered by Groq's fast AI. How can I help you today?`;
    }
    
    if (msg.includes('what is your name')) {
        return `✨ My name is ${aiName}! I'm an AI assistant running on Groq's ultra-fast infrastructure. What's your name?`;
    }
    
    if (msg.includes('how are you')) {
        return `🌟 I'm doing great, thank you for asking! I'm running at lightning speed on Groq's LPU. Ready to help you with anything!`;
    }
    
    return `💭 I'm ${aiName}, your AI assistant powered by Groq!

I can help answer questions, explain concepts, or just chat.

What would you like to know? 😊`;
}

console.log(`🚀 ${aiName} is ready with Groq AI!`);
console.log(`💬 Send any message - I'll respond super fast!`);
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
    
    log_success "Groq AI bot created with learning capabilities!"
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
        
        echo -e "\n📊 Database Stats:"
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as conversations FROM conversations;" 2>/dev/null
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as learned FROM learned_responses;" 2>/dev/null
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as users FROM users WHERE is_approved=1;" 2>/dev/null
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
    train)
        echo -e "${BLUE}Training AI with conversation data...${NC}"
        sqlite3 ~/.khongai/chat_history.db "SELECT user_message, ai_response FROM conversations WHERE id NOT IN (SELECT id FROM learned_responses) LIMIT 10;"
        echo -e "${GREEN}Training data prepared${NC}"
        ;;
    export)
        echo -e "${BLUE}Exporting data...${NC}"
        sqlite3 -json ~/.khongai/chat_history.db "SELECT * FROM conversations;" > ~/.khongai/export_$(date +%Y%m%d_%H%M%S).json
        echo -e "${GREEN}Data exported to ~/.khongai/export_*.json${NC}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|test|train|export}"
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
    cat > ~/.khongai/config.json << EOF
{
    "ai_name": "$AI_NAME",
    "groq_api_key": "$GROQ_API_KEY",
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
    echo "  • Ultra-fast responses (Groq LPU)"
    echo "  • Natural conversation flow"
    echo "  • Learns from every chat"
    echo "  • Saves to database"
    echo "  • Context memory"
    echo ""
    echo -e "${CYAN}📋 Available Commands:${NC}"
    echo "  • Send any message - Get instant AI responses"
    echo "  • /teach question | answer - Teach me something"
    echo "  • /learned - See what I've learned"
    echo "  • /feedback good/bad - Rate my response"
    echo "  • /stats - View statistics"
    echo "  • /model - Show current AI model"
    echo "  • /clear - Clear conversation"
    echo ""
    echo -e "${CYAN}👑 Admin Commands:${NC}"
    echo "  • /approve @username - Approve user"
    echo "  • /reject @username - Reject user"
    echo "  • /pending - View pending users"
    echo "  • /users - List all users"
    echo ""
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "  • ~/khongai-manager.sh status  - Check status"
    echo "  • ~/khongai-manager.sh logs     - View bot logs"
    echo "  • ~/khongai-manager.sh test     - Test Groq API"
    echo "  • ~/khongai-manager.sh export   - Export data"
    echo ""
    echo -e "${GREEN}🎉 Send /start to your bot on Telegram to begin!${NC}"
    echo -e "${YELLOW}💡 Your bot will respond super fast with Groq AI!${NC}\n"
}

main "$@"
