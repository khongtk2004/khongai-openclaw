#!/bin/bash
# ClawBot Installer - Fixed File Processing

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
    echo "║     ██████╗██╗      █████╗ ██╗    ██╗██████╗  ██████╗ ████████╗              ║"
    echo "║    ██╔════╝██║     ██╔══██╗██║    ██║██╔══██╗██╔═══██╗╚══██╔══╝              ║"
    echo "║    ██║     ██║     ███████║██║ █╗ ██║██████╔╝██║   ██║   ██║                 ║"
    echo "║    ██║     ██║     ██╔══██║██║███╗██║██╔══██╗██║   ██║   ██║                 ║"
    echo "║    ╚██████╗███████╗██║  ██║╚███╔███╔╝██████╔╝╚██████╔╝   ██║                 ║"
    echo "║     ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═════╝  ╚═════╝    ╚═╝                 ║"
    echo "║                                                                              ║"
    echo "║              ClawBot - Fixed PDF & File Learning                             ║"
    echo "║                      Learn from ANY document!                                ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step() { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }

# Install system dependencies
install_deps() {
    log_step "Installing system dependencies..."
    
    if ! command -v zstd &> /dev/null; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y zstd
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y zstd
        fi
    fi
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        log_info "Installing Node.js..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    fi
    
    log_success "Dependencies installed"
}

# Get API Keys
get_api_keys() {
    echo -e "\n${BOLD}${CYAN}🔑 API Configuration${NC}\n"
    
    echo -e "${YELLOW}Enter OpenAI ChatGPT API Key (optional, for better responses):${NC}"
    echo -e "${BLUE}(Get from https://platform.openai.com/api-keys)${NC}"
    read -p "➤ " OPENAI_API_KEY
    
    if [[ -n "$OPENAI_API_KEY" ]]; then
        log_success "ChatGPT API enabled"
    else
        log_info "Using Ollama only"
    fi

    # Ollama Model
    echo -e "\n${BOLD}${CYAN}🦙 Ollama Model Selection${NC}\n"
    echo "  1) llama2 (Recommended)"
    echo "  2) mistral"
    echo "  3) neural-chat"
    read -p "Select [1-3, default: 1]: " model_choice

    case $model_choice in
        2) OLLAMA_MODEL="mistral" ;;
        3) OLLAMA_MODEL="neural-chat" ;;
        *) OLLAMA_MODEL="llama2" ;;
    esac

    log_success "Ollama model: $OLLAMA_MODEL"

    # Bot name
    echo -e "\n${BOLD}${CYAN}🦞 Bot Name${NC}\n"
    read -p "Enter bot name [default: ClawBot]: " AI_NAME
    AI_NAME=${AI_NAME:-ClawBot}

    log_success "Bot configured: $AI_NAME"
}

# Get admin usernames
get_admin_usernames() {
    echo -e "\n${BOLD}${CYAN}👥 Admin Users${NC}\n"
    echo -e "${YELLOW}Enter Telegram usernames (without @, separated by commas):${NC}"
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
}

# Create directories
create_directories() {
    log_step "Creating directories..."
    mkdir -p ~/.clawbot/{models,data,chat_history,training_data,logs,uploads,knowledge}
    mkdir -p ~/clawbot
    mkdir -p ~/clawbot-telegram
    log_success "Directories created"
}

# Install Ollama
install_ollama() {
    log_step "Installing Ollama..."
    
    if ! command -v ollama &> /dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    sudo systemctl start ollama 2>/dev/null || ollama serve > /dev/null 2>&1 &
    sleep 5
    sudo systemctl enable ollama 2>/dev/null || true
    
    log_info "Pulling $OLLAMA_MODEL model (this may take several minutes)..."
    ollama pull $OLLAMA_MODEL
    
    log_success "Ollama ready"
}

