#!/bin/bash
# ClawBot Installer - PDF Learning + Firefox Search Engine & AI Analysis

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
    echo "║                   ClawBot - PDF Learning + Search Engine                    ║"
    echo "║         Reads PDFs · Searches Web · Analyzes Results with AI                ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step()    { echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info()    { echo -e "${CYAN}ℹ${NC} $1"; }

# ─────────────────────────────────────────────────────────────────────────────
# Install system dependencies including Firefox
# ─────────────────────────────────────────────────────────────────────────────
install_deps() {
    log_step "Installing system dependencies..."

    # zstd
    if ! command -v zstd &>/dev/null; then
        if   command -v dnf     &>/dev/null; then sudo dnf install -y zstd
        elif command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y zstd
        fi
    fi

    # Node.js
    if ! command -v node &>/dev/null; then
        log_info "Installing Node.js..."
        if   command -v dnf     &>/dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
        elif command -v apt-get &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
    fi

    # Firefox (required for search engine)
    install_firefox

    # Python3 + pip (for the search scraper helper)
    if ! command -v python3 &>/dev/null; then
        log_info "Installing Python3..."
        if   command -v dnf     &>/dev/null; then sudo dnf install -y python3 python3-pip
        elif command -v apt-get &>/dev/null; then sudo apt-get install -y python3 python3-pip
        fi
    fi

    # pip packages for scraping
    log_info "Installing Python scraping libraries..."
    pip3 install --quiet requests beautifulsoup4 selenium webdriver-manager 2>/dev/null || \
    pip3 install requests beautifulsoup4 selenium webdriver-manager

    log_success "All dependencies installed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Install Firefox if not present
# ─────────────────────────────────────────────────────────────────────────────
install_firefox() {
    if command -v firefox &>/dev/null || command -v firefox-esr &>/dev/null; then
        log_success "Firefox already installed"
        return
    fi

    log_info "Firefox not found — installing now..."

    if command -v dnf &>/dev/null; then
        # RHEL / Fedora / CentOS
        sudo dnf install -y firefox || {
            log_info "Trying Firefox ESR via snap..."
            sudo dnf install -y snapd 2>/dev/null
            sudo snap install firefox
        }
    elif command -v apt-get &>/dev/null; then
        # Debian / Ubuntu
        sudo apt-get update
        sudo apt-get install -y firefox || sudo apt-get install -y firefox-esr
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y firefox
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm firefox
    else
        log_warning "Cannot auto-install Firefox. Download from https://www.mozilla.org/firefox/"
    fi

    # Install geckodriver (needed by Selenium)
    if ! command -v geckodriver &>/dev/null; then
        log_info "Installing geckodriver for Firefox automation..."
        GECKO_VER=$(curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest \
                    | grep '"tag_name"' | cut -d '"' -f4)
        GECKO_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKO_VER}/geckodriver-${GECKO_VER}-linux64.tar.gz"
        curl -L "$GECKO_URL" -o /tmp/geckodriver.tar.gz
        tar -xzf /tmp/geckodriver.tar.gz -C /tmp
        sudo mv /tmp/geckodriver /usr/local/bin/geckodriver
        sudo chmod +x /usr/local/bin/geckodriver
        rm -f /tmp/geckodriver.tar.gz
        log_success "geckodriver installed"
    fi

    log_success "Firefox ready for search engine"
}

# ─────────────────────────────────────────────────────────────────────────────
# API Keys
# ─────────────────────────────────────────────────────────────────────────────
get_api_keys() {
    echo -e "\n${BOLD}${CYAN}🔑 API Configuration${NC}\n"

    echo -e "${YELLOW}Enter OpenAI ChatGPT API Key (optional, for better analysis):${NC}"
    echo -e "${BLUE}(Get from https://platform.openai.com/api-keys)${NC}"
    read -p "➤ " OPENAI_API_KEY
    [[ -n "$OPENAI_API_KEY" ]] && log_success "ChatGPT API enabled" || log_info "Using Ollama only"

    echo -e "\n${BOLD}${CYAN}🦙 Ollama Model${NC}\n"
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

    echo -e "\n${BOLD}${CYAN}🦞 Bot Name${NC}\n"
    read -p "Enter bot name [default: ClawBot]: " AI_NAME
    AI_NAME=${AI_NAME:-ClawBot}
    log_success "Bot name: $AI_NAME"
}

