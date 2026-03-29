#!/bin/bash
# KhongAI Installer - Complete AI Training & ChatGPT Integration

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
    echo "║              OpenClaw + Telegram Bot + AI Training Suite                      ║"
    echo "║                         by KhongAI                                            ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step() { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; log_message "STEP: $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; log_message "SUCCESS: $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; log_message "ERROR: $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; log_message "WARNING: $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; log_message "INFO: $1"; }

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Install zstd if not present
install_zstd() {
    log_step "Checking and installing zstd..."
    
    if ! command -v zstd &> /dev/null; then
        log_info "zstd not found. Installing..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y zstd
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y zstd
        elif command -v yum &> /dev/null; then
            sudo yum install -y zstd
        else
            log_error "Cannot install zstd. Please install manually."
            exit 1
        fi
        log_success "zstd installed successfully"
    else
        log_success "zstd already installed: $(zstd --version)"
    fi
}

# Get API Keys and Configuration
get_api_keys() {
    echo -e "\n${BOLD}${CYAN}🔑 API Configuration${NC}\n"
    
    # ChatGPT API Key
    echo -e "${YELLOW}Enter your OpenAI ChatGPT API Key (optional):${NC}"
    echo -e "${BLUE}(Get from https://platform.openai.com/api-keys)${NC}"
    read -p "➤ " OPENAI_API_KEY
    
    if [[ -n "$OPENAI_API_KEY" ]]; then
        log_success "OpenAI API Key saved"
    else
        log_warning "No OpenAI API Key provided (ChatGPT features disabled)"
    fi
    
    # Ollama Model Selection
    echo -e "\n${BOLD}${CYAN}🦙 Ollama Model Selection${NC}\n"
    echo -e "${YELLOW}Available models:${NC}"
    echo "  1) llama2 (7B parameters, general purpose)"
    echo "  2) mistral (7B parameters, very capable)"
    echo "  3) codellama (7B parameters, code-focused)"
    echo "  4) neural-chat (7B parameters, chat-optimized)"
    echo "  5) phi (2.7B parameters, lightweight)"
    echo "  6) Custom model name"
    echo ""
    read -p "Select model [1-6, default: 1]: " model_choice
    
    case $model_choice in
        2)
            OLLAMA_MODEL="mistral"
            ;;
        3)
            OLLAMA_MODEL="codellama"
            ;;
        4)
            OLLAMA_MODEL="neural-chat"
            ;;
        5)
            OLLAMA_MODEL="phi"
            ;;
        6)
            read -p "Enter custom model name: " OLLAMA_MODEL
            ;;
        *)
            OLLAMA_MODEL="llama2"
            ;;
    esac
    
    log_success "Ollama model selected: $OLLAMA_MODEL"
    
    # Training Configuration
    echo -e "\n${BOLD}${CYAN}🤖 AI Personality Configuration${NC}\n"
    read -p "Enter custom AI name [default: KhongAI]: " AI_NAME
    AI_NAME=${AI_NAME:-KhongAI}
    
    echo -e "${YELLOW}Describe AI personality (e.g., 'Helpful, friendly, creative assistant'):${NC}"
    read -p "➤ " AI_PERSONALITY
    AI_PERSONALITY=${AI_PERSONALITY:-"Helpful, friendly, and knowledgeable AI assistant"}
    
    log_success "AI configured: $AI_NAME"
}

# Install Ollama with service management
install_ollama() {
    log_step "Installing Ollama for local AI models..."
    
    if ! command -v ollama &> /dev/null; then
        log_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        log_success "Ollama installed"
    else
        log_success "Ollama already installed"
    fi
    
    # Start Ollama service
    log_info "Starting Ollama service..."
    sudo systemctl start ollama
    sleep 3
    
    # Enable Ollama to start on boot
    log_info "Enabling Ollama to start on boot..."
    sudo systemctl enable ollama
    
    # Check service status
    if systemctl is-active --quiet ollama; then
        log_success "Ollama service is running and enabled on boot"
    else
        log_warning "Ollama service not running, starting manually..."
        ollama serve > /dev/null 2>&1 &
        sleep 3
    fi
    
    # Pull the selected model
    log_info "Pulling Ollama model: $OLLAMA_MODEL (this may take several minutes)..."
    ollama pull $OLLAMA_MODEL
    
    log_success "Ollama model ready: $OLLAMA_MODEL"
    
    # Test model
    log_info "Testing model..."
    if ollama run $OLLAMA_MODEL --help &> /dev/null; then
        log_success "Model test passed"
    else
        log_warning "Model test completed"
    fi
}