# Create ClawBot with fixed file processing
create_clawbot() {
    log_step "Creating ClawBot with fixed file processing..."

    cd ~/clawbot-telegram

    cat > package.json << 'EOF'
{
  "name": "clawbot",
  "version": "3.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6",
    "pdf-parse": "^1.1.1",
    "mammoth": "^1.4.2"
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
const fs = require('fs');
const pdfParse = require('pdf-parse');

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const ollamaModel = process.env.OLLAMA_MODEL || 'llama2';
const aiName = process.env.AI_NAME || 'ClawBot';
const ADMIN_USERNAMES = JSON.parse(process.env.ADMIN_USERNAMES || '["khongtk2004"]');

const bot = new TelegramBot(token, { polling: true });
const UPLOAD_DIR = path.join(process.env.HOME, '.clawbot', 'uploads');

// Ensure upload directory exists
if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// Initialize database
const db = new sqlite3.Database(path.join(process.env.HOME, '.clawbot', 'chat_history.db'));

// Create tables
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
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS knowledge_base (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT,
        content TEXT,
        source TEXT,
        learned_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
});

// Store conversation history
const userHistory = new Map();

console.log(`🦞 ${aiName} (ClawBot) Started!`);
console.log(`Ollama Model: ${ollamaModel}`);
console.log(`ChatGPT: ${openaiApiKey ? 'Enabled ✅' : 'Disabled'}`);

// Extract text from PDF
async function extractPDFText(filePath) {
    try {
        const dataBuffer = fs.readFileSync(filePath);
        const data = await pdfParse(dataBuffer);
        return data.text;
    } catch (error) {
        console.error('PDF extraction error:', error);
        return null;
    }
}

// Extract text from TXT
async function extractTXTText(filePath) {
    try {
        return fs.readFileSync(filePath, 'utf8');
    } catch (error) {
        console.error('TXT extraction error:', error);
        return null;
    }
}

// Process file and extract text
async function processFile(filePath, fileName) {
    const ext = path.extname(fileName).toLowerCase();
    
    if (ext === '.pdf') {
        return await extractPDFText(filePath);
    } else if (ext === '.txt') {
        return await extractTXTText(filePath);
    } else {
        return null;
    }
}

// Learn from text
async function learnFromText(text, source, userId) {
    return new Promise((resolve) => {
        // Split text into chunks
        const chunks = text.match(/[^.!?]+[.!?]+/g) || [text];
        let learned = 0;
        
        for (const chunk of chunks.slice(0, 50)) {
            if (chunk.trim().length > 30) {
                const topic = chunk.substring(0, 100).trim();
                db.run('INSERT INTO knowledge_base (topic, content, source) VALUES (?, ?, ?)',
                    [topic, chunk.trim(), source], (err) => {
                    if (!err) learned++;
                });
            }
        }
        
        resolve(learned);
    });
}

// Search knowledge base
async function searchKnowledge(query) {
    return new Promise((resolve) => {
        const results = [];
        db.all('SELECT topic, content FROM knowledge_base', (err, rows) => {
            if (!rows) return resolve(null);
            
            const queryLower = query.toLowerCase();
            for (const row of rows) {
                if (row.topic.toLowerCase().includes(queryLower) || 
                    row.content.toLowerCase().includes(queryLower)) {
                    results.push(row.content);
                    if (results.length >= 3) break;
                }
            }
            
            resolve(results.length > 0 ? results.join('\n\n') : null);
        });
    });
}

// Call ChatGPT API
async function callChatGPT(userMessage, history) {
    if (!openaiApiKey) return null;
    
    try {
        const messages = [
            { role: 'system', content: `You are ${aiName}, a helpful AI assistant. Be conversational and engaging.` },
            ...history.slice(-10),
            { role: 'user', content: userMessage }
        ];
        
        const response = await axios.post('https://api.openai.com/v1/chat/completions', {
            model: 'gpt-3.5-turbo',
            messages: messages,
            temperature: 0.8,
            max_tokens: 500
        }, {
            headers: { 'Authorization': `Bearer ${openaiApiKey}` },
            timeout: 20000
        });
        
        return response.data.choices[0].message.content;
    } catch (error) {
        return null;
    }
}

// Call Ollama
async function callOllama(userMessage, history, context = '') {
    try {
        const historyText = history.slice(-5).map(h => `${h.role}: ${h.content}`).join('\n');
        const prompt = `You are ${aiName}, a helpful AI assistant.

${context ? `Here is relevant information from my knowledge base:\n${context}\n\n` : ''}
Previous conversation:
${historyText}

User: ${userMessage}

${aiName}:`;

        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: { temperature: 0.8, num_predict: 500 }
        }, { timeout: 30000 });
        
        return response.data.response.replace(`${aiName}:`, '').trim();
    } catch (error) {
        console.error('Ollama error:', error.message);
        return null;
    }
}