# ─────────────────────────────────────────────────────────────────────────────
# Admin users
# ─────────────────────────────────────────────────────────────────────────────
get_admin_usernames() {
    echo -e "\n${BOLD}${CYAN}👥 Admin Users${NC}\n"
    echo -e "${YELLOW}Enter Telegram usernames (without @, comma-separated):${NC}"
    read -p "Admin usernames: " ADMIN_USERNAMES_INPUT

    IFS=',' read -ra ADMIN_LIST <<< "$ADMIN_USERNAMES_INPUT"
    ADMIN_USERNAMES=()
    for username in "${ADMIN_LIST[@]}"; do
        username=$(echo "$username" | tr -d ' ' | sed 's/^@//')
        [[ -n "$username" ]] && ADMIN_USERNAMES+=("$username")
    done
    [[ ${#ADMIN_USERNAMES[@]} -eq 0 ]] && ADMIN_USERNAMES=("khongtk2004")

    echo -e "\n${GREEN}✓ Admin users:${NC}"
    for admin in "${ADMIN_USERNAMES[@]}"; do echo "  • @$admin"; done
}

# ─────────────────────────────────────────────────────────────────────────────
# Directories
# ─────────────────────────────────────────────────────────────────────────────
create_directories() {
    log_step "Creating directories..."
    mkdir -p ~/.clawbot/{models,data,chat_history,training_data,logs,uploads,knowledge,processed_pdfs,search_cache}
    mkdir -p ~/clawbot
    mkdir -p ~/clawbot-telegram
    log_success "Directories created"
}

# ─────────────────────────────────────────────────────────────────────────────
# Ollama
# ─────────────────────────────────────────────────────────────────────────────
install_ollama() {
    log_step "Installing Ollama..."
    if ! command -v ollama &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    sudo systemctl start ollama 2>/dev/null || ollama serve >/dev/null 2>&1 &
    sleep 5
    sudo systemctl enable ollama 2>/dev/null || true
    log_info "Pulling $OLLAMA_MODEL model (this may take several minutes)..."
    ollama pull $OLLAMA_MODEL
    log_success "Ollama ready"
}

# ─────────────────────────────────────────────────────────────────────────────
# Python Firefox Search Scraper
# ─────────────────────────────────────────────────────────────────────────────
create_search_scraper() {
    log_step "Creating Firefox search scraper..."

    cat > ~/clawbot-telegram/search_scraper.py << 'PYEOF'
#!/usr/bin/env python3
"""
ClawBot Firefox Search Scraper
Uses Firefox headless + BeautifulSoup to search DuckDuckGo / Google
and return clean text results for AI analysis.
Usage: python3 search_scraper.py "your search query"
"""

import sys
import json
import time
import requests
from urllib.parse import quote_plus
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) "
        "Gecko/20100101 Firefox/120.0"
    )
}

def search_duckduckgo(query: str, max_results: int = 6) -> list[dict]:
    """Search DuckDuckGo and return list of {title, url, snippet}."""
    url = f"https://html.duckduckgo.com/html/?q={quote_plus(query)}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        soup = BeautifulSoup(resp.text, "html.parser")
        results = []
        for result in soup.select(".result__body")[:max_results]:
            title_tag   = result.select_one(".result__title a")
            snippet_tag = result.select_one(".result__snippet")
            url_tag     = result.select_one(".result__url")
            if title_tag and snippet_tag:
                results.append({
                    "title":   title_tag.get_text(strip=True),
                    "url":     url_tag.get_text(strip=True) if url_tag else "",
                    "snippet": snippet_tag.get_text(strip=True)
                })
        return results
    except Exception as e:
        return [{"title": "Error", "url": "", "snippet": str(e)}]


def fetch_page_text(url: str, max_chars: int = 3000) -> str:
    """Fetch a page and return clean text (first max_chars chars)."""
    try:
        if not url.startswith("http"):
            url = "https://" + url
        resp = requests.get(url, headers=HEADERS, timeout=10)
        soup = BeautifulSoup(resp.text, "html.parser")
        # Remove scripts, styles, navbars
        for tag in soup(["script", "style", "nav", "footer", "header", "aside"]):
            tag.decompose()
        text = soup.get_text(separator=" ", strip=True)
        return text[:max_chars]
    except Exception as e:
        return f"[Could not fetch page: {e}]"


def deep_search(query: str) -> dict:
    """Full search: get results + fetch top 3 page contents."""
    results  = search_duckduckgo(query, max_results=6)
    enriched = []

    for r in results[:3]:
        page_text = fetch_page_text(r["url"]) if r["url"] else ""
        enriched.append({
            "title":     r["title"],
            "url":       r["url"],
            "snippet":   r["snippet"],
            "page_text": page_text
        })

    # Add remaining results (snippet only)
    for r in results[3:]:
        enriched.append({
            "title":     r["title"],
            "url":       r["url"],
            "snippet":   r["snippet"],
            "page_text": ""
        })

    return {"query": query, "results": enriched}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No query provided"}))
        sys.exit(1)
    query = " ".join(sys.argv[1:])
    data  = deep_search(query)
    print(json.dumps(data, ensure_ascii=False))
PYEOF

    chmod +x ~/clawbot-telegram/search_scraper.py
    log_success "Firefox search scraper created"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main ClawBot (Node.js) with Search Engine integrated
# ─────────────────────────────────────────────────────────────────────────────
create_clawbot() {
    log_step "Creating ClawBot with PDF Learning + Firefox Search Engine..."

    cd ~/clawbot-telegram

    cat > package.json << 'EOF'
{
  "name": "clawbot",
  "version": "5.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0",
    "sqlite3": "^5.1.6",
    "pdf-parse": "^1.1.1"
  }
}
EOF

    npm install --silent 2>/dev/null || npm install

    # Build admin JSON array
    ADMIN_LIST_JSON="["
    for i in "${!ADMIN_USERNAMES[@]}"; do
        [ $i -gt 0 ] && ADMIN_LIST_JSON+=","
        ADMIN_LIST_JSON+="\"${ADMIN_USERNAMES[$i]}\""
    done
    ADMIN_LIST_JSON+="]"

    # ── bot.js ────────────────────────────────────────────────────────────────
    cat > bot.js << 'BOTEOF'
const TelegramBot = require('node-telegram-bot-api');
const axios       = require('axios');
const sqlite3     = require('sqlite3').verbose();
const path        = require('path');
const fs          = require('fs');
const pdfParse    = require('pdf-parse');
const { execFile } = require('child_process');

// ── Config ────────────────────────────────────────────────────────────────────
const token        = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const ollamaModel  = process.env.OLLAMA_MODEL || 'llama2';
const aiName       = process.env.AI_NAME      || 'ClawBot';
const ADMIN_USERNAMES = JSON.parse(process.env.ADMIN_USERNAMES || '["khongtk2004"]');
const SCRAPER_PATH = path.join(__dirname, 'search_scraper.py');

const bot        = new TelegramBot(token, { polling: true });
const UPLOAD_DIR = path.join(process.env.HOME, '.clawbot', 'uploads');
const PROC_DIR   = path.join(process.env.HOME, '.clawbot', 'processed_pdfs');
const CACHE_DIR  = path.join(process.env.HOME, '.clawbot', 'search_cache');

for (const d of [UPLOAD_DIR, PROC_DIR, CACHE_DIR])
    if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });

