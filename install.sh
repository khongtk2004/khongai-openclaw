#!/bin/bash
# ClawBot Installer - Multi-Modal AI with Training from Files

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
    echo "║              ClawBot - Multi-Modal AI Assistant                              ║"
    echo "║         Learn from Text, PDF, Images, and Documents                          ║"
    echo "║              Ollama + ChatGPT + OpenClaw = ClawBot                           ║"
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
    
    # Install zstd
    if ! command -v zstd &> /dev/null; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y zstd poppler-utils tesseract tesseract-langpack-eng
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y zstd poppler-utils tesseract-ocr
        fi
        log_success "Dependencies installed"
    else
        log_success "Dependencies already installed"
    fi
    
    # Install Python for PDF/Image processing
    if ! command -v python3 &> /dev/null; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y python3 python3-pip
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install -y python3 python3-pip
        fi
    fi
    
    # Install Python libraries for file processing
    pip3 install --user PyPDF2 pillow pytesseract pdf2image 2>/dev/null || true
}

# Get API Keys
get_api_keys() {
    echo -e "\n${BOLD}${CYAN}🔑 API Configuration${NC}\n"
    
    # ChatGPT API Key (optional)
    echo -e "${YELLOW}Enter OpenAI ChatGPT API Key (optional, for better responses):${NC}"
    echo -e "${BLUE}(Get from https://platform.openai.com/api-keys)${NC}"
    echo -e "${BLUE}(Leave empty to use only Ollama)${NC}"
    read -p "➤ " OPENAI_API_KEY
    
    if [[ -n "$OPENAI_API_KEY" ]]; then
        log_success "ChatGPT API enabled"
    else
        log_info "Using Ollama only (free, local AI)"
    fi

    # Ollama Model Selection
    echo -e "\n${BOLD}${CYAN}🦙 Ollama Model Selection${NC}\n"
    echo -e "${YELLOW}Select Ollama model:${NC}"
    echo "  1) llama2 (7B, balanced - Recommended)"
    echo "  2) mistral (7B, very capable)"
    echo "  3) neural-chat (7B, best for conversation)"
    echo "  4) llama2-uncensored (7B, creative)"
    read -p "Select [1-4, default: 1]: " model_choice

    case $model_choice in
        2) OLLAMA_MODEL="mistral" ;;
        3) OLLAMA_MODEL="neural-chat" ;;
        4) OLLAMA_MODEL="llama2-uncensored" ;;
        *) OLLAMA_MODEL="llama2" ;;
    esac

    log_success "Ollama model: $OLLAMA_MODEL"

    # ClawBot Personality
    echo -e "\n${BOLD}${CYAN}🦞 ClawBot Personality${NC}\n"
    read -p "Enter bot name [default: ClawBot]: " AI_NAME
    AI_NAME=${AI_NAME:-ClawBot}
    
    echo -e "${YELLOW}Select personality:${NC}"
    echo "  1) Friendly & Helpful"
    echo "  2) Sassy & Witty (ClawBot Style)"
    echo "  3) Professional & Formal"
    echo "  4) Creative & Imaginative"
    read -p "Select [1-4, default: 2]: " personality_choice

    case $personality_choice in
        1)
            AI_PERSONALITY="You are $AI_NAME, a friendly, helpful AI assistant. You love helping people learn new things."
            ;;
        3)
            AI_PERSONALITY="You are $AI_NAME, a professional, formal AI assistant. You provide accurate, well-structured information."
            ;;
        4)
            AI_PERSONALITY="You are $AI_NAME, a creative, imaginative AI. You think outside the box and provide unique perspectives."
            ;;
        *)
            AI_PERSONALITY="You are $AI_NAME, a sassy, witty AI assistant with attitude. You're smart, slightly sarcastic, but ultimately helpful. You love learning from documents and files!"
            ;;
    esac

    log_success "ClawBot configured: $AI_NAME"
}

# Install Ollama
install_ollama() {
    log_step "Installing Ollama..."
    
    if ! command -v ollama &> /dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    sudo systemctl start ollama 2>/dev/null || ollama serve > /dev/null 2>&1 &
    sleep 3
    sudo systemctl enable ollama 2>/dev/null || true
    
    log_info "Pulling $OLLAMA_MODEL model..."
    ollama pull $OLLAMA_MODEL
    
    log_success "Ollama ready"
}

