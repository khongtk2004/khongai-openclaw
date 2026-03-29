#!/bin/bash
# KhongAI Installer - ChatGPT Style with Natural Conversation

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
    echo "║              ChatGPT-Style AI with Natural Conversation                       ║"
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

# Get configuration
get_config() {
    echo -e "\n${BOLD}${CYAN}🤖 AI Configuration${NC}\n"
    
    read -p "Enter AI name [default: KhongAI]: " AI_NAME
    AI_NAME=${AI_NAME:-KhongAI}
    
    echo -e "\n${YELLOW}Select AI response style:${NC}"
    echo "  1) ChatGPT Style (Conversational, helpful, detailed)"
    echo "  2) Friendly & Casual (Relaxed, approachable)"
    echo "  3) Professional & Formal (Business-like)"
    echo "  4) Creative & Imaginative (Unique perspectives)"
    read -p "Select [1-4, default: 1]: " style_choice
    
    case $style_choice in
        2)
            AI_PERSONALITY="casual, friendly, and approachable"
            RESPONSE_STYLE="casual and friendly"
            ;;
        3)
            AI_PERSONALITY="professional, formal, and precise"
            RESPONSE_STYLE="professional and formal"
            ;;
        4)
            AI_PERSONALITY="creative, imaginative, and artistic"
            RESPONSE_STYLE="creative and unique"
            ;;
        *)
            AI_PERSONALITY="helpful, knowledgeable, and conversational"
            RESPONSE_STYLE="conversational and detailed like ChatGPT"
            ;;
    esac
    
    # Ollama Model
    echo -e "\n${YELLOW}Select AI model:${NC}"
    echo "  1) neural-chat (Best for conversation - Recommended)"
    echo "  2) llama2 (Balanced performance)"
    echo "  3) mistral (Very intelligent)"
    echo "  4) phi (Fast and lightweight)"
    read -p "Select [1-4, default: 1]: " model_choice
    
    case $model_choice in
        2) OLLAMA_MODEL="llama2" ;;
        3) OLLAMA_MODEL="mistral" ;;
        4) OLLAMA_MODEL="phi" ;;
        *) OLLAMA_MODEL="neural-chat" ;;
    esac
    
    # OpenAI API (optional)
    echo -e "\n${YELLOW}Enter OpenAI ChatGPT API Key (optional - for better responses):${NC}"
    echo -e "${BLUE}(Get from https://platform.openai.com/api-keys)${NC}"
    read -p "➤ " OPENAI_API_KEY
    
    log_success "AI configured: $AI_NAME with $OLLAMA_MODEL model"
}

# Get admin usernames
get_admin_usernames() {
    echo -e "\n${BOLD}${CYAN}👥 Admin Users Setup${NC}\n"
    echo -e "${YELLOW}Enter Telegram usernames who can approve users (without @)${NC}"
    echo -e "${BLUE}Separate multiple with commas${NC}"
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
    mkdir -p ~/.khongai/{models,data,chat_history,training_data,logs,conversations}
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
    
    docker compose up -d
    log_success "OpenClaw container started"
}

# Create advanced ChatGPT-like bot
create_chatgpt_bot() {
    log_step "Creating ChatGPT-style bot with natural conversation..."
    
    cd ~/khongai-telegram-bot
    
    cat > package.json << 'EOF'
{
  "name": "khongai-chatgpt-bot",
  "version": "4.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6",
    "marked": "^11.0.0"
  }
}
EOF
    
    npm install
    
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
const marked = require('marked');

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const ollamaModel = process.env.OLLAMA_MODEL || 'neural-chat';
const aiName = process.env.AI_NAME || 'KhongAI';
const aiPersonality = process.env.AI_PERSONALITY || 'helpful';
const responseStyle = process.env.RESPONSE_STYLE || 'conversational';
const ADMIN_USERNAMES = JSON.parse(process.env.ADMIN_USERNAMES || '["khongtk2004"]');