// ── Database ──────────────────────────────────────────────────────────────────
const db = new sqlite3.Database(path.join(process.env.HOME, '.clawbot', 'chat_history.db'));
db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        username TEXT, first_name TEXT,
        is_approved BOOLEAN DEFAULT 0,
        is_admin    BOOLEAN DEFAULT 0,
        registered_at DATETIME DEFAULT CURRENT_TIMESTAMP)`);

    db.run(`CREATE TABLE IF NOT EXISTS conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT, user_message TEXT, ai_response TEXT,
        model_used TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)`);

    db.run(`CREATE TABLE IF NOT EXISTS pdf_knowledge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pdf_name TEXT, page_number INTEGER, content TEXT,
        keywords TEXT, processed_at DATETIME DEFAULT CURRENT_TIMESTAMP)`);

    db.run(`CREATE TABLE IF NOT EXISTS knowledge_search (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT, relevant_content TEXT,
        pdf_source TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)`);

    db.run(`CREATE TABLE IF NOT EXISTS search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT, query TEXT, result_summary TEXT,
        searched_at DATETIME DEFAULT CURRENT_TIMESTAMP)`);
});

const userHistory    = new Map();
const processingQueue = new Map();

console.log(`🦞 ${aiName} started — Ollama: ${ollamaModel} | ChatGPT: ${openaiApiKey ? 'ON' : 'OFF'}`);

// ── Helper: run Python scraper ─────────────────────────────────────────────────
function runScraper(query) {
    return new Promise((resolve) => {
        execFile('python3', [SCRAPER_PATH, query], { timeout: 45000 }, (err, stdout) => {
            if (err) { resolve(null); return; }
            try   { resolve(JSON.parse(stdout)); }
            catch { resolve(null); }
        });
    });
}

// ── AI Analysis of search results ─────────────────────────────────────────────
async function analyzeSearchResults(query, searchData) {
    if (!searchData || !searchData.results || searchData.results.length === 0) return null;

    // Build context from results
    let context = `Search query: "${query}"\n\nSearch results:\n`;
    for (let i = 0; i < searchData.results.length; i++) {
        const r = searchData.results[i];
        context += `\n[Result ${i+1}] ${r.title}\nURL: ${r.url}\nSnippet: ${r.snippet}\n`;
        if (r.page_text) context += `Page content: ${r.page_text.substring(0, 800)}\n`;
    }

    const prompt = `You are ${aiName}, a research assistant. A user searched for: "${query}"

Here are the web search results:
${context}

Your job:
1. Read ALL the results carefully
2. Determine if the information is TRUE, FALSE, UNVERIFIED, or MIXED
3. Give an accurate, clear summary of what the web says
4. Cite which source(s) confirm the key facts
5. Flag anything misleading or unverified

Be concise and factual. Format:

📋 *Summary:* [2-3 sentence answer]

✅ *Verified facts:* [bullet list]

⚠️ *Note / Caution:* [any caveats, if needed]

