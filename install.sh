#!/bin/bash
# ClawBot Installer - Fixed PDF Learning & Knowledge Retrieval

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
    echo "║                   ClawBot - PDF Learning System                              ║"
    echo "║               Reads PDFs, Learns, and Answers Questions                      ║"
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
        if command -v dnf &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
        elif command -v apt-get &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
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
    mkdir -p ~/.clawbot/{models,data,chat_history,training_data,logs,uploads,knowledge,processed_pdfs}
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

# Create ClawBot with proper PDF learning
create_clawbot() {
    log_step "Creating ClawBot with proper PDF learning..."

    cd ~/clawbot-telegram

    cat > package.json << 'EOF'
{
  "name": "clawbot",
  "version": "4.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6",
    "pdf-parse": "^1.1.1"
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
const PROCESSED_DIR = path.join(process.env.HOME, '.clawbot', 'processed_pdfs');

// Ensure directories exist
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(PROCESSED_DIR)) fs.mkdirSync(PROCESSED_DIR, { recursive: true });

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

    db.run(`CREATE TABLE IF NOT EXISTS pdf_knowledge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pdf_name TEXT,
        page_number INTEGER,
        content TEXT,
        keywords TEXT,
        processed_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS knowledge_search (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT,
        relevant_content TEXT,
        pdf_source TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);
});

// Store conversation history
const userHistory = new Map();
const processingQueue = new Map();

console.log(`🦞 ${aiName} (ClawBot) Started!`);
console.log(`Ollama Model: ${ollamaModel}`);
console.log(`ChatGPT: ${openaiApiKey ? 'Enabled ✅' : 'Disabled'}`);

// Extract text from PDF with page numbers
async function extractPDFTextWithPages(filePath) {
    try {
        const dataBuffer = fs.readFileSync(filePath);
        const data = await pdfParse(dataBuffer);
        return {
            text: data.text,
            pages: data.numpages,
            info: data.info
        };
    } catch (error) {
        console.error('PDF extraction error:', error);
        return null;
    }
}

// Extract keywords from text for searching
function extractSearchKeywords(text) {
    const words = text.toLowerCase().split(/\s+/);
    const commonWords = new Set(['the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'that', 'this', 'these', 'those', 'from', 'as', 'has', 'have', 'had', 'will', 'would', 'could', 'should', 'may', 'might', 'must']);
    const keywords = new Set();
    
    for (const word of words) {
        if (word.length > 3 && !commonWords.has(word)) {
            keywords.add(word);
        }
    }
    
    return Array.from(keywords).join(', ');
}

// Split text into meaningful chunks (paragraphs/sections)
function splitIntoChunks(text) {
    // Split by double newlines or periods followed by spaces
    const chunks = text.split(/\n\s*\n|\.\s+/);
    const validChunks = [];
    
    for (const chunk of chunks) {
        const trimmed = chunk.trim();
        if (trimmed.length > 100 && trimmed.length < 2000) {
            validChunks.push(trimmed);
        } else if (trimmed.length >= 2000) {
            // Further split large chunks
            const subChunks = trimmed.match(/.{1,1500}[.!?]\s+/g) || [trimmed.substring(0, 1500)];
            for (const sub of subChunks) {
                if (sub.trim().length > 100) {
                    validChunks.push(sub.trim());
                }
            }
        }
    }
    
    return validChunks;
}

// Save PDF knowledge to database
async function savePDFKnowledge(pdfName, pageNum, content, keywords) {
    return new Promise((resolve) => {
        db.run(
            'INSERT INTO pdf_knowledge (pdf_name, page_number, content, keywords) VALUES (?, ?, ?, ?)',
            [pdfName, pageNum, content.substring(0, 2000), keywords],
            (err) => {
                if (!err) {
                    // Also save individual keywords for faster searching
                    const keywordList = keywords.split(', ');
                    for (const keyword of keywordList.slice(0, 20)) {
                        if (keyword.length > 3) {
                            db.run(
                                'INSERT OR IGNORE INTO knowledge_search (keyword, relevant_content, pdf_source) VALUES (?, ?, ?)',
                                [keyword, content.substring(0, 1000), pdfName]
                            );
                        }
                    }
                }
                resolve();
            }
        );
    });
}

// Search for relevant content based on question
async function searchRelevantContent(question) {
    return new Promise((resolve) => {
        const questionLower = question.toLowerCase();
        const results = [];
        
        // First try keyword search
        db.all('SELECT keyword, relevant_content, pdf_source FROM knowledge_search', (err, rows) => {
            if (rows) {
                for (const row of rows) {
                    if (questionLower.includes(row.keyword) || row.keyword.includes(questionLower)) {
                        results.push({
                            content: row.relevant_content,
                            source: row.pdf_source,
                            relevance: 10
                        });
                    }
                }
            }
            
            // Then search full content
            db.all('SELECT pdf_name, content FROM pdf_knowledge', (err, contentRows) => {
                if (contentRows) {
                    for (const row of contentRows) {
                        const contentLower = row.content.toLowerCase();
                        if (contentLower.includes(questionLower)) {
                            // Calculate relevance based on keyword frequency
                            let relevance = 0;
                            const words = questionLower.split(/\s+/);
                            for (const word of words) {
                                if (word.length > 3 && contentLower.includes(word)) {
                                    relevance += 1;
                                }
                            }
                            results.push({
                                content: row.content,
                                source: row.pdf_name,
                                relevance: relevance
                            });
                        }
                    }
                }
                
                // Sort by relevance and return top 5
                results.sort((a, b) => b.relevance - a.relevance);
                const uniqueResults = [];
                const seenContent = new Set();
                
                for (const result of results) {
                    if (!seenContent.has(result.content.substring(0, 100))) {
                        seenContent.add(result.content.substring(0, 100));
                        uniqueResults.push(result);
                        if (uniqueResults.length >= 5) break;
                    }
                }
                
                resolve(uniqueResults);
            });
        });
    });
}

// Process and learn from PDF
async function processPDF(filePath, fileName, chatId, bot) {
    bot.sendMessage(chatId, `📖 *Reading PDF: ${fileName}* 📖\n\nThis may take a moment... I'm extracting all the knowledge! 🧠`);
    
    const pdfData = await extractPDFTextWithPages(filePath);
    
    if (!pdfData || !pdfData.text || pdfData.text.length < 100) {
        bot.sendMessage(chatId, `❌ *Couldn't read PDF properly*

**File:** ${fileName}
**Issue:** PDF might be scanned or have no selectable text

**Solution:** Try a PDF with selectable text or convert to TXT first.`);
        return false;
    }
    
    bot.sendMessage(chatId, `✅ *PDF Loaded Successfully!*

**Pages:** ${pdfData.pages}
**Characters:** ${pdfData.text.length.toLocaleString()}
**Processing:** Learning from content... 📚`);
    
    // Split into chunks and save to database
    const chunks = splitIntoChunks(pdfData.text);
    let savedCount = 0;
    
    for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];
        const keywords = extractSearchKeywords(chunk);
        await savePDFKnowledge(fileName, Math.floor(i / 5) + 1, chunk, keywords);
        savedCount++;
        
        // Send progress every 10 chunks
        if (i % 10 === 0 && i > 0) {
            bot.sendMessage(chatId, `🔄 *Learning progress:* ${Math.floor((i / chunks.length) * 100)}% (${savedCount} facts learned)`);
        }
    }
    
    // Also save the original PDF for reference
    const savedPath = path.join(PROCESSED_DIR, fileName);
    fs.copyFileSync(filePath, savedPath);
    
    bot.sendMessage(chatId, `🎉 *Learning Complete!* 🎉

**File:** ${fileName}
**Knowledge extracted:** ${savedCount} facts
**Pages processed:** ${pdfData.pages}

*I've learned everything from this PDF!* 🧠

Now you can ask me questions about:
${pdfData.text.substring(0, 500)}...

*Try asking:* "Tell me about [something from this PDF]"`);
    
    return true;
}