// Get AI response
async function getAIResponse(userMessage, history) {
    // Search knowledge base first
    const knowledge = await searchKnowledge(userMessage);
    
    // Try ChatGPT if available
    if (openaiApiKey) {
        const chatGPTResponse = await callChatGPT(userMessage, history);
        if (chatGPTResponse) return { response: chatGPTResponse, model: 'chatgpt' };
    }
    
    // Use Ollama
    const ollamaResponse = await callOllama(userMessage, history, knowledge);
    if (ollamaResponse) return { response: ollamaResponse, model: 'ollama' };
    
    // Fallback
    const fallbacks = [
        `🦞 *snap snap* I'm ${aiName}! Ask me anything or send me files to learn!`,
        `Hey there! ${aiName} here. What can I help you with today?`,
        `*claw click* ${aiName} ready! Send me documents and I'll learn from them!`
    ];
    return { response: fallbacks[Math.floor(Math.random() * fallbacks.length)], model: 'fallback' };
}

// User management
async function isApproved(userId) {
    return new Promise((resolve) => {
        db.get('SELECT is_approved FROM users WHERE user_id = ?', [userId], (err, row) => {
            resolve(row && row.is_approved === 1);
        });
    });
}

async function isAdmin(userId, username) {
    return new Promise((resolve) => {
        db.get('SELECT is_admin FROM users WHERE user_id = ?', [userId], (err, row) => {
            if (row && row.is_admin) {
                resolve(true);
            } else if (ADMIN_USERNAMES.includes(username)) {
                db.run('INSERT OR REPLACE INTO users (user_id, username, is_approved, is_admin) VALUES (?, ?, 1, 1)', [userId, username]);
                resolve(true);
            } else {
                resolve(false);
            }
        });
    });
}

async function registerUser(userId, username, firstName) {
    return new Promise((resolve) => {
        db.run('INSERT OR IGNORE INTO users (user_id, username, first_name) VALUES (?, ?, ?)', [userId, username, firstName], () => resolve());
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
        const welcomeMessage = `🦞 *Welcome to ${aiName}!* 🦞

*claw click* I can learn from PDF and TXT files!

━━━━━━━━━━━━━━━━━━━━━

✨ *What I can do:*
• 📝 Chat naturally
• 📚 Learn from PDF documents
• 📖 Read and remember TXT files
• 🧠 Search my knowledge base

📋 *Commands:*
• Send any message to chat
• Send PDF/TXT files - I'll learn
• /knowledge <query> - Search my memory
• /stats - View my stats
• /clear - Reset chat

━━━━━━━━━━━━━━━━━━━━━

*Send me a PDF or TXT to get started!* 🚀`;

        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `⏳ *Hey ${firstName}!*

You need admin approval to chat with me.`);

        for (const adminUsername of ADMIN_USERNAMES) {
            bot.sendMessage(chatId, `👥 *New User Request*

**User:** @${username || firstName}
**ID:** ${userId}

Use: /approve @${username || userId}`);
        }
    }
});

// Handle document uploads (PDF, TXT)
bot.on('document', async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const fileId = msg.document.file_id;
    const fileName = msg.document.file_name;
    const fileExt = path.extname(fileName).toLowerCase();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending* - Wait for admin approval!");
        return;
    }
    
    if (!['.pdf', '.txt'].includes(fileExt)) {
        bot.sendMessage(chatId, `❌ Unsupported file type: ${fileExt}\n\nPlease send PDF or TXT files only.`);
        return;
    }
    
    bot.sendMessage(chatId, `📥 *Processing ${fileName}...*\n\nI'm reading and learning from this file! 🧠`);
    
    try {
        // Download file
        const file = await bot.getFile(fileId);
        const filePath = path.join(UPLOAD_DIR, fileName);
        const fileUrl = `https://api.telegram.org/file/bot${token}/${file.file_path}`;
        
        const response = await axios({ method: 'get', url: fileUrl, responseType: 'stream' });
        const writer = fs.createWriteStream(filePath);
        response.data.pipe(writer);
        
        await new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });
        
        // Extract text from file
        const extractedText = await processFile(filePath, fileName);
        
        if (extractedText && extractedText.length > 100) {
            const learnedCount = await learnFromText(extractedText, fileName, userId);
            
            const preview = extractedText.substring(0, 300);
            bot.sendMessage(chatId, `✅ *Learning Complete!* 📚

**File:** ${fileName}
**Pages/Lines:** ${Math.floor(extractedText.length / 500)} sections
**Learned:** ${learnedCount} new facts

**Preview:**
${preview}${extractedText.length > 300 ? '...' : ''}

*I've added this knowledge to my brain!* 🧠

Try asking: /knowledge about this`);
        } else {
            bot.sendMessage(chatId, `⚠️ Couldn't extract text from this file.

**Possible issues:**
• PDF might be scanned images (no selectable text)
• File might be corrupted
• File is empty

Try a different file with selectable text.`);
        }
        
        // Clean up
        fs.unlinkSync(filePath);
        
    } catch (error) {
        console.error('File processing error:', error);
        bot.sendMessage(chatId, `❌ Error processing file. Please try again with a different file.`);
    }
});

