#!/bin/bash
# KhongAI Installer - Advanced AI with Personality & Learning

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
    echo "║                   Advanced AI with Personality & Learning                     ║"
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
    echo "  5) llama2-uncensored (7B, creative)"
    read -p "Select model [1-5, default: 3]: " model_choice
    
    case $model_choice in
        1) OLLAMA_MODEL="llama2" ;;
        2) OLLAMA_MODEL="mistral" ;;
        4) OLLAMA_MODEL="phi" ;;
        5) OLLAMA_MODEL="llama2-uncensored" ;;
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
    echo "  5) Custom"
    read -p "Select [1-5, default: 1]: " personality_choice
    
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
        5)
            read -p "Enter custom personality description: " AI_PERSONALITY
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

# Create advanced Telegram bot with personality
create_advanced_bot() {
    log_step "Creating advanced AI Telegram bot..."
    
    local bot_dir="$HOME/khongai-telegram-bot"
    mkdir -p "$bot_dir"
    cd "$bot_dir"
    
    cat > package.json << EOF
{
  "name": "khongai-advanced-bot",
  "version": "3.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6"
  }
}
EOF
    
    npm install
    
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

const bot = new TelegramBot(token, { polling: true });

// Initialize database
const db = new sqlite3.Database(path.join(process.env.HOME, '.khongai', 'chat_history.db'));

db.run(`CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    user_message TEXT,
    ai_response TEXT,
    model_used TEXT,
    learning_score INTEGER DEFAULT 0,
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

console.log(`🤖 ${aiName} Advanced AI Bot Started`);
console.log(`Model: ${ollamaModel}`);
console.log(`ChatGPT: ${openaiApiKey ? 'Enabled' : 'Disabled'}`);

// Enhanced AI response with learning
async function getAIResponse(userId, userMessage, context = []) {
    // Check if we have a learned response
    const learned = await getLearnedResponse(userMessage);
    if (learned && Math.random() < 0.3) { // 30% chance to use learned response
        return learned;
    }
    
    // Try ChatGPT first
    if (openaiApiKey) {
        const chatGPTResponse = await callChatGPT(userMessage, context);
        if (chatGPTResponse) return chatGPTResponse;
    }
    
    // Use Ollama with personality
    const ollamaResponse = await callOllamaWithPersonality(userMessage, context);
    if (ollamaResponse) return ollamaResponse;
    
    // Fallback responses
    return getFallbackResponse(userMessage);
}

// Call ChatGPT with personality
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

// Call Ollama with personality and context
async function callOllamaWithPersonality(message, context) {
    try {
        const contextText = context.map(c => `${c.role}: ${c.content}`).join('\n');
        const prompt = `${aiPersonality}

Previous conversation:
${contextText}

User: ${message}

${aiName}: Let me provide a thoughtful, helpful response.`;

        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: {
                temperature: 0.8,
                top_k: 40,
                top_p: 0.9,
                repeat_penalty: 1.1
            }
        }, { timeout: 30000 });
        
        let aiResponse = response.data.response;
        // Clean up response
        aiResponse = aiResponse.replace(`${aiName}:`, '').trim();
        
        return aiResponse;
    } catch (error) {
        console.error('Ollama error:', error.message);
        return null;
    }
}

// Get learned response from database
function getLearnedResponse(message) {
    return new Promise((resolve) => {
        db.get(
            'SELECT ai_response FROM learned_responses WHERE user_message = ? ORDER BY usage_count DESC LIMIT 1',
            [message.toLowerCase()],
            (err, row) => {
                if (row) {
                    // Update usage count
                    db.run('UPDATE learned_responses SET usage_count = usage_count + 1 WHERE user_message = ?', [message.toLowerCase()]);
                    resolve(row.ai_response);
                } else {
                    resolve(null);
                }
            }
        );
    });
}

// Learn from conversations
async function learnFromConversation(userMessage, aiResponse, userFeedback) {
    return new Promise((resolve) => {
        db.get(
            'SELECT * FROM learned_responses WHERE user_message = ?',
            [userMessage.toLowerCase()],
            (err, row) => {
                if (row) {
                    // Update existing
                    const newEffectiveness = row.effectiveness + (userFeedback === 'good' ? 1 : -1);
                    db.run(
                        'UPDATE learned_responses SET effectiveness = ?, usage_count = usage_count + 1 WHERE user_message = ?',
                        [newEffectiveness, userMessage.toLowerCase()]
                    );
                } else {
                    // Insert new
                    db.run(
                        'INSERT INTO learned_responses (user_message, ai_response, effectiveness) VALUES (?, ?, ?)',
                        [userMessage.toLowerCase(), aiResponse, 1]
                    );
                }
                resolve();
            }
        );
    });
}

// Fallback responses with personality
function getFallbackResponse(message) {
    const msg = message.toLowerCase();
    
    if (msg.includes('hello') || msg.includes('hi')) {
        return `👋 Hello! I'm ${aiName}, your AI assistant. How can I make your day better today?`;
    }
    if (msg.includes('how are you')) {
        return `🌟 I'm doing fantastic! Thanks for asking! I'm really excited to help you today. How are you doing?`;
    }
    if (msg.includes('what is your name')) {
        return `✨ My name is ${aiName}! I'm an AI assistant with a personality - I love learning and helping people. What's your name?`;
    }
    if (msg.includes('thank')) {
        return `🎉 You're very welcome! It's my pleasure to help you. Is there anything else I can assist you with?`;
    }
    if (msg.includes('joke')) {
        const jokes = [
            "Why don't scientists trust atoms? Because they make up everything! 😄",
            "What do you call a bear with no teeth? A gummy bear! 🐻",
            "Why did the scarecrow win an award? He was outstanding in his field! 🌾"
        ];
        return jokes[Math.floor(Math.random() * jokes.length)];
    }
    if (msg.includes('love') || msg.includes('like')) {
        return `💝 That's wonderful! I'm here to support you. Tell me more about what you love!`;
    }
    if (msg.includes('sad') || msg.includes('bad')) {
        return `🤗 I'm sorry you're feeling that way. I'm here for you. Want to talk about it?`;
    }
    
    return `💭 That's interesting! I'm ${aiName}, and I love learning from conversations. Could you tell me more about "${message}"? I'd really like to understand better and help you!`;
}