const bot = new TelegramBot(token, { polling: true });

// Initialize database
const db = new sqlite3.Database(path.join(process.env.HOME, '.khongai', 'chat_history.db'));

// Create all tables
db.serialize(() => {
    // Users table
    db.run(`CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT UNIQUE,
        username TEXT,
        first_name TEXT,
        is_approved BOOLEAN DEFAULT 0,
        is_admin BOOLEAN DEFAULT 0,
        approved_by TEXT,
        approved_at DATETIME,
        registered_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
    
    // Conversations table
    db.run(`CREATE TABLE IF NOT EXISTS conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        user_message TEXT,
        ai_response TEXT,
        model_used TEXT,
        response_time INTEGER,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
    
    // Learned patterns table
    db.run(`CREATE TABLE IF NOT EXISTS learned_patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern TEXT UNIQUE,
        response TEXT,
        context TEXT,
        usage_count INTEGER DEFAULT 1,
        effectiveness INTEGER DEFAULT 0,
        last_used DATETIME
    )`);
    
    // User context table
    db.run(`CREATE TABLE IF NOT EXISTS user_context (
        user_id TEXT PRIMARY KEY,
        context TEXT,
        preferences TEXT,
        last_active DATETIME
    )`);
    
    // Training data table
    db.run(`CREATE TABLE IF NOT EXISTS training_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_message TEXT,
        ai_response TEXT,
        quality_score INTEGER,
        used_for_training BOOLEAN DEFAULT 0,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
});

// Store conversation history per user
const userConversations = new Map();

console.log(`🤖 ${aiName} ChatGPT-Style Bot Started`);
console.log(`Response Style: ${responseStyle}`);
console.log(`Model: ${ollamaModel}`);
console.log(`Admins: ${ADMIN_USERNAMES.join(', ')}`);

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

// Helper: Check if user is approved
async function isApproved(userId) {
    return new Promise((resolve) => {
        db.get('SELECT is_approved FROM users WHERE user_id = ?', [userId], (err, row) => {
            resolve(row && row.is_approved === 1);
        });
    });
}

// Helper: Save conversation
async function saveConversation(userId, userMessage, aiResponse, modelUsed, responseTime) {
    return new Promise((resolve) => {
        db.run(
            'INSERT INTO conversations (user_id, user_message, ai_response, model_used, response_time) VALUES (?, ?, ?, ?, ?)',
            [userId, userMessage, aiResponse, modelUsed, responseTime],
            (err) => resolve(!err)
        );
    });
}

// Helper: Save for training
async function saveForTraining(userMessage, aiResponse, qualityScore = 3) {
    return new Promise((resolve) => {
        db.run(
            'INSERT INTO training_data (user_message, ai_response, quality_score) VALUES (?, ?, ?)',
            [userMessage, aiResponse, qualityScore],
            (err) => resolve(!err)
        );
    });
}

// Helper: Learn pattern
async function learnPattern(userMessage, aiResponse, context) {
    const pattern = userMessage.toLowerCase().trim();
    return new Promise((resolve) => {
        db.get('SELECT * FROM learned_patterns WHERE pattern = ?', [pattern], (err, row) => {
            if (row) {
                db.run('UPDATE learned_patterns SET usage_count = usage_count + 1, last_used = CURRENT_TIMESTAMP WHERE pattern = ?', [pattern]);
            } else {
                db.run('INSERT INTO learned_patterns (pattern, response, context) VALUES (?, ?, ?)', [pattern, aiResponse, context]);
            }
            resolve();
        });
    });
}

// Main AI response function - ChatGPT style
async function getChatGPTResponse(userId, userMessage, conversationHistory) {
    const startTime = Date.now();
    
    // Check for learned patterns first
    const learnedPattern = await checkLearnedPattern(userMessage);
    if (learnedPattern && Math.random() < 0.4) {
        await saveConversation(userId, userMessage, learnedPattern, 'learned', Date.now() - startTime);
        return learnedPattern;
    }
    
    // Build conversation context
    const context = buildContext(conversationHistory);
    
    // Try ChatGPT API first if available
    if (openaiApiKey) {
        const chatGPTResponse = await callChatGPTAPI(userMessage, context);
        if (chatGPTResponse) {
            await saveConversation(userId, userMessage, chatGPTResponse, 'chatgpt', Date.now() - startTime);
            await learnPattern(userMessage, chatGPTResponse, context);
            await saveForTraining(userMessage, chatGPTResponse, 5);
            return chatGPTResponse;
        }
    }
    
    // Use Ollama with ChatGPT-style prompt
    const ollamaResponse = await callOllamaChatGPT(userMessage, context, conversationHistory);
    if (ollamaResponse) {
        await saveConversation(userId, userMessage, ollamaResponse, 'ollama', Date.now() - startTime);
        await learnPattern(userMessage, ollamaResponse, context);
        await saveForTraining(userMessage, ollamaResponse, 4);
        return ollamaResponse;
    }
    
    // Fallback responses
    return getFallbackResponse(userMessage);
}

// Call ChatGPT API
async function callChatGPTAPI(message, context) {
    try {
        const systemPrompt = `You are ${aiName}, an AI assistant with a ${aiPersonality} personality. 
Your responses should be ${responseStyle}.
Be conversational, helpful, and detailed like ChatGPT.
Use natural language, emojis occasionally, and format responses nicely.`;

        const response = await axios.post('https://api.openai.com/v1/chat/completions', {
            model: 'gpt-3.5-turbo',
            messages: [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: context + message }
            ],
            temperature: 0.8,
            max_tokens: 500,
            presence_penalty: 0.6,
            frequency_penalty: 0.5
        }, {
            headers: { 'Authorization': `Bearer ${openaiApiKey}` },
            timeout: 20000
        });
        
        return response.data.choices[0].message.content;
    } catch (error) {
        return null;
    }
}

// Call Ollama with ChatGPT-style prompt
async function callOllamaChatGPT(message, context, history) {
    try {
        // Build conversation history for context
        let historyText = '';
        if (history && history.length > 0) {
            const lastFew = history.slice(-5);
            historyText = lastFew.map(h => `${h.role}: ${h.content}`).join('\n');
        }
        
        const prompt = `You are ${aiName}, an AI assistant with a ${aiPersonality} personality.

Your responses should be ${responseStyle}.

Guidelines:
- Be conversational and natural like ChatGPT
- Provide detailed, helpful answers
- Use markdown formatting for clarity
- Add emojis occasionally for personality
- Break down complex topics
- Ask clarifying questions when needed
- Be engaging and interactive

Conversation history:
${historyText}

User: ${message}

${aiName}: Let me provide a helpful, detailed response.`;

        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: {
                temperature: 0.8,
                top_k: 50,
                top_p: 0.95,
                repeat_penalty: 1.1,
                num_predict: 500
            }
        }, { timeout: 30000 });
        
        let aiResponse = response.data.response;
        // Clean up and format
        aiResponse = aiResponse.replace(`${aiName}:`, '').trim();
        
        return aiResponse;
    } catch (error) {
        console.error('Ollama error:', error.message);
        return null;
    }
}

// Check learned patterns
async function checkLearnedPattern(message) {
    return new Promise((resolve) => {
        const msg = message.toLowerCase().trim();
        db.get('SELECT response FROM learned_patterns WHERE pattern = ? AND effectiveness > 0 ORDER BY usage_count DESC LIMIT 1', [msg], (err, row) => {
            if (row) {
                db.run('UPDATE learned_patterns SET last_used = CURRENT_TIMESTAMP WHERE pattern = ?', [msg]);
                resolve(row.response);
            } else {
                // Check for partial matches
                db.all('SELECT pattern, response FROM learned_patterns WHERE effectiveness > 0', (err, rows) => {
                    if (rows) {
                        for (const row of rows) {
                            if (msg.includes(row.pattern) || row.pattern.includes(msg)) {
                                resolve(row.response);
                                return;
                            }
                        }
                    }
                    resolve(null);
                });
            }
        });
    });
}

// Build context from conversation history
function buildContext(history) {
    if (!history || history.length === 0) return '';
    return history.map(h => `${h.role}: ${h.content}`).join('\n') + '\n';
}

// Get user context
async function getUserContext(userId) {
    return new Promise((resolve) => {
        db.get('SELECT context, preferences FROM user_context WHERE user_id = ?', [userId], (err, row) => {
            if (row) {
                try {
                    resolve({
                        context: JSON.parse(row.context || '[]'),
                        preferences: JSON.parse(row.preferences || '{}')
                    });
                } catch {
                    resolve({ context: [], preferences: {} });
                }
            } else {
                resolve({ context: [], preferences: {} });
            }
        });
    });
}

// Update user context
async function updateUserContext(userId, context, preferences) {
    return new Promise((resolve) => {
        db.run(
            'INSERT OR REPLACE INTO user_context (user_id, context, preferences, last_active) VALUES (?, ?, ?, CURRENT_TIMESTAMP)',
            [userId, JSON.stringify(context), JSON.stringify(preferences || {})],
            () => resolve()
        );
    });
}

// Fallback responses (ChatGPT style)
function getFallbackResponse(message) {
    const msg = message.toLowerCase();
    
    if (msg.includes('hello') || msg.includes('hi') || msg.includes('hey')) {
        return `👋 Hello! I'm ${aiName}, your AI assistant. 

I'm here to help you with questions, tasks, or just to chat! 

What would you like to know or discuss today? 😊`;
    }
    
    if (msg.includes('how are you')) {
        return `🌟 I'm doing fantastic, thank you for asking!

I'm running on ${ollamaModel} model and I'm ready to help you with anything you need. 

How can I assist you today? 💫`;
    }
    
    if (msg.includes('what is your name')) {
        return `✨ My name is ${aiName}!

I'm an AI assistant designed to help you with questions, provide information, and have natural conversations.

Think of me as your personal AI friend who's always ready to help! 

What's your name? 😊`;
    }
    
    if (msg.includes('thank')) {
        return `🎉 You're very welcome! 

I'm glad I could help. Is there anything else you'd like to know or any other questions I can answer for you?

I'm here whenever you need me! 💫`;
    }
    
    if (msg.includes('what is') || msg.includes('explain') || msg.includes('tell me about')) {
        return `📚 That's a great question!

I'd love to help explain that. Let me think about it for a moment...

${message}

To give you the best answer, could you tell me a bit more about what specifically you'd like to know? 

I'm here to provide detailed, helpful explanations! 💡`;
    }
    
    if (msg.includes('how to') || msg.includes('how do i')) {
        return `💡 Great question about how to do that!

I can help guide you through this. Here's what I understand about ${message.substring(0, 50)}...

To give you the most helpful step-by-step guidance, could you share a bit more context about what you're trying to accomplish?

I'm here to help you learn and succeed! 🚀`;
    }
    
    if (msg.includes('why')) {
        return `🤔 That's an interesting "why" question!

Let me think about the reasons behind this...

${message}

The answer might depend on several factors. Is there a specific aspect you're most curious about?

I love exploring "why" questions - they help us understand things better! 💭`;
    }
    
    // Default engaging response
    return `💭 Thanks for sharing that with me, ${aiName} here!

I'm interested in what you're saying about "${message.substring(0, 50)}${message.length > 50 ? '...' : ''}"

To give you the best response, could you tell me a bit more about what you'd like to know or discuss?

I'm here to help with detailed answers, explanations, or just good conversation! 

What specific aspect interests you most? 😊`;
}

// Command: /start
bot.onText(/\/start/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const firstName = msg.from.first_name || '';
    
    // Register user
    db.run('INSERT OR IGNORE INTO users (user_id, username, first_name) VALUES (?, ?, ?)', [userId, username, firstName]);
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);
    
    if (approved || admin) {
        const welcomeMessage = `🌟 *Welcome back, ${firstName}!* 🌟

I'm **${aiName}**, your AI assistant with ChatGPT-style conversation!

━━━━━━━━━━━━━━━━━━━━━

✨ *What makes me special:*
• 💬 Natural, engaging conversations
• 🧠 I learn from every interaction
• 📚 Detailed, helpful responses
• 🎯 Context-aware answers
• 💾 Remember our conversations

━━━━━━━━━━━━━━━━━━━━━

📋 *Commands:*

**💬 Chat**
• Just send any message to talk with me
• I'll respond like ChatGPT - natural and detailed!

**👑 Admin Commands** (Admins only)
• /approve @username - Approve user
• /reject @username - Reject user  
• /pending - View pending users
• /users - List all users

**📊 Info**
• /stats - View statistics
• /clear - Clear conversation history

━━━━━━━━━━━━━━━━━━━━━

💡 *Try asking me:*
• "What is ChatGPT and how does it work?"
• "Explain quantum computing simply"
• "Help me understand machine learning"
• "Tell me an interesting fact"
• "What's the weather like?"

━━━━━━━━━━━━━━━━━━━━━

*Let's have a great conversation!* 🚀

Just send me any message to start chatting!`;
        
        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        // Request approval
        db.run('INSERT OR REPLACE INTO pending_approvals (user_id, username, first_name, request_message) VALUES (?, ?, ?, ?)', 
            [userId, username, firstName, "User requested access"]);
        
        bot.sendMessage(chatId, `⏳ *Access Request Submitted* 🙏

Hi ${firstName}! Thanks for your interest in using ${aiName}.

Your request has been sent to the administrators for approval.

**What happens next:**
1. An admin will review your request
2. You'll receive a notification when approved
3. Then you can start chatting with me!

*Estimated wait time:* Usually within 24 hours

Thank you for your patience! 🌟`, { parse_mode: 'Markdown' });
        
        // Notify admins
        for (const adminUsername of ADMIN_USERNAMES) {
            bot.sendMessage(chatId, `👥 *New User Request*

**User:** @${username || firstName}
**ID:** ${userId}
**Time:** ${new Date().toLocaleString()}

Use: /approve @${username || userId} to approve
Use: /reject @${username || userId} to reject

*Pending approvals:* /pending`, { parse_mode: 'Markdown' });
        }
    }
});