// Generate answer using Ollama with context
async function generateAnswer(question, relevantContent) {
    if (!relevantContent || relevantContent.length === 0) {
        return null;
    }
    
    try {
        // Build context from relevant content
        let context = "";
        for (let i = 0; i < Math.min(3, relevantContent.length); i++) {
            context += `\n[Source ${i+1}]: ${relevantContent[i].content}\n`;
        }
        
        const prompt = `You are ${aiName}, an AI assistant that has read and learned from PDF documents.

Based ONLY on the following information from the PDFs I've read, answer the user's question.

${context}

Question: ${question}

Answer the question accurately using ONLY the information above. If the information doesn't fully answer the question, say so, but provide what you can find. Be helpful and conversational.`;

        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: { temperature: 0.5, num_predict: 500 }
        }, { timeout: 30000 });
        
        return response.data.response.trim();
    } catch (error) {
        console.error('Ollama error:', error.message);
        return null;
    }
}

// Get AI response with PDF knowledge
async function getAIResponse(userMessage, history) {
    // Search for relevant content in PDF knowledge base
    const relevantContent = await searchRelevantContent(userMessage);
    
    if (relevantContent && relevantContent.length > 0) {
        console.log(`Found ${relevantContent.length} relevant sections for: ${userMessage.substring(0, 50)}`);
        
        // Try to generate answer using Ollama with context
        const ollamaAnswer = await generateAnswer(userMessage, relevantContent);
        if (ollamaAnswer && ollamaAnswer.length > 20) {
            return { 
                response: `📚 *From my PDF knowledge:*\n\n${ollamaAnswer}\n\n---\n*Source:* ${relevantContent[0].source}`,
                model: 'ollama'
            };
        }
        
        // Fallback to returning the relevant content directly
        let response = `📚 *I found this in my PDF knowledge base:*\n\n`;
        for (let i = 0; i < Math.min(2, relevantContent.length); i++) {
            response += `\n**From ${relevantContent[i].source}:**\n${relevantContent[i].content.substring(0, 800)}...\n`;
        }
        return { response: response, model: 'knowledge' };
    }
    
    // Try ChatGPT if available
    if (openaiApiKey) {
        try {
            const messages = [
                { role: 'system', content: `You are ${aiName}, a helpful AI assistant.` },
                ...history.slice(-5),
                { role: 'user', content: userMessage }
            ];
            const response = await axios.post('https://api.openai.com/v1/chat/completions', {
                model: 'gpt-3.5-turbo',
                messages: messages,
                temperature: 0.7,
                max_tokens: 500
            }, {
                headers: { 'Authorization': `Bearer ${openaiApiKey}` },
                timeout: 20000
            });
            if (response.data.choices[0].message.content) {
                return { response: response.data.choices[0].message.content, model: 'chatgpt' };
            }
        } catch (error) {}
    }
    
    // Check if user has uploaded any PDFs
    return new Promise((resolve) => {
        db.get('SELECT COUNT(*) as count FROM pdf_knowledge', (err, result) => {
            const count = result ? result.count : 0;
            if (count === 0) {
                resolve({ 
                    response: `📚 *I haven't learned any PDFs yet!*

Send me a PDF file to read and learn from.

Once I've read it, I'll be able to answer questions about its content! 🧠`,
                    model: 'fallback' 
                });
            } else {
                resolve({ 
                    response: `📚 *I have ${count} pieces of knowledge from PDFs you've sent!*

Try asking me something more specific about what you taught me.

Example: "What does the PDF say about [topic]?"`,
                    model: 'fallback' 
                });
            }
        });
    });
}