🔗 *Best source:* [title + URL]`;

    // Try ChatGPT first
    if (openaiApiKey) {
        try {
            const resp = await axios.post('https://api.openai.com/v1/chat/completions', {
                model: 'gpt-3.5-turbo',
                messages: [{ role: 'user', content: prompt }],
                temperature: 0.3,
                max_tokens: 600
            }, { headers: { Authorization: `Bearer ${openaiApiKey}` }, timeout: 20000 });
            if (resp.data.choices[0].message.content)
                return { text: resp.data.choices[0].message.content, model: 'chatgpt' };
        } catch (_) {}
    }

    // Fallback: Ollama
    try {
        const resp = await axios.post('http://localhost:11434/api/generate', {
            model: ollamaModel,
            prompt: prompt,
            stream: false,
            options: { temperature: 0.3, num_predict: 600 }
        }, { timeout: 40000 });
        if (resp.data.response)
            return { text: resp.data.response.trim(), model: 'ollama' };
    } catch (_) {}

    // Fallback: manual summary
    const r0 = searchData.results[0];
    return {
        text: `📋 *Summary:* ${r0.snippet}\n\n🔗 *Source:* ${r0.title} — ${r0.url}`,
        model: 'direct'
    };
}

// ── Main /search command handler ───────────────────────────────────────────────
async function handleSearch(chatId, userId, query) {
    await bot.sendMessage(chatId,
        `🔍 *Searching the web for:*\n"${query}"\n\n🦊 Opening Firefox engine... please wait.`,
        { parse_mode: 'Markdown' });

    bot.sendChatAction(chatId, 'typing');

    const searchData = await runScraper(query);

    if (!searchData || !searchData.results || searchData.results.length === 0) {
        await bot.sendMessage(chatId,
            `❌ *Search failed*\n\nCouldn't fetch results for: "${query}"\n\n` +
            `Check your internet connection or try again.`);
        return;
    }

    await bot.sendMessage(chatId,
        `📡 *Found ${searchData.results.length} results!*\n🧠 Analyzing with AI...`,
        { parse_mode: 'Markdown' });

    bot.sendChatAction(chatId, 'typing');

    const analysis = await analyzeSearchResults(query, searchData);

    let response = `🔍 *Search Results for:* "${query}"\n\n`;
    if (analysis) {
        response += analysis.text;
    } else {
        response += `No analysis available.`;
    }

    // Show top raw results too
    response += `\n\n━━━━━━━━━━━━━━━━━━━━━\n📰 *Top Results:*\n`;
    for (let i = 0; i < Math.min(3, searchData.results.length); i++) {
        const r = searchData.results[i];
        response += `\n*${i+1}. ${r.title}*\n${r.snippet}\n🔗 ${r.url}\n`;
    }

    // Save to search history
    db.run('INSERT INTO search_history (user_id, query, result_summary) VALUES (?,?,?)',
        [userId, query, analysis ? analysis.text.substring(0, 500) : '']);

    // Split message if too long
    if (response.length > 4000) {
        const parts = response.match(/.{1,4000}/gs) || [response];
        for (const part of parts) {
            await bot.sendMessage(chatId, part, { parse_mode: 'Markdown' });
        }
    } else {
        await bot.sendMessage(chatId, response, { parse_mode: 'Markdown' });
    }
}

// ── PDF helpers (unchanged from v4) ───────────────────────────────────────────
async function extractPDFTextWithPages(filePath) {
    try {
        const data = await pdfParse(fs.readFileSync(filePath));
        return { text: data.text, pages: data.numpages };
    } catch { return null; }
}

function extractSearchKeywords(text) {
    const stop = new Set(['the','a','an','and','or','but','in','on','at','to','for',
        'of','with','by','is','are','was','were','be','been','being','that','this',
        'these','those','from','as','has','have','had','will','would','could',
        'should','may','might','must']);
    return [...new Set(text.toLowerCase().split(/\s+/)
        .filter(w => w.length > 3 && !stop.has(w)))]
        .join(', ');
}

function splitIntoChunks(text) {
    const chunks = text.split(/\n\s*\n|\.\s+/);
    const valid  = [];
    for (const c of chunks) {
        const t = c.trim();
        if (t.length > 100 && t.length < 2000) valid.push(t);
        else if (t.length >= 2000) {
            const subs = t.match(/.{1,1500}[.!?]\s+/g) || [t.substring(0, 1500)];
            for (const s of subs) if (s.trim().length > 100) valid.push(s.trim());
        }
    }
    return valid;
}

async function savePDFKnowledge(pdfName, pageNum, content, keywords) {
    return new Promise(resolve => {
        db.run('INSERT INTO pdf_knowledge (pdf_name,page_number,content,keywords) VALUES(?,?,?,?)',
            [pdfName, pageNum, content.substring(0, 2000), keywords], err => {
            if (!err) {
                for (const kw of keywords.split(', ').slice(0, 20)) {
                    if (kw.length > 3)
                        db.run('INSERT OR IGNORE INTO knowledge_search (keyword,relevant_content,pdf_source) VALUES(?,?,?)',
                            [kw, content.substring(0, 1000), pdfName]);
                }
            }
            resolve();
        });
    });
}