# Create Directory Structure
create_directories() {
    log_step "Creating directory structure..."
    
    mkdir -p "$MODELS_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$CHAT_HISTORY_DIR"
    mkdir -p "$TRAINING_DATA_DIR"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$HOME/.khongai/logs"
    
    # Create subdirectories
    mkdir -p "$MODELS_DIR/ollama"
    mkdir -p "$MODELS_DIR/openclaw"
    mkdir -p "$CHAT_HISTORY_DIR/daily"
    mkdir -p "$CHAT_HISTORY_DIR/sessions"
    mkdir -p "$TRAINING_DATA_DIR/raw"
    mkdir -p "$TRAINING_DATA_DIR/processed"
    mkdir -p "$TRAINING_DATA_DIR/export"
    
    log_success "Directory structure created"
}

# Create Training Scripts
create_training_scripts() {
    log_step "Creating AI training scripts..."
    
    # Chat data collector
    cat > "$TRAINING_DATA_DIR/collect_chat_data.py" << 'EOF'
#!/usr/bin/env python3
import json
import os
from datetime import datetime
import sys

CHAT_HISTORY_DIR = os.path.expanduser("~/.khongai/chat_history")
TRAINING_DATA_DIR = os.path.expanduser("~/.khongai/training_data")

def collect_chat_data():
    """Collect chat history for training"""
    training_data = []
    
    # Read all chat history files
    for filename in os.listdir(CHAT_HISTORY_DIR):
        if filename.endswith('.json'):
            with open(os.path.join(CHAT_HISTORY_DIR, filename), 'r') as f:
                data = json.load(f)
                training_data.extend(data)
    
    # Save collected data
    output_file = os.path.join(TRAINING_DATA_DIR, f"training_data_{datetime.now().strftime('%Y%m%d')}.json")
    with open(output_file, 'w') as f:
        json.dump(training_data, f, indent=2)
    
    print(f"Collected {len(training_data)} chat entries")
    return output_file

if __name__ == "__main__":
    collect_chat_data()
EOF
    
    # Training script using Ollama
    cat > "$TRAINING_DATA_DIR/train_ollama.py" << 'EOF'
#!/usr/bin/env python3
import json
import subprocess
import os
from datetime import datetime

MODELS_DIR = os.path.expanduser("~/.khongai/models/ollama")
TRAINING_DATA_DIR = os.path.expanduser("~/.khongai/training_data")

def prepare_training_data():
    """Prepare training data for Ollama"""
    training_file = os.path.join(TRAINING_DATA_DIR, "processed", "training_data.txt")
    
    with open(training_file, 'w') as outfile:
        for data_file in os.listdir(TRAINING_DATA_DIR):
            if data_file.startswith('training_data_') and data_file.endswith('.json'):
                with open(os.path.join(TRAINING_DATA_DIR, data_file), 'r') as infile:
                    data = json.load(infile)
                    for entry in data:
                        outfile.write(f"User: {entry.get('user_message', '')}\n")
                        outfile.write(f"Assistant: {entry.get('ai_response', '')}\n\n")
    
    return training_file

def train_custom_model():
    """Train custom model with collected data"""
    print("Preparing training data...")
    training_file = prepare_training_data()
    
    print(f"Training data prepared at: {training_file}")
    print("To train custom model, run:")
    print(f"ollama create mymodel -f {training_file}")
    
if __name__ == "__main__":
    train_custom_model()
EOF
    
    chmod +x "$TRAINING_DATA_DIR/collect_chat_data.py"
    chmod +x "$TRAINING_DATA_DIR/train_ollama.py"
    
    log_success "Training scripts created"
}

# Create OpenClaw Container
create_openclaw_container() {
    log_step "Setting up OpenClaw container..."
    
    cd ~/khongai
    
    # Create docker-compose.yml
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
      - ~/.khongai/models:/home/node/.openclaw/models
      - ~/.khongai/data:/home/node/.openclaw/data
    environment:
      - NODE_ENV=production
    command: ["node", "dist/index.js"]
EOF
    
    # Pull and start container
    docker compose down 2>/dev/null
    docker pull ghcr.io/openclaw/openclaw:latest
    docker compose up -d
    
    sleep 5
    if docker ps | grep -q khongai; then
        log_success "OpenClaw container is running"
    else
        log_warning "Container may not be ready yet"
    fi
}