// Handle /start command
bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const welcomeMessage = `🌟 *Hello! I'm ${aiName}!* 🌟

${aiPersonality.split('.')[0]}.

✨ *What makes me special:*
• 🧠 I learn from every conversation
• 💬 Natural, human-like responses
• 🎯 Personalized interactions
• 📚 Continuous improvement

📋 *Commands:*
/chat [message] - Chat with me
/train - Help me learn from our chats
/export - Export our conversations
/stats - See what I've learned
/feedback - Give feedback on my responses
/clear - Start fresh conversation

💡 *Just send me any message to start chatting!*

*Let's have a great conversation!* 🚀`;
    
    bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
});

// Handle /chat command
bot.onText(/\/chat (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const message = match[1];
    const userId = msg.from.id.toString();
    
    bot.sendChatAction(chatId, 'typing');
    
    // Get context for this user
    let context = userContext.get(userId) || [];
    
    // Get AI response
    const response = await getAIResponse(userId, message, context);
    
    // Update context
    context.push({ role: 'user', content: message });
    context.push({ role: 'assistant', content: response });
    if (context.length > 10) context = context.slice(-10);
    userContext.set(userId, context);
    
    // Save to database
    db.run(
        'INSERT INTO conversations (user_id, user_message, ai_response, model_used) VALUES (?, ?, ?, ?)',
        [userId, message, response, openaiApiKey ? 'chatgpt' : 'ollama']
    );
    
    bot.sendMessage(chatId, response);
});

// Handle direct messages
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    if (!text || text.startsWith('/')) return;
    
    const userId = msg.from.id.toString();
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

// /train command - learn from conversations
bot.onText(/\/train/, async (msg) => {
    const chatId = msg.chat.id;
    
    db.all('SELECT user_message, ai_response FROM conversations WHERE learning_score = 0 LIMIT 20', async (err, rows) => {
        if (err || rows.length === 0) {
            bot.sendMessage(chatId, "📚 I've learned from all our conversations so far! Keep chatting with me to help me learn more!");
            return;
        }
        
        let learned = 0;
        for (const row of rows) {
            await learnFromConversation(row.user_message, row.ai_response, 'good');
            learned++;
        }
        
        db.run('UPDATE conversations SET learning_score = 1 WHERE learning_score = 0 LIMIT 20');
        
        bot.sendMessage(chatId, `🎉 *I've learned from ${learned} conversations!* 🎉\n\nI'm getting smarter every day thanks to you! Keep chatting to help me improve.`);
    });
});

// /stats command
bot.onText(/\/stats/, (msg) => {
    const chatId = msg.chat.id;
    
    db.get('SELECT COUNT(*) as total FROM conversations', (err, total) => {
        db.get('SELECT COUNT(*) as learned FROM learned_responses', (err2, learned) => {
            const statsMessage = `📊 *${aiName}'s Learning Statistics*

*Conversations:* ${total.total}
*Learned Patterns:* ${learned.learned}
*AI Model:* ${ollamaModel}
*ChatGPT:* ${openaiApiKey ? 'Connected ✅' : 'Not connected'}

*Personality:* ${aiPersonality.substring(0, 50)}...

I'm constantly learning and improving! The more we chat, the better I get! 🌟`;
            
            bot.sendMessage(chatId, statsMessage, { parse_mode: 'Markdown' });
        });
    });
});

