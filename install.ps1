# KhongAI Installer - Windows PowerShell Version
# One-command setup for KhongAI on Docker for Windows

param(
    [string]$InstallDir = "$env:USERPROFILE\khongai",
    [switch]$NoStart,
    [switch]$SkipOnboard,
    [switch]$PullOnly,
    [switch]$Help
)

$Image = "ghcr.io/khongtk2004/khongai-openclaw:latest"
$RepoUrl = "https://github.com/khongtk2004/khongai-openclaw"
$ComposeUrl = "https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/docker-compose.yml"

$ErrorActionPreference = "Stop"

function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║    _  __ _                                                    ║" -ForegroundColor Cyan
    Write-Host "║   | |/ /| |                                                   ║" -ForegroundColor Cyan
    Write-Host "║   | ' / | |   ___   __ _  _ __   _   _   ___   _ __           ║" -ForegroundColor Cyan
    Write-Host "║   |  <  | |  / _ \ / _\` || '_ \ | | | | / _ \ | '_ \          ║" -ForegroundColor Cyan
    Write-Host "║   | . \ | | |  __/| (_| || | | || |_| || (_) || | | |         ║" -ForegroundColor Cyan
    Write-Host "║   |_|\_\|_|  \___| \__,_||_| |_| \__,_| \___/ |_| |_|         ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║              OpenClaw + Telegram Bot Installer                ║" -ForegroundColor Cyan
    Write-Host "║                    by KhongAI                                 ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

if ($Help) {
    Write-Host "KhongAI Installer - Windows"
    Write-Host ""
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR   Installation directory (default: ~\khongai)"
    Write-Host "  -NoStart          Don't start the gateway after setup"
    Write-Host "  -SkipOnboard      Skip onboarding wizard"
    Write-Host "  -PullOnly         Only pull the image, don't set up"
    Write-Host "  -Help             Show this help message"
    return
}

Write-Banner

Write-Step "Checking prerequisites..."

if (Test-Command docker) {
    Write-Success "docker found"
} else {
    Write-Error "docker not found"
    Write-Host ""
    Write-Host "Docker is required but not installed." -ForegroundColor Red
    Write-Host "Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    return
}

$ComposeCmd = ""
if (docker compose version 2>$null) {
    Write-Success "Docker Compose found (plugin)"
    $ComposeCmd = "docker compose"
} elseif (Test-Command docker-compose) {
    Write-Success "Docker Compose found (standalone)"
    $ComposeCmd = "docker-compose"
} else {
    Write-Error "Docker Compose not found"
    exit 1
}

try {
    docker info 2>$null | Out-Null
    Write-Success "Docker is running"
} catch {
    Write-Error "Docker is not running"
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

if ($PullOnly) {
    Write-Step "Pulling KhongAI image..."
    docker pull $Image
    Write-Success "Image pulled successfully!"
    Write-Host ""
    Write-Host "Done! Run the installer again without -PullOnly to complete setup." -ForegroundColor Green
    exit 0
}

Write-Step "Setting up installation directory..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location $InstallDir
Write-Success "Created $InstallDir"

Write-Step "Downloading docker-compose.yml..."
Invoke-WebRequest -Uri $ComposeUrl -OutFile "docker-compose.yml"
Write-Success "Downloaded docker-compose.yml"

Write-Step "Creating data directories..."
$ConfigDir = "$env:USERPROFILE\.khongai"
$WorkspaceDir = "$env:USERPROFILE\.khongai\workspace"
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
Write-Success "Created $ConfigDir (config)"
Write-Success "Created $WorkspaceDir (workspace)"

Write-Step "Setting up environment..."
$BotToken = Read-Host -Prompt "Enter your Telegram Bot Token (from @BotFather)"
$AdminIds = Read-Host -Prompt "Enter admin usernames (comma-separated, e.g., @khongtk,@renyu4444)"
if ([string]::IsNullOrEmpty($AdminIds)) {
    $AdminIds = "@khongtk,@renyu4444"
}

@"
TELEGRAM_BOT_TOKEN=$BotToken
ADMIN_USER_IDS=$AdminIds
KHONGAI_VERSION=latest
"@ | Out-File -FilePath "$InstallDir\.env" -Encoding utf8
Write-Success "Environment configured"

Write-Step "Pulling KhongAI image..."
docker pull $Image
Write-Success "Image pulled successfully!"

Write-Step "Starting KhongAI gateway..."
$composeParts = $ComposeCmd -split " ", 2
if ($composeParts.Count -eq 2) {
    & $composeParts[0] $composeParts[1] up -d
} else {
    & $composeParts[0] up -d
}

Write-Host "Waiting for gateway to start" -NoNewline
for ($i = 0; $i -lt 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:18789/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host ""
            Write-Success "Gateway is running!"
            break
        }
    } catch {
        # Continue waiting
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║         🎉 KhongAI installed successfully! 🎉                ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "Quick reference:" -ForegroundColor White
Write-Host "  Dashboard:      http://localhost:18789" -ForegroundColor Cyan
Write-Host "  Config:         $ConfigDir" -ForegroundColor Cyan
Write-Host "  Workspace:      $WorkspaceDir" -ForegroundColor Cyan
Write-Host "  Install dir:    $InstallDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Telegram Bot Commands:" -ForegroundColor White
Write-Host "  /status    - Check system status" -ForegroundColor Cyan
Write-Host "  /model     - Change AI model" -ForegroundColor Cyan
Write-Host "  /restart   - Restart KhongAI" -ForegroundColor Cyan
Write-Host "  /help      - Show all commands" -ForegroundColor Cyan

Write-Host ""
Write-Host "Happy building with KhongAI! 🤖🦙" -ForegroundColor Yellow
Write-Host ""