# Get admin usernames
get_admin_usernames() {
    echo -e "\n${BOLD}${CYAN}👥 Admin Users${NC}\n"
    echo -e "${YELLOW}Enter Telegram usernames (without @):${NC}"
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
    mkdir -p ~/.clawbot/{models,data,chat_history,training_data,logs,uploads,learned}
    mkdir -p ~/.clawbot/uploads/{text,pdf,images,txt}
    mkdir -p ~/clawbot
    mkdir -p ~/clawbot-telegram
    log_success "Directories created"
}

# Create ClawBot with file learning
create_clawbot() {
    log_step "Creating ClawBot with file learning..."

    cd ~/clawbot-telegram

    cat > package.json << 'EOF'
{
  "name": "clawbot",
  "version": "2.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6",
    "multer": "^1.4.5-lts.1",
    "pdf-parse": "^1.1.1",
    "tesseract.js": "^5.0.0"
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

    # Create Python file processor
    cat > ~/.clawbot/process_file.py << 'PYEOF'
#!/usr/bin/env python3
import sys
import json
import PyPDF2
import pytesseract
from PIL import Image
import os

def extract_text_from_pdf(pdf_path):
    text = ""
    with open(pdf_path, 'rb') as file:
        reader = PyPDF2.PdfReader(file)
        for page in reader.pages:
            text += page.extract_text()
    return text

def extract_text_from_image(image_path):
    try:
        image = Image.open(image_path)
        text = pytesseract.image_to_string(image)
        return text
    except Exception as e:
        return f"Error extracting text: {e}"

def extract_text_from_txt(txt_path):
    with open(txt_path, 'r', encoding='utf-8') as file:
        return file.read()

if __name__ == "__main__":
    file_path = sys.argv[1]
    file_ext = os.path.splitext(file_path)[1].lower()
    
    if file_ext == '.pdf':
        text = extract_text_from_pdf(file_path)
    elif file_ext in ['.jpg', '.jpeg', '.png', '.bmp']:
        text = extract_text_from_image(file_path)
    elif file_ext == '.txt':
        text = extract_text_from_txt(file_path)
    else:
        text = "Unsupported file type"
    
    print(json.dumps({"text": text[:5000]}))
PYEOF

    chmod +x ~/.clawbot/process_file.py

    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const { promisify } = require('util');
const execPromise = promisify(exec);

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const ollamaModel = process.env.OLLAMA_MODEL || 'llama2';
const aiName = process.env.AI_NAME || 'ClawBot';
const aiPersonality = process.env.AI_PERSONALITY;
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

    db.run(`CREATE TABLE IF NOT EXISTS training_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        source TEXT,
        trained BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS learned_knowledge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT UNIQUE,
        knowledge TEXT,
        confidence INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
});

// Store conversation history
const userHistory = new Map();
const trainingQueue = [];

console.log(`🦞 ${aiName} (ClawBot) Started!`);
console.log(`Ollama Model: ${ollamaModel}`);
console.log(`ChatGPT: ${openaiApiKey ? 'Enabled ✅' : 'Disabled'}`);

// Extract text from file
async function extractTextFromFile(filePath, fileType) {
    try {
        const { stdout } = await execPromise(`python3 ~/.clawbot/process_file.py "${filePath}"`);
        const result = JSON.parse(stdout);
        return result.text;
    } catch (error) {
        console.error('File extraction error:', error);
        return null;
    }
}

// Call ChatGPT API
async function callChatGPT(userMessage, history) {
    if (!openaiApiKey) return null;
    
    try {
        const messages = [
            { role: 'system', content: aiPersonality },
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
        const prompt = `${aiPersonality}

${context ? `Relevant information from training:\n${context}\n` : ''}

Previous conversation:
${historyText}

User: ${userMessage}

${aiName}:`;

        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: { temperature: 0.8, num_predict: 600 }
        }, { timeout: 30000 });
        
        return response.data.response.replace(`${aiName}:`, '').trim();
    } catch (error) {
        return null;
    }
}

// Search learned knowledge
async function searchKnowledge(query) {
    return new Promise((resolve) => {
        db.all('SELECT topic, knowledge FROM learned_knowledge ORDER BY confidence DESC', (err, rows) => {
            if (!rows) return resolve(null);
            
            const relevant = [];
            const queryLower = query.toLowerCase();
            
            for (const row of rows) {
                if (queryLower.includes(row.topic.toLowerCase()) || 
                    row.topic.toLowerCase().includes(queryLower)) {
                    relevant.push(row.knowledge);
                }
            }
            
            resolve(relevant.length > 0 ? relevant.join('\n\n') : null);
        });
    });
}

// Train AI with content
async function trainAI(content, source) {
    return new Promise((resolve) => {
        db.run('INSERT INTO training_data (content, source) VALUES (?, ?)', [content, source], (err) => {
            if (!err) {
                // Process and learn from content
                const sentences = content.match(/[^.!?]+[.!?]+/g) || [content];
                for (const sentence of sentences.slice(0, 20)) {
                    if (sentence.length > 20) {
                        const topic = sentence.substring(0, 50).toLowerCase();
                        db.run('INSERT OR REPLACE INTO learned_knowledge (topic, knowledge, confidence) VALUES (?, ?, 1)',
                            [topic, sentence.trim()]);
                    }
                }
            }
            resolve();
        });
    });
}

// Get AI response
async function getAIResponse(userMessage, history) {
    // Search learned knowledge first
    const knowledge = await searchKnowledge(userMessage);
    
    // Try ChatGPT if available
    if (openaiApiKey) {
        const chatGPTResponse = await callChatGPT(userMessage, history);
        if (chatGPTResponse) return { response: chatGPTResponse, model: 'chatgpt' };
    }
    
    // Use Ollama with knowledge context
    const ollamaResponse = await callOllama(userMessage, history, knowledge);
    if (ollamaResponse) return { response: ollamaResponse, model: 'ollama' };
    
    return { response: `🦞 *snap snap* I'm ${aiName}! Ask me anything or upload files for me to learn!`, model: 'fallback' };
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

*claw click* Hey ${firstName}! I'm a multi-modal AI that can learn from files!

━━━━━━━━━━━━━━━━━━━━━

✨ *What I can do:*
• 📝 Chat naturally like ChatGPT
• 📚 Learn from PDF, TXT, and Images
• 🧠 Remember what you teach me
• 🔍 Search my knowledge base
• 💬 Have sassy, engaging conversations

📋 *Commands:*
• Send any message to chat
• /train - Train me on uploaded files
• /knowledge - Search my knowledge
• /stats - View my stats
• /clear - Reset our chat

📁 *File Upload:*
• Send PDF files - I'll read and learn
• Send TXT files - I'll remember content
• Send Images - I'll extract text

━━━━━━━━━━━━━━━━━━━━━

*Let's learn together!* 🚀`;

        bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `⏳ *Hey ${firstName}!*

You need approval to chat with me. An admin has been notified! 🦞`);

        for (const adminUsername of ADMIN_USERNAMES) {
            bot.sendMessage(chatId, `👥 *New User Request*

**User:** @${username || firstName}
**ID:** ${userId}

Use: /approve @${username || userId} to approve`);
        }
    }
});