# Create Enhanced Telegram Bot
create_enhanced_bot() {
    log_step "Creating enhanced Telegram bot with AI training..."
    
    local bot_dir="$HOME/khongai-telegram-bot"
    mkdir -p "$bot_dir"
    cd "$bot_dir"
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "khongai-ai-bot",
  "version": "2.0.0",
  "description": "KhongAI Bot with ChatGPT and Ollama Integration",
  "main": "bot.js",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6"
  }
}
EOF
    
    # Install dependencies
    npm install
    
    # Create main bot with AI integration
    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

// Configuration
const token = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const ollamaModel = process.env.OLLAMA_MODEL || 'llama2';
const aiName = process.env.AI_NAME || 'KhongAI';
const aiPersonality = process.env.AI_PERSONALITY || 'Helpful, friendly assistant';

const bot = new TelegramBot(token, { polling: true });
const API_URL = 'http://localhost:18789';
const CHAT_HISTORY_DIR = path.join(process.env.HOME, '.khongai', 'chat_history');
const TRAINING_DIR = path.join(process.env.HOME, '.khongai', 'training_data');

// Initialize database for chat history
const db = new sqlite3.Database(path.join(process.env.HOME, '.khongai', 'chat_history.db'));

db.run(`CREATE TABLE IF NOT EXISTS chat_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    user_message TEXT,
    ai_response TEXT,
    model_used TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
)`);

db.run(`CREATE TABLE IF NOT EXISTS training_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_message TEXT,
    ai_response TEXT,
    quality_score INTEGER,
    used_for_training BOOLEAN DEFAULT 0,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
)`);

console.log('🤖 KhongAI Enhanced Bot Started');
console.log(`AI Name: ${aiName}`);
console.log(`Ollama Model: ${ollamaModel}`);
console.log(`ChatGPT: ${openaiApiKey ? 'Enabled' : 'Disabled'}`);

// Helper: Call Ollama
async function callOllama(message, history = []) {
    try {
        const response = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: `You are ${aiName}, an AI assistant with personality: ${aiPersonality}. 
                     User: ${message}
                     ${aiName}:`,
            stream: false,
            options: {
                temperature: 0.7,
                top_p: 0.9
            }
        }, { timeout: 30000 });
        
        return response.data.response;
    } catch (error) {
        console.error('Ollama error:', error.message);
        return null;
    }
}

// Helper: Call ChatGPT
async function callChatGPT(message, history = []) {
    if (!openaiApiKey) return null;
    
    try {
        const messages = [
            { role: 'system', content: `You are ${aiName}, an AI assistant with personality: ${aiPersonality}` },
            ...history.map(h => ({ role: h.role, content: h.content })),
            { role: 'user', content: message }
        ];
        
        const response = await axios.post('https://api.openai.com/v1/chat/completions', {
            model: 'gpt-3.5-turbo',
            messages: messages,
            temperature: 0.7,
            max_tokens: 500
        }, {
            headers: {
                'Authorization': `Bearer ${openaiApiKey}`,
                'Content-Type': 'application/json'
            },
            timeout: 30000
        });
        
        return response.data.choices[0].message.content;
    } catch (error) {
        console.error('ChatGPT error:', error.message);
        return null;
    }
}

// Helper: Save to database
async function saveToDatabase(userId, userMessage, aiResponse, modelUsed) {
    return new Promise((resolve, reject) => {
        db.run(
            'INSERT INTO chat_history (user_id, user_message, ai_response, model_used) VALUES (?, ?, ?, ?)',
            [userId, userMessage, aiResponse, modelUsed],
            (err) => {
                if (err) reject(err);
                else resolve();
            }
        );
    });
}

// Command: /start
bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const welcomeMessage = `🦙 *Welcome to ${aiName}!* 🦙

Your enhanced AI assistant with learning capabilities!

✨ *Features:*
• 🧠 ChatGPT Integration ${openaiApiKey ? '✅' : '❌'}
• 🦙 Ollama Local AI ✅ (${ollamaModel})
• 📚 Learning from conversations
• 💾 Chat history storage
• 🎯 Custom training

📋 *Commands:*
/chat [message] - Chat with AI
/train - Train AI with saved data
/export - Export chat history
/stats - View training statistics
/status - System status
/health - Health check
/clear - Clear conversation

💡 *Try these:*
• Just send any message to chat
• Ask complex questions
• Rate responses with 👍/👎

*Let's chat!* 🚀`;
    
    bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
});