// Handle messages - Main chat handler
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    
    if (!text || text.startsWith('/')) return;
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);
    
    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nPlease wait for admin approval before chatting.\n\nContact an admin if you have questions.", { parse_mode: 'Markdown' });
        return;
    }
    
    // Send typing indicator
    bot.sendChatAction(chatId, 'typing');
    
    // Get conversation history
    let history = userConversations.get(userId) || [];
    
    // Get AI response
    const response = await getChatGPTResponse(userId, text, history);
    
    // Update history
    history.push({ role: 'user', content: text });
    history.push({ role: 'assistant', content: response });
    if (history.length > 20) history = history.slice(-20);
    userConversations.set(userId, history);
    
    // Update user context
    await updateUserContext(userId, history, { last_topic: text.substring(0, 100) });
    
    // Send response with formatting
    bot.sendMessage(chatId, response, { parse_mode: 'Markdown' });
});

// /approve command
bot.onText(/\/approve (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const target = match[1].replace('@', '');
    
    const admin = await isAdmin(userId, username);
    if (!admin) {
        bot.sendMessage(chatId, "❌ *Access Denied*\n\nYou don't have permission to use this command.", { parse_mode: 'Markdown' });
        return;
    }
    
    db.get('SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?', [target, target], async (err, user) => {
        if (user) {
            db.run('UPDATE users SET is_approved = 1, approved_by = ?, approved_at = CURRENT_TIMESTAMP WHERE user_id = ?', [username, user.user_id]);
            bot.sendMessage(chatId, `✅ *User Approved*\n\n@${user.username || user.first_name} can now use the bot!`);
            
            bot.sendMessage(user.user_id, `🎉 *Access Granted!* 🎉

You've been approved to chat with ${aiName}!

Send /start to begin our conversation!

I'm excited to chat with you! 🚀`, { parse_mode: 'Markdown' });
        } else {
            bot.sendMessage(chatId, `❌ *User Not Found*\n\nCould not find user: ${target}`);
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
    
    db.get('SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?', [target, target], async (err, user) => {
        if (user) {
            bot.sendMessage(chatId, `❌ *User Rejected*\n\n@${user.username || user.first_name} has been rejected.`);
            
            bot.sendMessage(user.user_id, `❌ *Access Denied*

Your request to use ${aiName} has been reviewed and not approved at this time.

If you believe this is an error, please contact an administrator.`);
        } else {
            bot.sendMessage(chatId, `❌ *User Not Found*`);
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
    
    db.all('SELECT user_id, username, first_name, requested_at FROM pending_approvals ORDER BY requested_at DESC', (err, rows) => {
        if (!rows || rows.length === 0) {
            bot.sendMessage(chatId, "📋 *No Pending Users*\n\nThere are no users waiting for approval.");
            return;
        }
        
        let message = "👥 *Pending Approvals*\n\n";
        for (const user of rows) {
            message += `• @${user.username || user.first_name}\n  ID: ${user.user_id}\n  Requested: ${user.requested_at}\n\n`;
        }
        message += `\nUse /approve @username to approve\nUse /reject @username to reject`;
        
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
    
    db.all('SELECT user_id, username, first_name, is_approved, is_admin, approved_at FROM users ORDER BY registered_at DESC', (err, rows) => {
        let message = "👥 *Registered Users*\n\n";
        for (const user of rows) {
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
    const username = msg.from.username || '';
    
    const approved = await isApproved(userId);
    const admin = await isAdmin(userId, username);
    
    if (!approved && !admin) {
        bot.sendMessage(chatId, "⏳ *Access Pending*", { parse_mode: 'Markdown' });
        return;
    }
    
    db.get('SELECT COUNT(*) as total FROM conversations', (err, total) => {
        db.get('SELECT COUNT(*) as approved_users FROM users WHERE is_approved = 1', (err2, users) => {
            db.get('SELECT COUNT(*) as learned FROM learned_patterns', (err3, learned) => {
                const statsMessage = `📊 *${aiName} Statistics*

━━━━━━━━━━━━━━━━━━━━━

**📈 Usage Stats:**
• Total Conversations: ${total.total}
• Approved Users: ${users.approved_users}
• Learned Patterns: ${learned.learned}

**🤖 AI Configuration:**
• Model: ${ollamaModel}
• Personality: ${aiPersonality}
• Style: ${responseStyle}
• ChatGPT: ${openaiApiKey ? 'Connected ✅' : 'Not connected'}

**👥 Admins:**
${ADMIN_USERNAMES.map(u => `• @${u}`).join('\n')}

━━━━━━━━━━━━━━━━━━━━━

*I'm learning and improving from every conversation!* 🌟

The more we chat, the better I understand you!`;
                
                bot.sendMessage(chatId, statsMessage, { parse_mode: 'Markdown' });
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
    
    userConversations.delete(userId);
    await updateUserContext(userId, [], {});
    
    bot.sendMessage(chatId, `🗑️ *Conversation Cleared!*

I've reset our conversation history.

We can start fresh now - feel free to ask me anything! 

What would you like to talk about? 💭`, { parse_mode: 'Markdown' });
});

// Error handling
bot.on('polling_error', (error) => {
    console.error('Polling error:', error.message);
});

console.log(`🚀 ${aiName} is ready for ChatGPT-style conversations!`);
console.log(`💬 Response style: ${responseStyle}`);
BOTEOF
    
    # Create start script
    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export OLLAMA_MODEL="$OLLAMA_MODEL"
export AI_NAME="$AI_NAME"
export AI_PERSONALITY="$AI_PERSONALITY"
export RESPONSE_STYLE="$RESPONSE_STYLE"
export ADMIN_USERNAMES='$ADMIN_LIST_JSON'

cd "$HOME/khongai-telegram-bot"
pkill -f "node bot.js" 2>/dev/null
nohup node bot.js > bot.log 2>&1 &
echo \$! > bot.pid
echo "✅ ${AI_NAME} bot started!"
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
    
    log_success "ChatGPT-style bot created!"
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
        echo -e "${BLUE}Stopping services...${NC}"
        cd ~/khongai && docker compose down
        cd ~/khongai-telegram-bot && ./stop.sh
        sudo systemctl stop ollama
        echo -e "${GREEN}✓ Services stopped${NC}"
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
        
        echo -e "\n📊 Database Stats:"
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as conversations FROM conversations;" 2>/dev/null
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as patterns FROM learned_patterns;" 2>/dev/null
        sqlite3 ~/.khongai/chat_history.db "SELECT COUNT(*) as approved FROM users WHERE is_approved=1;" 2>/dev/null
        ;;
    train)
        echo -e "${BLUE}Training AI with conversation data...${NC}"
        sqlite3 ~/.khongai/chat_history.db "SELECT user_message, ai_response FROM training_data WHERE used_for_training=0 LIMIT 50;"
        echo -e "${GREEN}Training data prepared${NC}"
        ;;
    export)
        echo -e "${BLUE}Exporting data...${NC}"
        sqlite3 -json ~/.khongai/chat_history.db "SELECT * FROM conversations;" > ~/.khongai/export_$(date +%Y%m%d_%H%M%S).json
        echo -e "${GREEN}Data exported${NC}"
        ;;
    logs)
        docker logs khongai --tail 50 -f
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|train|export|logs|bot-logs}"
        ;;
esac
EOF
    
    chmod +x ~/khongai-manager.sh
}

# Main installation
main() {
    print_banner
    
    install_zstd
    get_config
    get_admin_usernames
    create_directories
    
    # Get Telegram token
    echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Token${NC}\n"
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
    "response_style": "$RESPONSE_STYLE",
    "ollama_model": "$OLLAMA_MODEL",
    "admins": ${ADMIN_LIST_JSON},
    "install_date": "$(date)"
}
EOF
    
    install_ollama
    create_openclaw_container
    create_chatgpt_bot
    create_manager
    
    ~/khongai-manager.sh start
    
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ ${AI_NAME} ChatGPT-Style Bot installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}🤖 ChatGPT-Style Features:${NC}"
    echo "  • Natural, conversational responses"
    echo "  • Detailed answers like ChatGPT"
    echo "  • Learns from every conversation"
    echo "  • Remembers context"
    echo "  • Provides examples and explanations"
    echo ""
    echo -e "${CYAN}📋 Example Conversations:${NC}"
    echo "  User: What is ChatGPT?"
    echo "  ${AI_NAME}: ChatGPT is an AI chatbot created by OpenAI..."
    echo ""
    echo "  User: How does machine learning work?"
    echo "  ${AI_NAME}: Great question! Machine learning is a subset of AI..."
    echo ""
    echo -e "${CYAN}👥 Admin Commands:${NC}"
    echo "  • /approve @username - Approve user"
    echo "  • /reject @username - Reject user"
    echo "  • /pending - View pending"
    echo "  • /users - List all users"
    echo ""
    echo -e "${GREEN}🎉 Send /start to your bot to begin ChatGPT-style conversations!${NC}\n"
}

main "$@"