// User management functions
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
        db.get('SELECT COUNT(*) as count FROM pdf_knowledge', (err, result) => {
            const knowledgeCount = result ? result.count : 0;
            const welcomeMessage = `🦞 *Welcome to ${aiName}!* 🦞

I can read PDFs and answer questions about their content!

━━━━━━━━━━━━━━━━━━━━━

✨ *What I can do:*
• 📚 Read and learn from PDF documents
• 🧠 Answer questions based on what I read
• 💡 Find specific information from PDFs

📋 *How to use me:*
1. Send me a PDF file - I'll read it completely
2. Wait for me to finish learning (I'll show progress)
3. Ask me questions about the PDF content!

📁 *Current Knowledge:* ${knowledgeCount} facts learned

━━━━━━━━━━━━━━━━━━━━━

*Send me a PDF to start teaching me!* 🚀`;

            bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
        });
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

// Handle PDF uploads
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
    
    if (fileExt !== '.pdf') {
        bot.sendMessage(chatId, `❌ Please send PDF files only.`);
        return;
    }
    
    // Check if already processing
    if (processingQueue.get(userId)) {
        bot.sendMessage(chatId, `⏳ *Already processing a PDF!*\n\nPlease wait for the current PDF to finish learning before sending another.`);
        return;
    }
    
    processingQueue.set(userId, true);
    
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
        
        // Process PDF
        await processPDF(filePath, fileName, chatId, bot);
        
        // Clean up
        fs.unlinkSync(filePath);
        
    } catch (error) {
        console.error('File processing error:', error);
        bot.sendMessage(chatId, `❌ Error processing file. Please try again.`);
    } finally {
        processingQueue.delete(userId);
    }
});