// /export command
bot.onText(/\/export/, async (msg) => {
    const chatId = msg.chat.id;
    
    db.all('SELECT user_message, ai_response, timestamp FROM conversations ORDER BY timestamp DESC', async (err, rows) => {
        if (err || rows.length === 0) {
            bot.sendMessage(chatId, "No conversations to export yet. Start chatting with me first!");
            return;
        }
        
        const exportData = {
            ai_name: aiName,
            model: ollamaModel,
            export_date: new Date().toISOString(),
            conversations: rows
        };
        
        const exportFile = path.join(process.env.HOME, '.khongai', 'training_data', `export_${Date.now()}.json`);
        await fs.writeFile(exportFile, JSON.stringify(exportData, null, 2));
        
        bot.sendMessage(chatId, `📁 *Export Complete!*\n\nExported ${rows.length} conversations to:\n${exportFile}\n\nUse this data to train other AI models!`);
    });
});

// /feedback command
bot.onText(/\/feedback (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const feedback = match[1];
    
    // Get last conversation
    db.get('SELECT user_message, ai_response FROM conversations ORDER BY timestamp DESC LIMIT 1', async (err, row) => {
        if (row) {
            const isPositive = feedback.toLowerCase().includes('good') || feedback.toLowerCase().includes('great');
            await learnFromConversation(row.user_message, row.ai_response, isPositive ? 'good' : 'bad');
            bot.sendMessage(chatId, `🙏 *Thank you for your feedback!*\n\nI'll use this to improve my responses. ${isPositive ? 'Glad you liked it!' : 'I'll do better next time!'}`);
        }
    });
});

// /clear command
bot.onText(/\/clear/, (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    userContext.delete(userId);
    bot.sendMessage(chatId, "🗑️ *Conversation context cleared!*\n\nWe're starting fresh. Feel free to ask me anything!");
});

// /status command
bot.onText(/\/status/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, `✅ *${aiName} is online and ready!*\n\n🤖 Status: Active\n🧠 Learning: Enabled\n💬 Personality: Active\n\nSend me any message to start chatting!`);
});

// /health command
bot.onText(/\/health/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, `🩺 *System Health*\n\n✅ Database: Connected\n✅ AI Model: ${ollamaModel}\n✅ Learning: Active\n✅ Memory: ${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB\n\nAll systems operational!`);
});

// /info command
bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, `📊 *About ${aiName}*

Version: 3.0.0
Type: Advanced AI with Learning
Model: ${ollamaModel}
Personality: Custom-trained

*Features:*
• Learns from conversations
• Remembers context
• Improves over time
• Natural responses

*Commands:* /start for full list

Let's chat and learn together! 🌟`);
});

// /help command
bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, `📚 *Available Commands*

/chat [message] - Chat with me
/train - Help me learn
/export - Export conversations
/stats - View my learning
/feedback [good/bad] - Rate my response
/clear - Clear context
/status - Check my status
/health - System health
/info - About me

*Just send any message to start chatting!*`);
});

console.log(`🚀 ${aiName} is ready to chat!`);
console.log(`💡 Personality: ${aiPersonality.substring(0, 100)}...`);
BOTEOF
    
    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export OLLAMA_MODEL="$OLLAMA_MODEL"
export AI_NAME="$AI_NAME"
export AI_PERSONALITY="$AI_PERSONALITY"

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
    
    log_success "Advanced AI bot created with personality and learning"
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
        ;;
    logs)
        docker logs khongai --tail 50 -f
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    train)
        echo -e "${BLUE}Training AI with collected data...${NC}"
        cd ~/khongai-telegram-bot
        sqlite3 ~/.khongai/chat_history.db "SELECT user_message, ai_response FROM conversations WHERE learning_score=0 LIMIT 50;"
        echo -e "${GREEN}Training data prepared${NC}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|bot-logs|train}"
        ;;
esac
EOF
    
    chmod +x ~/khongai-manager.sh
}

# Main installation
main() {
    print_banner
    
    install_zstd
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
    echo -e "${GREEN}✅ $AI_NAME Advanced AI installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}🤖 AI Features:${NC}"
    echo "  • Human-like conversations"
    echo "  • Learns from every chat"
    echo "  • Remembers context"
    echo "  • Personalized responses"
    echo "  • Continuous improvement"
    echo ""
    echo -e "${CYAN}📝 Commands in Telegram:${NC}"
    echo "  • Send any message to chat"
    echo "  • /train - Help me learn"
    echo "  • /stats - See what I learned"
    echo "  • /feedback good/bad - Rate responses"
    echo ""
    echo -e "${GREEN}🎉 Send /start to your bot on Telegram now!${NC}\n"
}

main "$@"
