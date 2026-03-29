# KhongAI Installer for Windows PowerShell
# Run as Administrator

param(
    [string]$TelegramBotToken,
    [string]$TelegramUsername
)

# Colors
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$CYAN = "`e[36m"
$BOLD = "`e[1m"
$NC = "`e[0m"

# Configuration
$INSTALL_DIR = if ($env:KHONGAI_INSTALL_DIR) { $env:KHONGAI_INSTALL_DIR } else { "$HOME\khongai" }

function Print-Banner {
    Write-Host "${CYAN}"
    Write-Host "╔══════════════════════════════════════════════════════════════╗"
    Write-Host "║                                                              ║"
    Write-Host "║    _  __ _                                                    ║"
    Write-Host "║   | |/ /| |                                                   ║"
    Write-Host "║   | ' / | |   ___   __ _  _ __   _   _   ___   _ __           ║"
    Write-Host "║   |  <  | |  / _ \ / _\` || '_ \ | | | | / _ \ | '_ \          ║"
    Write-Host "║   | . \ | | |  __/| (_| || | | || |_| || (_) || | | |         ║"
    Write-Host "║   |_|\_\|_|  \___| \__,_||_| |_| \__,_| \___/ |_| |_|         ║"
    Write-Host "║                                                              ║"
    Write-Host "║              OpenClaw + Telegram Bot Installer                ║"
    Write-Host "║                    by KhongAI                                 ║"
    Write-Host "║                                                              ║"
    Write-Host "╚══════════════════════════════════════════════════════════════╝"
    Write-Host "${NC}"
}

function Log-Step { Write-Host "`n${BLUE}▶${NC} ${BOLD}$args${NC}" }
function Log-Success { Write-Host "${GREEN}✓${NC} $args" }
function Log-Error { Write-Host "${RED}✗${NC} $args" }
function Log-Info { Write-Host "${CYAN}ℹ${NC} $args" }

function Get-TelegramCredentials {
    Write-Host "`n${BOLD}${CYAN}📱 Telegram Bot Setup${NC}`n"
    
    # Get Bot Token
    while ($true) {
        if (-not $TelegramBotToken) {
            Write-Host "${YELLOW}Enter your Telegram Bot Token:${NC}"
            Write-Host "${BLUE}(Get it from @BotFather on Telegram)${NC}"
            $TelegramBotToken = Read-Host "➤"
        }
        
        if ([string]::IsNullOrWhiteSpace($TelegramBotToken)) {
            Log-Error "Bot Token cannot be empty!"
            $TelegramBotToken = $null
            continue
        }
        
        if ($TelegramBotToken -notmatch '^\d+:[A-Za-z0-9_-]+$') {
            Log-Error "Invalid token format! Should be like: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
            $TelegramBotToken = $null
            continue
        }
        
        Log-Success "Token format accepted"
        break
    }
    
    # Get Telegram Username
    if (-not $TelegramUsername) {
        Write-Host "`n${YELLOW}Enter your Telegram Username (optional):${NC}"
        Write-Host "${BLUE}(Without @ symbol - for notifications)${NC}"
        $TelegramUsername = Read-Host "➤"
    }
    
    if ($TelegramUsername) {
        $TelegramUsername = $TelegramUsername -replace '@', ''
        Log-Success "Username: @$TelegramUsername"
    } else {
        Log-Info "No username provided (optional)"
    }
    
    # Save credentials
    $credPath = "$env:USERPROFILE\.khongai"
    New-Item -ItemType Directory -Force -Path $credPath | Out-Null
    @"
TELEGRAM_BOT_TOKEN=$TelegramBotToken
TELEGRAM_USERNAME=$TelegramUsername
INSTALL_DATE=$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Out-File -FilePath "$credPath\credentials.txt" -Encoding UTF8
    
    Write-Host "`n${GREEN}✓ Telegram credentials saved${NC}"
    
    return @{
        Token = $TelegramBotToken
        Username = $TelegramUsername
    }
}

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "${RED}This script must be run as Administrator!${NC}" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
    pause
    exit 1
}

Print-Banner

# Get credentials
$creds = Get-TelegramCredentials

Log-Step "Creating directories..."
New-Item -ItemType Directory -Force -Path "$INSTALL_DIR" | Out-Null
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.khongai\workspace" | Out-Null
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.khongai\logs" | Out-Null