// Handle file uploads (PDF, Images, TXT)
bot.on('document', async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const fileId = msg.document.file_id;
    const fileName = msg.document.file_name;
    const fileExt = fileName.split('.').pop().toLowerCase();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*\n\nWait for admin approval!");
        return;
    }
    
    if (!['pdf', 'txt', 'jpg', 'jpeg', 'png'].includes(fileExt)) {
        bot.sendMessage(chatId, `❌ Unsupported file type: ${fileExt}\n\nSend PDF, TXT, or Image files.`);
        return;
    }
    
    bot.sendMessage(chatId, `📥 *Processing ${fileName}...*\n\nI'm reading and learning from this file! 🧠`);
    
    try {
        // Download file
        const file = await bot.getFile(fileId);
        const filePath = path.join(UPLOAD_DIR, fileName);
        
        // Download file using axios
        const fileUrl = `https://api.telegram.org/file/bot${token}/${file.file_path}`;
        const response = await axios({ method: 'get', url: fileUrl, responseType: 'stream' });
        const writer = fs.createWriteStream(filePath);
        response.data.pipe(writer);
        
        await new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });
        
        // Extract text from file
        const extractedText = await extractTextFromFile(filePath, fileExt);
        
        if (extractedText && extractedText.length > 50) {
            await trainAI(extractedText, fileName);
            bot.sendMessage(chatId, `✅ *Learning Complete!* 📚

**File:** ${fileName}
**Content Length:** ${extractedText.length} characters
**Topics Learned:** ${Math.min(20, Math.floor(extractedText.length / 100))}+

I've learned from this file and will use this knowledge in our conversations! 🧠

*Try asking me about what you just taught me!*`);
        } else {
            bot.sendMessage(chatId, `⚠️ Couldn't extract much text from this file. Try a clearer document or image.`);
        }
        
        // Clean up
        fs.unlinkSync(filePath);
        
    } catch (error) {
        console.error('File processing error:', error);
        bot.sendMessage(chatId, `❌ Error processing file. Please try again.`);
    }
});