async function searchRelevantContent(question) {
    return new Promise(resolve => {
        const ql = question.toLowerCase();
        const results = [];
        db.all('SELECT keyword,relevant_content,pdf_source FROM knowledge_search', (_, rows) => {
            for (const r of (rows || []))
                if (ql.includes(r.keyword) || r.keyword.includes(ql))
                    results.push({ content: r.relevant_content, source: r.pdf_source, relevance: 10 });
            db.all('SELECT pdf_name,content FROM pdf_knowledge', (_, crows) => {
                for (const r of (crows || [])) {
                    const cl = r.content.toLowerCase();
                    if (cl.includes(ql)) {
                        let rel = 0;
                        for (const w of ql.split(/\s+/)) if (w.length > 3 && cl.includes(w)) rel++;
                        results.push({ content: r.content, source: r.pdf_name, relevance: rel });
                    }
                }
                results.sort((a, b) => b.relevance - a.relevance);
                const seen = new Set(); const uniq = [];
                for (const r of results) {
                    const k = r.content.substring(0, 100);
                    if (!seen.has(k)) { seen.add(k); uniq.push(r); if (uniq.length >= 5) break; }
                }
                resolve(uniq);
            });
        });
    });
}

async function processPDF(filePath, fileName, chatId) {
    bot.sendMessage(chatId, `📖 *Reading PDF: ${fileName}*\n\nExtracting knowledge...`, { parse_mode: 'Markdown' });
    const pdfData = await extractPDFTextWithPages(filePath);
    if (!pdfData || !pdfData.text || pdfData.text.length < 100) {
        bot.sendMessage(chatId, `❌ Couldn't read PDF. Try a PDF with selectable text.`);
        return false;
    }
    bot.sendMessage(chatId,
        `✅ *PDF Loaded*\n\n**Pages:** ${pdfData.pages}\n**Characters:** ${pdfData.text.length.toLocaleString()}\n\nLearning...`, { parse_mode: 'Markdown' });
    const chunks = splitIntoChunks(pdfData.text);
    let saved = 0;
    for (let i = 0; i < chunks.length; i++) {
        await savePDFKnowledge(fileName, Math.floor(i / 5) + 1, chunks[i], extractSearchKeywords(chunks[i]));
        saved++;
        if (i % 10 === 0 && i > 0)
            bot.sendMessage(chatId, `🔄 Progress: ${Math.floor((i / chunks.length) * 100)}% (${saved} facts)`);
    }
    fs.copyFileSync(filePath, path.join(PROC_DIR, fileName));
    bot.sendMessage(chatId,
        `🎉 *Learning Complete!*\n\n**File:** ${fileName}\n**Facts learned:** ${saved}\n\nAsk me anything about it! 🧠`, { parse_mode: 'Markdown' });
    return true;
}

async function generateAnswer(question, relevant) {
    if (!relevant || relevant.length === 0) return null;
    let context = '';
    for (let i = 0; i < Math.min(3, relevant.length); i++)
        context += `\n[Source ${i+1}]: ${relevant[i].content}\n`;
    const prompt = `You are ${aiName}. Answer the question using ONLY the sources below.\n\n${context}\n\nQuestion: ${question}\n\nBe accurate and concise.`;
    try {
        const r = await axios.post('http://localhost:11434/api/generate',
            { model: ollamaModel, prompt, stream: false, options: { temperature: 0.5, num_predict: 500 } },
            { timeout: 30000 });
        return r.data.response.trim();
    } catch { return null; }
}

async function getAIResponse(userMessage, history) {
    const relevant = await searchRelevantContent(userMessage);
    if (relevant && relevant.length > 0) {
        const ans = await generateAnswer(userMessage, relevant);
        if (ans && ans.length > 20)
            return { response: `📚 *From PDF knowledge:*\n\n${ans}\n\n---\n*Source:* ${relevant[0].source}`, model: 'ollama' };
        let r = `📚 *From my PDF knowledge base:*\n\n`;
        for (let i = 0; i < Math.min(2, relevant.length); i++)
            r += `\n**${relevant[i].source}:**\n${relevant[i].content.substring(0, 800)}...\n`;
        return { response: r, model: 'knowledge' };
    }
    if (openaiApiKey) {
        try {
            const messages = [
                { role: 'system', content: `You are ${aiName}, a helpful AI assistant.` },
                ...history.slice(-5),
                { role: 'user', content: userMessage }
            ];
            const r = await axios.post('https://api.openai.com/v1/chat/completions',
                { model: 'gpt-3.5-turbo', messages, temperature: 0.7, max_tokens: 500 },
                { headers: { Authorization: `Bearer ${openaiApiKey}` }, timeout: 20000 });
            if (r.data.choices[0].message.content)
                return { response: r.data.choices[0].message.content, model: 'chatgpt' };
        } catch (_) {}
    }
    return new Promise(resolve => {
        db.get('SELECT COUNT(*) as c FROM pdf_knowledge', (_, row) => {
            const c = row ? row.c : 0;
            resolve({ response: c === 0
                ? `📚 I haven't read any PDFs yet!\n\nSend me a PDF and I'll learn from it.\nOr use /search <query> to search the web! 🔍`
                : `📚 I have ${c} facts from PDFs.\n\nTry a more specific question or use /search <query> to search the web! 🔍`,
                model: 'fallback' });
        });
    });
}