// /knowledge command - Search knowledge base
bot.onText(/\/knowledge (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const query = match[1];
    const userId = msg.from.id.toString();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }
    
    bot.sendMessage(chatId, `🔍 *Searching knowledge base for:* "${query}"`);
    
    const knowledge = await searchKnowledge(query);
    
    if (knowledge) {
        bot.sendMessage(chatId, `📚 *Found in my memory!*

${knowledge.substring(0, 1500)}

*I learned this from uploaded files!* 🧠`);
    } else {
        bot.sendMessage(chatId, `📚 *No knowledge found for:* "${query}"

Teach me by uploading PDF or TXT files related to this topic!`);
    }
});

// /stats command
bot.onText(/\/stats/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();

    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }

    db.get('SELECT COUNT(*) as total FROM conversations', (err, total) => {
        db.get('SELECT COUNT(*) as knowledge FROM knowledge_base', (err2, knowledge) => {
            const statsMessage = `📊 *${aiName} Stats*

**Conversations:** ${total.total || 0}
**Knowledge Items:** ${knowledge.knowledge || 0}
**AI Model:** ${openaiApiKey ? 'ChatGPT + Ollama' : 'Ollama'}

*Send me PDFs to learn!* 📚🦞`;

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
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }

    userHistory.delete(userId);
    bot.sendMessage(chatId, `🗑️ *Chat cleared!*\n\nStarting fresh! 🦞`);
});

// /approve command
bot.onText(/\/approve (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const username = msg.from.username || '';
    const target = match[1].replace('@', '');

    if (!(await isAdmin(userId, username))) {
        bot.sendMessage(chatId, "❌ *Access Denied*");
        return;
    }

    db.get('SELECT user_id, username, first_name FROM users WHERE username = ? OR user_id = ?', [target, target], async (err, user) => {
        if (user) {
            db.run('UPDATE users SET is_approved = 1 WHERE user_id = ?', [user.user_id]);
            bot.sendMessage(chatId, `✅ *User Approved*\n\n@${user.username || user.first_name} can now use ClawBot!`);
            bot.sendMessage(user.user_id, `🎉 *Access Granted!*\n\nYou can now chat with ${aiName}! Send me PDFs to learn!`);
        } else {
            bot.sendMessage(chatId, `❌ *User Not Found*`);
        }
    });
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
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nWait for admin approval!");
        return;
    }

    bot.sendChatAction(chatId, 'typing');

    let history = userHistory.get(userId) || [];
    const result = await getAIResponse(text, history);
    
    history.push({ role: 'user', content: text });
    history.push({ role: 'assistant', content: result.response });
    if (history.length > 20) history = history.slice(-20);
    userHistory.set(userId, history);

    db.run('INSERT INTO conversations (user_id, user_message, ai_response, model_used) VALUES (?, ?, ?, ?)',
        [userId, text, result.response, result.model]);

    bot.sendMessage(chatId, result.response);
});

console.log(`🦞 ${aiName} is ready! Send me PDF files to learn!`);
BOTEOF

    # Create start script
    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export OLLAMA_MODEL="$OLLAMA_MODEL"
export AI_NAME="$AI_NAME"
export ADMIN_USERNAMES='$ADMIN_LIST_JSON'