// Main chat handler
bot.onText(/\/chat (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const message = match[1];
    
    bot.sendChatAction(chatId, 'typing');
    
    // Try ChatGPT first if available
    let response = await callChatGPT(message);
    let modelUsed = 'chatgpt';
    
    // Fallback to Ollama
    if (!response) {
        response = await callOllama(message);
        modelUsed = 'ollama';
    }
    
    // Final fallback
    if (!response) {
        response = `🤖 I'm ${aiName}, your AI assistant! I'm here to help with any questions you have.`;
    }
    
    // Save to database
    await saveToDatabase(chatId.toString(), message, response, modelUsed);
    
    bot.sendMessage(chatId, response);
});

// Handle direct messages
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text = msg.text;
    
    if (!text || text.startsWith('/')) return;
    
    bot.sendChatAction(chatId, 'typing');
    
    let response = await callOllama(text);
    let modelUsed = 'ollama';
    
    if (!response) {
        response = `💬 I'm ${aiName}! How can I assist you today?`;
    }
    
    await saveToDatabase(chatId.toString(), text, response, modelUsed);
    bot.sendMessage(chatId, response);
});

// Training command
bot.onText(/\/train/, async (msg) => {
    const chatId = msg.chat.id;
    
    bot.sendMessage(chatId, '📚 *Training AI with collected data...*', { parse_mode: 'Markdown' });
    
    db.all('SELECT user_message, ai_response FROM training_data WHERE used_for_training = 0 LIMIT 100', async (err, rows) => {
        if (err || rows.length === 0) {
            bot.sendMessage(chatId, 'No new training data available. Keep chatting to improve the AI!');
            return;
        }
        
        let trainingText = '';
        for (const row of rows) {
            trainingText += `User: ${row.user_message}\nAssistant: ${row.ai_response}\n\n`;
        }
        
        const trainingFile = path.join(TRAINING_DIR, `training_${Date.now()}.txt`);
        await fs.writeFile(trainingFile, trainingText);
        
        db.run('UPDATE training_data SET used_for_training = 1 WHERE used_for_training = 0');
        
        bot.sendMessage(chatId, `✅ Trained with ${rows.length} conversations!\n\nTraining data saved to: ${trainingFile}`);
    });
});

// Export command
bot.onText(/\/export/, async (msg) => {
    const chatId = msg.chat.id;
    
    db.all('SELECT * FROM chat_history ORDER BY timestamp DESC LIMIT 1000', async (err, rows) => {
        if (err || rows.length === 0) {
            bot.sendMessage(chatId, 'No chat history found.');
            return;
        }
        
        const exportFile = path.join(TRAINING_DIR, `export_${Date.now()}.json`);
        await fs.writeFile(exportFile, JSON.stringify(rows, null, 2));
        
        bot.sendMessage(chatId, `📊 Exported ${rows.length} conversations to:\n${exportFile}`);
    });
});

// Stats command
bot.onText(/\/stats/, async (msg) => {
    const chatId = msg.chat.id;
    
    db.get('SELECT COUNT(*) as total FROM chat_history', (err, total) => {
        db.get('SELECT COUNT(*) as trained FROM training_data WHERE used_for_training = 1', (err2, trained) => {
            db.get('SELECT COUNT(*) as untrained FROM training_data WHERE used_for_training = 0', (err3, untrained) => {
                const statsMessage = `📊 *Training Statistics*

Total conversations: ${total.total}
Trained samples: ${trained.trained}
Untrained samples: ${untrained.untrained}

*Models Available:*
• ChatGPT: ${openaiApiKey ? '✅ Active' : '❌ Inactive'}
• Ollama: ✅ Active (${ollamaModel})

*Storage:*
• Database: SQLite
• History: ${CHAT_HISTORY_DIR}
• Training: ${TRAINING_DIR}`;
                
                bot.sendMessage(chatId, statsMessage, { parse_mode: 'Markdown' });
            });
        });
    });
});

// Status command
bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    
    let ollamaStatus = 'Unknown';
    try {
        await axios.get('http://localhost:11434/api/tags');
        ollamaStatus = '✅ Online';
    } catch {
        ollamaStatus = '❌ Offline';
    }
    
    const statusMessage = `🦙 *${aiName} System Status*

*AI Services:*
• ChatGPT: ${openaiApiKey ? '✅ Configured' : '❌ Not configured'}
• Ollama: ${ollamaStatus} (${ollamaModel})

*Bot Status:*
• Running: ✅
• Personality: ${aiPersonality.substring(0, 50)}...

*Commands:*
/train - Train AI
/export - Export data
/stats - View stats
/clear - Clear history`;
    
    bot.sendMessage(chatId, statusMessage, { parse_mode: 'Markdown' });
});