// Handle photos (images with OCR)
bot.on('photo', async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const photo = msg.photo[msg.photo.length - 1];
    const fileId = photo.file_id;
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }
    
    bot.sendMessage(chatId, `📸 *Processing image with OCR...*\n\nI'm extracting and learning from this image! 👁️`);
    
    try {
        const file = await bot.getFile(fileId);
        const filePath = path.join(UPLOAD_DIR, `image_${Date.now()}.jpg`);
        
        const fileUrl = `https://api.telegram.org/file/bot${token}/${file.file_path}`;
        const response = await axios({ method: 'get', url: fileUrl, responseType: 'stream' });
        const writer = fs.createWriteStream(filePath);
        response.data.pipe(writer);
        
        await new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });
        
        const extractedText = await extractTextFromFile(filePath, 'jpg');
        
        if (extractedText && extractedText.length > 20) {
            await trainAI(extractedText, 'image_ocr');
            bot.sendMessage(chatId, `✅ *Image Learning Complete!* 📸

**Extracted Text:** ${extractedText.substring(0, 200)}${extractedText.length > 200 ? '...' : ''}

I've learned from this image! 🧠`);
        } else {
            bot.sendMessage(chatId, `⚠️ Couldn't read text from this image. Try a clearer picture.`);
        }
        
        fs.unlinkSync(filePath);
        
    } catch (error) {
        console.error('Image processing error:', error);
        bot.sendMessage(chatId, `❌ Error processing image.`);
    }
});

// /train command - Train on all pending files
bot.onText(/\/train/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }
    
    db.all('SELECT content, source FROM training_data WHERE trained = 0 LIMIT 10', async (err, rows) => {
        if (!rows || rows.length === 0) {
            bot.sendMessage(chatId, `📚 *No new files to train on!*\n\nSend me PDF, TXT, or Images to learn from.`);
            return;
        }
        
        bot.sendMessage(chatId, `🧠 *Training on ${rows.length} items...*\n\nI'm learning and improving!`);
        
        for (const row of rows) {
            await trainAI(row.content, row.source);
            db.run('UPDATE training_data SET trained = 1 WHERE source = ?', [row.source]);
        }
        
        bot.sendMessage(chatId, `✅ *Training Complete!*

I've learned from ${rows.length} files and integrated the knowledge into my brain!

*My knowledge base is growing!* 🧠🦞`);
    });
});

// /knowledge command - Search learned knowledge
bot.onText(/\/knowledge (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const query = match[1];
    const userId = msg.from.id.toString();
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }
    
    const knowledge = await searchKnowledge(query);
    
    if (knowledge) {
        bot.sendMessage(chatId, `📚 *Knowledge Found!*

**Query:** ${query}

${knowledge.substring(0, 1500)}

*I learned this from training!* 🧠`);
    } else {
        bot.sendMessage(chatId, `📚 *No knowledge found for:* "${query}"

Teach me by uploading files or using /teach!`);
    }
});