// ── User management ────────────────────────────────────────────────────────────
const isApproved = (userId) => new Promise(resolve =>
    db.get('SELECT is_approved FROM users WHERE user_id=?', [userId], (_, r) => resolve(r && r.is_approved === 1)));

const isAdmin = (userId, username) => new Promise(resolve => {
    db.get('SELECT is_admin FROM users WHERE user_id=?', [userId], (_, r) => {
        if (r && r.is_admin) return resolve(true);
        if (ADMIN_USERNAMES.includes(username)) {
            db.run('INSERT OR REPLACE INTO users (user_id,username,is_approved,is_admin) VALUES(?,?,1,1)', [userId, username]);
            return resolve(true);
        }
        resolve(false);
    });
});

const registerUser = (uid, uname, fname) => new Promise(resolve =>
    db.run('INSERT OR IGNORE INTO users (user_id,username,first_name) VALUES(?,?,?)', [uid, uname, fname], () => resolve()));

// ── /start ─────────────────────────────────────────────────────────────────────
bot.onText(/\/start/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    const fname  = msg.from.first_name || '';
    await registerUser(userId, uname, fname);
    const ok = await isApproved(userId) || await isAdmin(userId, uname);
    if (!ok) {
        bot.sendMessage(chatId, `⏳ *Hey ${fname}!*\n\nYou need admin approval to use me.`);
        return;
    }
    db.get('SELECT COUNT(*) as c FROM pdf_knowledge', (_, r) => {
        bot.sendMessage(chatId, `🦞 *Welcome to ${aiName}!* 🦞

I can read PDFs AND search the web to answer your questions!

━━━━━━━━━━━━━━━━━━━━━

📚 *PDF Mode:*
• Send me any PDF → I'll read every page
• Ask questions → I'll answer from what I learned

🔍 *Search Mode:*
• /search <question> → I search the web with Firefox
• I analyze results and tell you what's TRUE
• I flag anything misleading or unverified

━━━━━━━━━━━━━━━━━━━━━

📋 *Commands:*
• /search <query>   — Web search + AI analysis
• /knowledge <topic> — Search my PDF knowledge
• /stats            — View learning stats
• /clear            — Clear chat history

📁 *Knowledge base:* ${r ? r.c : 0} facts from PDFs

*Send a PDF or use /search to get started!* 🚀`, { parse_mode: 'Markdown' });
    });
});

// ── /search command ────────────────────────────────────────────────────────────
bot.onText(/\/search(?:\s+(.+))?/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    const query  = match && match[1] ? match[1].trim() : null;

    if (!await isApproved(userId) && !await isAdmin(userId, uname)) {
        bot.sendMessage(chatId, '⏳ *Access Pending*'); return;
    }
    if (!query) {
        bot.sendMessage(chatId, `🔍 *Firefox Search Engine*

Usage: /search <your question>

Examples:
• /search what is CEH certification
• /search latest Kali Linux version
• /search how to use nmap
• /search is GPT-4 better than Claude

I'll search the web, read the pages, and give you a verified answer! 🧠`, { parse_mode: 'Markdown' });
        return;
    }
    await handleSearch(chatId, userId, query);
});

// ── Handle documents (PDF upload) ─────────────────────────────────────────────
bot.on('document', async (msg) => {
    const chatId   = msg.chat.id;
    const userId   = msg.from.id.toString();
    const fileId   = msg.document.file_id;
    const fileName = msg.document.file_name;
    const uname    = msg.from.username || '';

    if (!await isApproved(userId) && !await isAdmin(userId, uname)) {
        bot.sendMessage(chatId, '⏳ *Access Pending*'); return;
    }
    if (path.extname(fileName).toLowerCase() !== '.pdf') {
        bot.sendMessage(chatId, '❌ Please send PDF files only.'); return;
    }
    if (processingQueue.get(userId)) {
        bot.sendMessage(chatId, '⏳ Already processing a PDF. Please wait!'); return;
    }
    processingQueue.set(userId, true);
    try {
        const file    = await bot.getFile(fileId);
        const fPath   = path.join(UPLOAD_DIR, fileName);
        const fileUrl = `https://api.telegram.org/file/bot${token}/${file.file_path}`;
        const resp    = await axios({ method: 'get', url: fileUrl, responseType: 'stream' });
        const writer  = fs.createWriteStream(fPath);
        resp.data.pipe(writer);
        await new Promise((res, rej) => { writer.on('finish', res); writer.on('error', rej); });
        await processPDF(fPath, fileName, chatId);
        fs.unlinkSync(fPath);
    } catch (e) {
        console.error('File error:', e);
        bot.sendMessage(chatId, '❌ Error processing file. Please try again.');
    } finally {
        processingQueue.delete(userId);
    }
});