// /knowledge command - Search knowledge base
bot.onText(/\/knowledge(?:\s+(.+))?/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const query = match ? match[1] : null;
    
    const approved = await isApproved(userId);
    if (!approved) {
        bot.sendMessage(chatId, "⏳ *Access Pending*");
        return;
    }
    
    if (!query) {
        db.get('SELECT COUNT(*) as count FROM pdf_knowledge', (err, result) => {
            const count = result ? result.count : 0;
            bot.sendMessage(chatId, `📚 *Knowledge Base Status*

**Total facts learned:** ${count}
**PDFs processed:** (check stats)

*Usage:* /knowledge <topic or question>

*Examples:*
• /knowledge what is CEH
• /knowledge Kali Linux commands
• /knowledge nmap scanning

*Send me a PDF to add to my knowledge!* 📄`, { parse_mode: 'Markdown' });
        });
        return;
    }
    
    bot.sendMessage(chatId, `🔍 *Searching for:* "${query}"`);
    
    const results = await searchRelevantContent(query);
    
    if (results && results.length > 0) {
        let response = `📚 *Found ${results.length} relevant results:*\n\n`;
        for (let i = 0; i < Math.min(3, results.length); i++) {
            response += `**${i+1}. From ${results[i].source}**\n`;
            response += `${results[i].content.substring(0, 600)}...\n\n`;
        }
        bot.sendMessage(chatId, response);
    } else {
        bot.sendMessage(chatId, `📚 *No knowledge found for:* "${query}"

**Try:**
• Different keywords
• Upload a PDF about this topic first
• Ask me directly - I'll search my memory!

*Send me a PDF to teach me!* 📄`);
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
        db.get('SELECT COUNT(*) as knowledge FROM pdf_knowledge', (err2, knowledge) => {
            db.get('SELECT COUNT(DISTINCT pdf_name) as pdfs FROM pdf_knowledge', (err3, pdfs) => {
                const statsMessage = `📊 *${aiName} Stats*

**Conversations:** ${total.total || 0}
**Knowledge Facts:** ${knowledge.knowledge || 0}
**PDFs Learned:** ${pdfs.pdfs || 0}
**AI Model:** ${openaiApiKey ? 'ChatGPT + Ollama' : 'Ollama'}

*Send me PDFs to grow my knowledge!* 📚🦞`;

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

console.log(`🦞 ${aiName} is ready! Send me PDF files to read and learn!`);
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

    log_success "ClawBot created with proper PDF learning!"
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
        echo -e "\n📚 Knowledge: $(sqlite3 ~/.clawbot/chat_history.db 'SELECT COUNT(*) FROM pdf_knowledge;' 2>/dev/null || echo '0') facts"
        echo -e "\n📁 PDFs: $(sqlite3 ~/.clawbot/chat_history.db 'SELECT COUNT(DISTINCT pdf_name) FROM pdf_knowledge;' 2>/dev/null || echo '0') files"
        ;;
    logs)
        tail -f ~/clawbot-telegram/bot.log
        ;;
    knowledge)
        echo -e "${BLUE}Knowledge Base Summary:${NC}"
        sqlite3 ~/.clawbot/chat_history.db "SELECT pdf_name, COUNT(*) as facts FROM pdf_knowledge GROUP BY pdf_name;" 2>/dev/null
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

# Main installation function
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

    echo -e "${CYAN}🦞 ClawBot PDF Learning Features:${NC}"
    echo "  • 📚 Reads and learns from entire PDFs"
    echo "  • 🧠 Answers questions based on PDF content"
    echo "  • 🔍 Searches through learned knowledge"
    echo "  • 📊 Shows learning progress"
    echo "  • 💾 Stores all learned information"
    echo ""
    echo -e "${CYAN}📁 How to use:${NC}"
    echo "  1. Send a PDF file - I'll read EVERY page"
    echo "  2. Watch progress as I learn (shows percentage)"
    echo "  3. Ask questions - I'll search my memory and answer"
    echo "  4. Use /knowledge <topic> - Search specific topics"
    echo ""
    echo -e "${CYAN}📋 Commands:${NC}"
    echo "  • Send a PDF - I'll read and learn everything"
    echo "  • Ask any question - I'll answer from PDFs"
    echo "  • /knowledge <topic> - Search my knowledge"
    echo "  • /stats - View learning statistics"
    echo "  • /clear - Clear conversation"
    echo ""
    echo -e "${CYAN}👑 Admin Commands:${NC}"
    echo "  • /approve @username - Approve new users"
    echo ""
    echo -e "${GREEN}🎉 Send a PDF file and I'll read it completely!${NC}\n"
}

main "$@"