cd "$HOME/clawbot-telegram"
pkill -f "node bot.js" 2>/dev/null
nohup node bot.js > bot.log 2>&1 &
echo \$! > bot.pid
echo "✅ ${AI_NAME} started!"
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

    log_success "ClawBot created with fixed PDF processing!"
}

# Create management script
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
        echo -e "${GREEN}✓ ClawBot started${NC}"
        ;;
    stop)
        echo -e "${BLUE}Stopping ClawBot...${NC}"
        cd ~/clawbot-telegram && ./stop.sh
        echo -e "${GREEN}✓ ClawBot stopped${NC}"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo -e "${BLUE}════════════════════════════════${NC}"
        echo -e "ClawBot Status"
        echo -e "${BLUE}════════════════════════════════${NC}"
        echo -e "\n🤖 Bot: $(pgrep -f 'node bot.js' > /dev/null && echo 'Running ✅' || echo 'Stopped ❌')"
        echo -e "\n🦙 Ollama: $(curl -s http://localhost:11434/api/tags > /dev/null && echo 'Running ✅' || echo 'Stopped ❌')"
        echo -e "\n📚 Knowledge: $(sqlite3 ~/.clawbot/chat_history.db 'SELECT COUNT(*) FROM knowledge_base;' 2>/dev/null || echo '0') items"
        ;;
    logs)
        tail -f ~/clawbot-telegram/bot.log
        ;;
    knowledge)
        echo -e "${BLUE}Knowledge Base:${NC}"
        sqlite3 ~/.clawbot/chat_history.db "SELECT topic FROM knowledge_base LIMIT 20;" 2>/dev/null
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|knowledge}"
        exit 1
        ;;
esac
EOF

    chmod +x ~/clawbot-manager.sh
    log_success "Management script created"
}

# Main installation
main() {
    print_banner

    install_deps
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

    echo "$TELEGRAM_BOT_TOKEN" > ~/.clawbot/bot-token.txt

    # Save config
    ADMIN_LIST_JSON="["
    for i in "${!ADMIN_USERNAMES[@]}"; do
        [ $i -gt 0 ] && ADMIN_LIST_JSON+=","
        ADMIN_LIST_JSON+="\"${ADMIN_USERNAMES[$i]}\""
    done
    ADMIN_LIST_JSON+="]"

    cat > ~/.clawbot/config.json << EOF
{
    "bot_name": "$AI_NAME",
    "ollama_model": "$OLLAMA_MODEL",
    "chatgpt_enabled": ${OPENAI_API_KEY:+true},
    "admins": ${ADMIN_LIST_JSON},
    "install_date": "$(date)"
}
EOF

    # Install Ollama
    install_ollama
    
    # Create and start ClawBot
    create_clawbot
    create_manager

    ~/clawbot-manager.sh start

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ ${AI_NAME} (ClawBot) installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

    echo -e "${CYAN}🦞 ClawBot Features:${NC}"
    echo "  • 📝 Chat naturally"
    echo "  • 📚 Learn from PDF files"
    echo "  • 📖 Read TXT documents"
    echo "  • 🧠 Searchable knowledge base"
    echo ""
    echo -e "${CYAN}📁 How to use:${NC}"
    echo "  1. Send a PDF file - I'll read and learn from it"
    echo "  2. Ask questions - I'll use what I learned"
    echo "  3. Use /knowledge <query> - Search my memory"
    echo ""
    echo -e "${CYAN}📋 Commands:${NC}"
    echo "  • Send any message - Chat with me"
    echo "  • /knowledge <query> - Search my knowledge"
    echo "  • /stats - View statistics"
    echo "  • /clear - Clear conversation"
    echo ""
    echo -e "${CYAN}👑 Admin Commands:${NC}"
    echo "  • /approve @username - Approve user"
    echo ""
    echo -e "${CYAN}🛠️ Management:${NC}"
    echo "  • ~/clawbot-manager.sh status  - Check status"
    echo "  • ~/clawbot-manager.sh logs     - View logs"
    echo "  • ~/clawbot-manager.sh knowledge - View knowledge base"
    echo ""
    echo -e "${GREEN}🎉 Send a PDF file to your bot to start teaching it!${NC}\n"
    
    echo -e "${YELLOW}⚠️ Important: PDF must have selectable text (not scanned images).${NC}"
    echo -e "${YELLOW}   For scanned PDFs, convert to text first or use TXT files.${NC}\n"
}

main "$@"