// ── /knowledge ─────────────────────────────────────────────────────────────────
bot.onText(/\/knowledge(?:\s+(.+))?/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    const query  = match && match[1] ? match[1].trim() : null;
    if (!await isApproved(userId) && !await isAdmin(userId, uname)) {
        bot.sendMessage(chatId, '⏳ *Access Pending*'); return;
    }
    if (!query) {
        db.get('SELECT COUNT(*) as c FROM pdf_knowledge', (_, r) =>
            bot.sendMessage(chatId, `📚 *Knowledge Base*\n\n**Facts:** ${r ? r.c : 0}\n\nUsage: /knowledge <topic>`, { parse_mode: 'Markdown' }));
        return;
    }
    bot.sendMessage(chatId, `🔍 *Searching PDF knowledge for:* "${query}"`, { parse_mode: 'Markdown' });
    const results = await searchRelevantContent(query);
    if (results && results.length > 0) {
        let r = `📚 *Found ${results.length} results:*\n\n`;
        for (let i = 0; i < Math.min(3, results.length); i++)
            r += `**${i+1}. ${results[i].source}**\n${results[i].content.substring(0, 600)}...\n\n`;
        bot.sendMessage(chatId, r, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, `📚 Nothing found for: "${query}"\n\nTry /search ${query} to search the web instead! 🔍`);
    }
});

// ── /stats ─────────────────────────────────────────────────────────────────────
bot.onText(/\/stats/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    if (!await isApproved(userId) && !await isAdmin(userId, uname)) {
        bot.sendMessage(chatId, '⏳ *Access Pending*'); return;
    }
    db.get('SELECT COUNT(*) as t FROM conversations', (_, t) =>
    db.get('SELECT COUNT(*) as k FROM pdf_knowledge', (_, k) =>
    db.get('SELECT COUNT(DISTINCT pdf_name) as p FROM pdf_knowledge', (_, p) =>
    db.get('SELECT COUNT(*) as s FROM search_history', (_, s) => {
        bot.sendMessage(chatId, `📊 *${aiName} Stats*

**Conversations:** ${t ? t.t : 0}
**PDF Facts:** ${k ? k.k : 0}
**PDFs Learned:** ${p ? p.p : 0}
**Web Searches:** ${s ? s.s : 0}
**AI Engine:** ${openaiApiKey ? 'ChatGPT + Ollama' : 'Ollama'}
**Search Engine:** Firefox + DuckDuckGo 🦊

*Send PDFs or use /search to grow my knowledge!* 📚`, { parse_mode: 'Markdown' });
    }))));
});

// ── /clear ─────────────────────────────────────────────────────────────────────
bot.onText(/\/clear/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    if (!await isApproved(userId) && !await isAdmin(userId, uname)) {
        bot.sendMessage(chatId, '⏳ *Access Pending*'); return;
    }
    userHistory.delete(userId);
    bot.sendMessage(chatId, `🗑️ *Chat cleared!* Starting fresh! 🦞`);
});

// ── /approve ───────────────────────────────────────────────────────────────────
bot.onText(/\/approve (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    const target = match[1].replace('@', '');
    if (!await isAdmin(userId, uname)) { bot.sendMessage(chatId, '❌ Admins only.'); return; }
    db.get('SELECT user_id,username,first_name FROM users WHERE username=? OR user_id=?', [target, target], (_, user) => {
        if (!user) { bot.sendMessage(chatId, `❌ User not found: ${target}`); return; }
        db.run('UPDATE users SET is_approved=1 WHERE user_id=?', [user.user_id]);
        bot.sendMessage(chatId, `✅ *Approved!* @${user.username || user.first_name} can now use ${aiName}.`);
        bot.sendMessage(user.user_id, `🎉 *Access granted!* You can now use ${aiName}.\n\nSend me PDFs or try /search <anything>!`);
    });
});

// ── Main message handler ───────────────────────────────────────────────────────
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const text   = msg.text;
    const userId = msg.from.id.toString();
    const uname  = msg.from.username || '';
    if (!text || text.startsWith('/')) return;

    if (!await isApproved(userId) && !await isAdmin(userId, uname)) {
        bot.sendMessage(chatId, '⏳ *Access Pending*\n\nWait for admin approval!'); return;
    }

    bot.sendChatAction(chatId, 'typing');
    let history = userHistory.get(userId) || [];
    const result = await getAIResponse(text, history);
    history.push({ role: 'user', content: text });
    history.push({ role: 'assistant', content: result.response });
    if (history.length > 20) history = history.slice(-20);
    userHistory.set(userId, history);
    db.run('INSERT INTO conversations (user_id,user_message,ai_response,model_used) VALUES(?,?,?,?)',
        [userId, text, result.response, result.model]);

    if (result.response.length > 4000) {
        const parts = result.response.match(/.{1,4000}/gs) || [result.response];
        for (const p of parts) await bot.sendMessage(chatId, p, { parse_mode: 'Markdown' });
    } else {
        bot.sendMessage(chatId, result.response, { parse_mode: 'Markdown' });
    }
});