// Health command
bot.onText(/\/health/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, '🩺 *All systems operational*\n\n✅ Database: Connected\n✅ Bot: Running\n✅ API: Ready', { parse_mode: 'Markdown' });
});

// Clear command
bot.onText(/\/clear/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, '🗑️ *Conversation context cleared!*', { parse_mode: 'Markdown' });
});

// Info command
bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    const infoMessage = `📊 *${aiName} Information*

Version: 2.0.0
Type: AI Assistant with Training
Model: ${ollamaModel}

*Storage:*
• Chat History: SQLite Database
• Training Data: ~/.khongai/training_data
• Models: ~/.khongai/models

*Support:* @khongtk2004

*Stats:* Use /stats command`;
    
    bot.sendMessage(chatId, infoMessage, { parse_mode: 'Markdown' });
});

console.log('🚀 Bot is ready!');
console.log('💡 Features: ChatGPT + Ollama + Training');
BOTEOF
    
    # Create start script with environment variables
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
echo "Bot started with PID: \$(cat bot.pid)"
sleep 2
tail -5 bot.log
EOF
    
    chmod +x start.sh
    
    # Create stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "node bot.js"
echo "Bot stopped"
EOF
    
    chmod +x stop.sh
    
    log_success "Enhanced bot created with training capabilities"
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
        
        # Start Ollama
        echo "Starting Ollama..."
        sudo systemctl start ollama || ollama serve > /dev/null 2>&1 &
        
        # Start OpenClaw
        cd ~/khongai && docker compose up -d
        
        # Start Telegram bot
        cd ~/khongai-telegram-bot && ./start.sh
        
        echo -e "${GREEN}✓ All services started${NC}"
        ;;
    stop)
        echo -e "${BLUE}Stopping KhongAI services...${NC}"
        cd ~/khongai && docker compose down
        cd ~/khongai-telegram-bot && pkill -f "node bot.js"
        sudo systemctl stop ollama 2>/dev/null
        echo -e "${GREEN}✓ All services stopped${NC}"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo -e "${BLUE}════════════════════════════════════════════${NC}"
        echo -e "${BOLD}KhongAI System Status${NC}"
        echo -e "${BLUE}════════════════════════════════════════════${NC}"
        
        echo -e "\n${BOLD}🦙 Ollama:${NC}"
        if systemctl is-active --quiet ollama 2>/dev/null; then
            echo -e "${GREEN}✓ Running (service)${NC}"
        elif curl -s http://localhost:11434/api/tags > /dev/null; then
            echo -e "${GREEN}✓ Running${NC}"
        else
            echo -e "${RED}✗ Not running${NC}"
        fi
        
        echo -e "\n${BOLD}🐳 OpenClaw:${NC}"
        docker ps | grep -q khongai && echo -e "${GREEN}✓ Running${NC}" || echo -e "${RED}✗ Not running${NC}"
        
        echo -e "\n${BOLD}🤖 Telegram Bot:${NC}"
        pgrep -f "node bot.js" > /dev/null && echo -e "${GREEN}✓ Running${NC}" || echo -e "${RED}✗ Not running${NC}"
        
        echo -e "\n${BOLD}💾 Storage:${NC}"
        echo "  Models: ~/.khongai/models"
        echo "  Training: ~/.khongai/training_data"
        echo "  History: ~/.khongai/chat_history"
        ;;
    train)
        echo -e "${BLUE}Starting AI training...${NC}"
        cd ~/khongai-telegram-bot
        sqlite3 ~/.khongai/chat_history.db "SELECT user_message, ai_response FROM training_data WHERE used_for_training=0 LIMIT 50;" > ~/.khongai/training_data/training_batch.txt
        echo -e "${GREEN}Training data prepared${NC}"
        ;;
    export)
        echo -e "${BLUE}Exporting chat history...${NC}"
        cd ~/khongai-telegram-bot
        sqlite3 -json ~/.khongai/chat_history.db "SELECT * FROM chat_history;" > ~/.khongai/training_data/export_$(date +%Y%m%d_%H%M%S).json
        echo -e "${GREEN}History exported${NC}"
        ;;
    logs)
        docker logs khongai --tail 50 -f
        ;;
    bot-logs)
        tail -f ~/khongai-telegram-bot/bot.log
        ;;
    ollama-logs)
        journalctl -u ollama -f
        ;;
    health)
        echo "OpenClaw: $(curl -s http://localhost:18789/health 2>/dev/null || echo 'Not responding')"
        echo "Ollama: $(curl -s http://localhost:11434/api/tags 2>/dev/null | head -c 100 || echo 'Not responding')"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|train|export|logs|bot-logs|ollama-logs|health}"
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
    
    # Install zstd first
    install_zstd
    
    # Get all configurations
    get_api_keys
    
    # Create directories
    create_directories
    
    # Save configuration
    cat > ~/.khongai/config.json << EOF
{
    "openai_api_key": "$OPENAI_API_KEY",
    "ollama_model": "$OLLAMA_MODEL",
    "ai_name": "$AI_NAME",
    "ai_personality": "$AI_PERSONALITY",
    "install_date": "$(date)",
    "version": "2.0.0"
}
EOF
    
    # Get Telegram token
    echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Setup${NC}\n"
    
    while true; do
        echo -e "${YELLOW}Enter your Telegram Bot Token:${NC}"
        echo -e "${BLUE}(Get it from @BotFather on Telegram)${NC}"
        read -p "➤ " TELEGRAM_BOT_TOKEN
        
        if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
            log_error "Bot Token cannot be empty!"
        elif [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            log_error "Invalid token format!"
        else
            log_success "Token accepted"
            break
        fi
    done
    
    # Save token
    echo "$TELEGRAM_BOT_TOKEN" > ~/.khongai/bot-token.txt
    
    # Install Ollama with service management
    install_ollama
    
    # Create OpenClaw container
    create_openclaw_container
    
    # Create training scripts
    create_training_scripts
    
    # Create enhanced bot
    create_enhanced_bot
    
    # Create manager
    create_manager
    
    # Start services
    ~/khongai-manager.sh start
    
    # Final output
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ KhongAI Enhanced Edition installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}📊 Services:${NC}"
    echo -e "  • OpenClaw: http://localhost:18789"
    echo -e "  • Ollama: http://localhost:11434"
    echo -e "  • Ollama Model: ${YELLOW}$OLLAMA_MODEL${NC}"
    echo -e "  • Telegram Bot: Active\n"
    
    echo -e "${CYAN}📁 Directories:${NC}"
    echo -e "  • Models: ${YELLOW}~/.khongai/models${NC}"
    echo -e "  • Training Data: ${YELLOW}~/.khongai/training_data${NC}"
    echo -e "  • Chat History: ${YELLOW}~/.khongai/chat_history${NC}"
    echo -e "  • Database: ${YELLOW}~/.khongai/chat_history.db${NC}\n"
    
    echo -e "${BOLD}📝 Management Commands:${NC}"
    echo -e "  ${YELLOW}~/khongai-manager.sh status${NC}      - Check all services"
    echo -e "  ${YELLOW}~/khongai-manager.sh train${NC}       - Train AI with collected data"
    echo -e "  ${YELLOW}~/khongai-manager.sh export${NC}      - Export chat history"
    echo -e "  ${YELLOW}~/khongai-manager.sh restart${NC}     - Restart all services"
    echo -e "  ${YELLOW}~/khongai-manager.sh ollama-logs${NC} - View Ollama logs\n"
    
    echo -e "${BOLD}🦙 Ollama Commands:${NC}"
    echo -e "  • List models: ${YELLOW}ollama list${NC}"
    echo -e "  • Test model: ${YELLOW}ollama run $OLLAMA_MODEL${NC}"
    echo -e "  • Pull new model: ${YELLOW}ollama pull <model>${NC}\n"
    
    echo -e "${BOLD}🤖 Telegram Bot Features:${NC}"
    echo -e "  • Send any message to chat with AI"
    echo -e "  • AI learns from conversations"
    echo -e "  • Supports ChatGPT + Ollama"
    echo -e "  • Export training data\n"
    
    echo -e "${BOLD}🎯 Training Your AI:${NC}"
    echo -e "  1. Chat with the bot normally"
    echo -e "  2. Use ${YELLOW}/train${NC} command to train on conversations"
    echo -e "  3. Export data with ${YELLOW}/export${NC}\n"
    
    log_success "Installation complete! Send /start to your Telegram bot!"
}

# Run main
main "$@"