Log-Step "Checking Docker..."
$dockerPath = (Get-Command docker -ErrorAction SilentlyContinue)
if (-not $dockerPath) {
    Log-Error "Docker not installed. Please install Docker Desktop for Windows from:"
    Write-Host "${YELLOW}https://docs.docker.com/desktop/install/windows-install/${NC}"
    Write-Host "`nAfter installing Docker Desktop, please run this script again."
    pause
    exit 1
}
Log-Success "Docker found"

Log-Step "Pulling OpenClaw image..."
docker pull ghcr.io/openclaw/openclaw:latest

Log-Step "Creating docker-compose.yml..."
Set-Location "$INSTALL_DIR"
@"
version: '3.8'

services:
  khongai:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: khongai
    restart: unless-stopped
    volumes:
      - $env:USERPROFILE/.khongai:/home/node/.openclaw
      - $env:USERPROFILE/.khongai/workspace:/home/node/.openclaw/workspace
    ports:
      - "18789:18789"
    environment:
      - NODE_ENV=production
    command: ["gateway", "start", "--foreground"]
"@ | Out-File -FilePath "docker-compose.yml" -Encoding UTF8

Log-Step "Starting KhongAI..."
docker-compose up -d

Start-Sleep -Seconds 5
$containerStatus = docker ps --filter "name=khongai" --format "table {{.Names}}"
if ($containerStatus -like "*khongai*") {
    Log-Success "KhongAI is running!"
} else {
    Log-Error "Failed to start KhongAI"
    docker logs khongai
    exit 1
}

Log-Step "Setting up Telegram bot..."
$botDir = "$env:USERPROFILE\khongai-telegram-bot"
New-Item -ItemType Directory -Force -Path $botDir | Out-Null
Set-Location $botDir

# Create package.json
@"
{
  "name": "khongai-telegram-bot",
  "version": "1.0.0",
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "axios": "^1.6.0"
  }
}
"@ | Out-File -FilePath "package.json" -Encoding UTF8

# Install dependencies
Log-Info "Installing Node.js dependencies..."
if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm install --silent
} else {
    Log-Error "Node.js not found. Please install Node.js from https://nodejs.org/"
    pause
    exit 1
}

# Create bot.js
$botToken = $creds.Token
$botUsername = $creds.Username
@"
const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

const token = '$botToken';
const bot = new TelegramBot(token, { polling: true });
const KHONGAI_URL = 'http://localhost:18789';
const ADMIN_USERNAME = '$botUsername';

console.log('🤖 KhongAI Telegram Bot Starting...');
console.log('📱 Bot Token: ' + token.substring(0, 10) + '...');

bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const welcomeMessage = `
🦙 *Welcome to KhongAI!* 🦙

Your AI assistant is ready to help.

*Available Commands:*
/status - Check KhongAI server status
/health - Detailed health check
/info - Bot information
/help - Show this help message

*About:*
🤖 KhongAI v1.0
💡 OpenClaw Gateway
📡 Telegram Integration
    `;
    bot.sendMessage(chatId, welcomeMessage, { parse_mode: 'Markdown' });
});

bot.onText(/\/status/, async (msg) => {
    const chatId = msg.chat.id;
    try {
        const response = await axios.get(`\${KHONGAI_URL}/health`, { timeout: 5000 });
        if (response.status === 200) {
            bot.sendMessage(chatId, '✅ *KhongAI is running!*', { parse_mode: 'Markdown' });
        }
    } catch (error) {
        bot.sendMessage(chatId, '❌ *Cannot connect to KhongAI*', { parse_mode: 'Markdown' });
    }
});

bot.onText(/\/health/, async (msg) => {
    const chatId = msg.chat.id;
    try {
        const response = await axios.get(`\${KHONGAI_URL}/health`, { timeout: 5000 });
        const healthMessage = `
✅ *KhongAI Health Check*

Status: Healthy
HTTP Code: ${response.status}
        `;
        bot.sendMessage(chatId, healthMessage, { parse_mode: 'Markdown' });
    } catch (error) {
        bot.sendMessage(chatId, '❌ *KhongAI Unreachable*', { parse_mode: 'Markdown' });
    }
});