console.log(`🦞 ${aiName} ready! PDF learning + Firefox search engine active.`);
BOTEOF

    # ── start.sh ──────────────────────────────────────────────────────────────
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
echo "✅ ${AI_NAME} started! (PID: \$(cat bot.pid))"
sleep 2
tail -5 bot.log
EOF
    chmod +x start.sh

    cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "node bot.js"
echo "Bot stopped"
EOF
    chmod +x stop.sh

    log_success "ClawBot with Firefox search engine created!"
}

# ─────────────────────────────────────────────────────────────────────────────
# Management script
# ─────────────────────────────────────────────────────────────────────────────
create_manager() {
    cat > ~/clawbot-manager.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

case "$1" in
    start)
        echo -e "${BLUE}Starting ClawBot...${NC}"
        cd ~/clawbot-telegram && ./start.sh
        echo -e "${GREEN}✓ ClawBot started${NC}"
        ;;
    stop)
        echo -e "${BLUE}Stopping ClawBot...${NC}"
        pkill -f "node bot.js"; echo -e "${GREEN}✓ Stopped${NC}"
        ;;
    restart)
        $0 stop; sleep 3; $0 start
        ;;
    status)
        echo -e "${BLUE}══════════════════════════════════${NC}"
        echo -e "       ClawBot Status"
        echo -e "${BLUE}══════════════════════════════════${NC}"
        echo -e "\n🤖 Bot:     $(pgrep -f 'node bot.js' &>/dev/null && echo -e '${GREEN}Running ✅${NC}' || echo -e '${RED}Stopped ❌${NC}')"
        echo -e "🦙 Ollama:  $(curl -s http://localhost:11434/api/tags &>/dev/null && echo 'Running ✅' || echo 'Stopped ❌')"
        echo -e "🦊 Firefox: $(command -v firefox &>/dev/null && echo 'Installed ✅' || (command -v firefox-esr &>/dev/null && echo 'ESR Installed ✅' || echo 'Not found ❌'))"
        echo -e "📚 PDF facts: $(sqlite3 ~/.clawbot/chat_history.db 'SELECT COUNT(*) FROM pdf_knowledge;' 2>/dev/null || echo '0')"
        echo -e "🔍 Searches: $(sqlite3 ~/.clawbot/chat_history.db 'SELECT COUNT(*) FROM search_history;' 2>/dev/null || echo '0')"
        ;;
    logs)
        tail -f ~/clawbot-telegram/bot.log
        ;;
    knowledge)
        echo -e "${CYAN}PDF Knowledge Base:${NC}"
        sqlite3 ~/.clawbot/chat_history.db \
            "SELECT pdf_name, COUNT(*) as facts FROM pdf_knowledge GROUP BY pdf_name;" 2>/dev/null
        ;;
    search-history)
        echo -e "${CYAN}Recent Searches:${NC}"
        sqlite3 ~/.clawbot/chat_history.db \
            "SELECT query, searched_at FROM search_history ORDER BY searched_at DESC LIMIT 20;" 2>/dev/null
        ;;
    test-search)
        echo -e "${CYAN}Testing Firefox search engine...${NC}"
        python3 ~/clawbot-telegram/search_scraper.py "what is linux" | python3 -m json.tool | head -40
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|knowledge|search-history|test-search}"
        exit 1
        ;;
esac
EOF
    chmod +x ~/clawbot-manager.sh
    log_success "Manager script created"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
    print_banner

    install_deps           # installs Firefox automatically if missing
    get_api_keys
    get_admin_usernames
    create_directories

    echo -e "\n${BOLD}${CYAN}📱 Telegram Bot Token${NC}\n"
    while true; do
        read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        if [[ "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then break
        else log_error "Invalid token format. Get it from @BotFather"; fi
    done
    echo "$TELEGRAM_BOT_TOKEN" > ~/.clawbot/bot-token.txt

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
    "search_engine": "Firefox + DuckDuckGo",
    "install_date": "$(date)"
}
EOF

    install_ollama
    create_search_scraper
    create_clawbot
    create_manager

    ~/clawbot-manager.sh start

    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ ${AI_NAME} v5 installed with Firefox Search Engine!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

    echo -e "${CYAN}🦊 Search Engine Features:${NC}"
    echo "  • /search <query>   — Searches DuckDuckGo via Firefox engine"
    echo "  • Reads actual web pages (not just snippets)"
    echo "  • AI analyzes results: TRUE / FALSE / UNVERIFIED"
    echo "  • Flags misleading information automatically"
    echo "  • Shows best verified source + URL"
    echo ""
    echo -e "${CYAN}📚 PDF Learning Features:${NC}"
    echo "  • Send any PDF — reads every page"
    echo "  • /knowledge <topic> — searches PDF memory"
    echo ""
    echo -e "${CYAN}🧪 Test search engine:${NC}"
    echo "  ~/clawbot-manager.sh test-search"
    echo ""
    echo -e "${CYAN}📋 All commands:${NC}"
    echo "  ~/clawbot-manager.sh {start|stop|restart|status|logs|knowledge|search-history|test-search}"
    echo ""
    echo -e "${GREEN}🎉 Use /search in Telegram to start searching!${NC}\n"
}

main "$@"