// /teach command
bot.onText(/\/teach (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const teachingText = match[1];
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }
    
    const parts = teachingText.split('|');
    if (parts.length >= 2) {
        const topic = parts[0].trim();
        const knowledge = parts[1].trim();
        
        db.run('INSERT OR REPLACE INTO learned_knowledge (topic, knowledge, confidence) VALUES (?, ?, 5)', [topic.toLowerCase(), knowledge]);
        bot.sendMessage(chatId, `📚 *I Learned!*

**Topic:** ${topic}
**Knowledge:** ${knowledge.substring(0, 200)}${knowledge.length > 200 ? '...' : ''}

Thanks for teaching me! 🧠`);
    } else {
        bot.sendMessage(chatId, `📚 *How to teach me:*

Use: /teach topic | knowledge

**Example:**
/teach What is ClawBot? | ClawBot is an AI that learns from files and conversations!`);
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
            bot.sendMessage(user.user_id, `🎉 *Access Granted!*\n\nYou can now chat with ${aiName}! Send files for me to learn!`);
        } else {
            bot.sendMessage(chatId, `❌ *User Not Found*`);
        }
    });
});

// /stats command
bot.onText(/\/stats/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();

    if (!(await isApproved(userId))) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }

    db.get('SELECT COUNT(*) as total FROM conversations', (err, total) => {
        db.get('SELECT COUNT(*) as knowledge FROM learned_knowledge', (err2, knowledge) => {
            db.get('SELECT COUNT(*) as files FROM training_data', (err3, files) => {
                const statsMessage = `📊 *${aiName} Stats*

**Conversations:** ${total.total}
**Knowledge Items:** ${knowledge.knowledge}
**Files Learned:** ${files.files}
**AI Model:** ${openaiApiKey ? 'ChatGPT + Ollama' : 'Ollama'}

*Keep teaching me!* 🧠🦞`;

                bot.sendMessage(chatId, statsMessage, { parse_mode: 'Markdown' });
            });
        });
    });
});

// /clear command
bot.onText(/\/clear/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();

    if (!(await isApproved(userId))) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }

    userHistory.delete(userId);
    bot.sendMessage(chatId, `🗑️ *Chat cleared!*\n\nWe're starting fresh! What's on your mind? 🦞`);
});

console.log(`🦞 ${aiName} is ready! Send files for me to learn!`);
BOTEOF

    # Create start script
    cat > start.sh << EOF
#!/bin/bash
export TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export OLLAMA_MODEL="$OLLAMA_MODEL"
export AI_NAME="$AI_NAME"
export AI_PERSONALITY="$AI_PERSONALITY"
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

    log_success "ClawBot created with file learning!"
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
        echo -e "\n📚 Knowledge: $(sqlite3 ~/.clawbot/chat_history.db 'SELECT COUNT(*) FROM learned_knowledge;' 2>/dev/null) items"
        ;;
    logs)
        tail -f ~/clawbot-telegram/bot.log
        ;;
    test)
        echo -e "${BLUE}Testing Ollama...${NC}"
        curl -s http://localhost:11434/api/generate -d '{"model":"llama2","prompt":"Say OK","stream":false}' | head -c 100
        ;;
    knowledge)
        echo -e "${BLUE}Knowledge Base:${NC}"
        sqlite3 ~/.clawbot/chat_history.db "SELECT topic FROM learned_knowledge ORDER BY confidence DESC LIMIT 20;"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|test|knowledge}"
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
    echo "  • 📝 Chat naturally like ChatGPT"
    echo "  • 📚 Learn from PDF, TXT, and Images"
    echo "  • 🧠 Searchable knowledge base"
    echo "  • 🔄 Train on uploaded files"
    echo "  • 👥 User approval system"
    echo ""
    echo -e "${CYAN}📁 File Learning:${NC}"
    echo "  • Send PDF - I'll read and learn"
    echo "  • Send TXT - I'll remember content"
    echo "  • Send Images - OCR text extraction"
    echo ""
    echo -e "${CYAN}📋 Commands:${NC}"
    echo "  • Send any message - Chat with ClawBot"
    echo "  • /teach topic | text - Teach me directly"
    echo "  • /knowledge query - Search my knowledge"
    echo "  • /train - Train on uploaded files"
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
    echo -e "${GREEN}🎉 Send /start to your bot and upload files for me to learn!${NC}\n"
}

main "$@"