bot.onText(/\/info/, (msg) => {
    const chatId = msg.chat.id;
    const infoMessage = `
📊 *KhongAI Information*

*Server:* ${KHONGAI_URL}
*Admin:* @${ADMIN_USERNAME || 'Not configured'}
*Commands:* /start, /status, /health, /info
    `;
    bot.sendMessage(chatId, infoMessage, { parse_mode: 'Markdown' });
});

bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    bot.sendMessage(chatId, 'Send /start to see available commands');
});

console.log('🚀 Bot is polling for messages...');
"@ | Out-File -FilePath "bot.js" -Encoding UTF8

# Create start script
@"
@echo off
cd /d $botDir
start /B node bot.js > bot.log 2>&1
echo Bot started
"@ | Out-File -FilePath "start-bot.bat" -Encoding ASCII

# Create stop script
@"
@echo off
taskkill /F /IM node.exe /FI "WINDOWTITLE eq bot.js"
echo Bot stopped
"@ | Out-File -FilePath "stop-bot.bat" -Encoding ASCII

# Start the bot
Log-Step "Starting Telegram bot..."
Set-Location $botDir
$botProcess = Start-Process -NoNewWindow -FilePath "node" -ArgumentList "bot.js" -RedirectStandardOutput "bot.log" -RedirectStandardError "bot-error.log" -PassThru
$botProcess.Id | Out-File -FilePath "bot.pid"

Start-Sleep -Seconds 3
if (Get-Process -Id $botProcess.Id -ErrorAction SilentlyContinue) {
    Log-Success "Telegram bot started (PID: $($botProcess.Id))"
} else {
    Log-Error "Failed to start bot. Check bot.log"
    Get-Content "bot.log" -Tail 20
}

# Create management script
@"
@echo off
setlocal enabledelayedexpansion

if "%1"=="" (
    echo Usage: $0 {start^|stop^|restart^|status^|logs^|bot-logs}
    exit /b 1
)

if "%1"=="start" (
    echo Starting KhongAI...
    cd /d $INSTALL_DIR
    docker-compose up -d
    cd /d $botDir
    start /B node bot.js > bot.log 2>&1
    echo Started
)
if "%1"=="stop" (
    echo Stopping KhongAI...
    cd /d $INSTALL_DIR
    docker-compose down
    taskkill /F /IM node.exe /FI "WINDOWTITLE eq bot.js"
    echo Stopped
)
if "%1"=="restart" (
    call %0 stop
    timeout /t 3 /nobreak >nul
    call %0 start
)
if "%1"=="status" (
    echo KhongAI Status:
    docker ps --filter "name=khongai"
    echo.
    echo Bot Status:
    tasklist /FI "IMAGENAME eq node.exe" 2>nul | find "node.exe" >nul && echo Bot running || echo Bot not running
)
if "%1"=="logs" (
    docker logs khongai --tail 50
)
if "%1"=="bot-logs" (
    type $botDir\bot.log
)
"@ | Out-File -FilePath "$env:USERPROFILE\khongai-manager.bat" -Encoding ASCII

# Final output
Write-Host "`n${GREEN}════════════════════════════════════════════════════════════════${NC}"
Write-Host "${GREEN}✅ KhongAI installed successfully!${NC}"
Write-Host "${GREEN}════════════════════════════════════════════════════════════════${NC}`n"

Write-Host "${CYAN}📊 Dashboard:${NC} http://localhost:18789"
Write-Host "${CYAN}🤖 Telegram Bot:${NC} Send /start to your bot"
Write-Host "${CYAN}👤 Admin Username:${NC} @$($creds.Username)`n"

Write-Host "${BOLD}📝 Management Commands:${NC}"
Write-Host "  ${YELLOW}khongai-manager.bat status${NC}     - Check status"
Write-Host "  ${YELLOW}khongai-manager.bat restart${NC}    - Restart everything"
Write-Host "  ${YELLOW}khongai-manager.bat logs${NC}       - View KhongAI logs"
Write-Host "  ${YELLOW}khongai-manager.bat bot-logs${NC}   - View bot logs`n"

Write-Host "${GREEN}🎉 Installation complete! Send /start to your Telegram bot to begin.${NC}`n"

# Test connection
Start-Sleep -Seconds 2
try {
    $response = Invoke-WebRequest -Uri "http://localhost:18789/health" -UseBasicParsing -TimeoutSec 5
    Log-Success "KhongAI is responding!"
} catch {
    Log-Error "KhongAI not responding. Check with: docker logs khongai"
}

pause
