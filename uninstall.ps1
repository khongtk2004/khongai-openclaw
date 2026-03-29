# KhongAI Uninstaller for Windows PowerShell
# Run as Administrator

$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$CYAN = "`e[36m"
$BOLD = "`e[1m"
$NC = "`e[0m"

function Print-Banner {
    Write-Host "${RED}"
    Write-Host "╔══════════════════════════════════════════════════════════════╗"
    Write-Host "║                                                              ║"
    Write-Host "║                 KhongAI Uninstaller                           ║"
    Write-Host "║                                                              ║"
    Write-Host "╚══════════════════════════════════════════════════════════════╝"
    Write-Host "${NC}"
}

function Log-Step { Write-Host "`n${BLUE}▶${NC} ${BOLD}$args${NC}" }
function Log-Success { Write-Host "${GREEN}✓${NC} $args" }
function Log-Error { Write-Host "${RED}✗${NC} $args" }
function Log-Warning { Write-Host "${YELLOW}⚠${NC} $args" }
function Log-Info { Write-Host "${CYAN}ℹ${NC} $args" }

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "${RED}This script must be run as Administrator!${NC}"
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
    pause
    exit 1
}

Print-Banner

# Confirmation
Write-Host "`n${RED}${BOLD}WARNING: This will completely remove KhongAI and all data!${NC}"
Write-Host "${YELLOW}This includes:${NC}"
Write-Host "  - Docker containers and images"
Write-Host "  - Configuration files"
Write-Host "  - Telegram bot files"
Write-Host "  - Workspace data"
Write-Host "  - Logs"
Write-Host ""
$confirm = Read-Host "Are you sure you want to continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Uninstall cancelled."
    exit 0
}

# Stop and remove Docker container
Log-Step "Stopping and removing Docker container..."
$containerExists = docker ps -a --filter "name=khongai" --format "table {{.Names}}" | Select-String "khongai"
if ($containerExists) {
    docker stop khongai 2>$null
    docker rm khongai 2>$null
    Log-Success "Docker container removed"
} else {
    Log-Info "No Docker container found"
}

# Remove Docker image
$removeImage = Read-Host "Remove OpenClaw Docker image as well? (yes/no)"
if ($removeImage -eq "yes") {
    Log-Step "Removing Docker image..."
    docker rmi ghcr.io/openclaw/openclaw:latest 2>$null
    Log-Success "Docker image removed"
}

# Stop Telegram bot
Log-Step "Stopping Telegram bot..."
Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.StartInfo.Arguments -like "*bot.js*" } | Stop-Process -Force
taskkill /F /IM node.exe 2>$null
Log-Success "Bot stopped"

# Remove installation directories
Log-Step "Removing installation directories..."

# KhongAI main directory
$khongaiDir = "$env:USERPROFILE\khongai"
if (Test-Path $khongaiDir) {
    Remove-Item -Recurse -Force $khongaiDir -ErrorAction SilentlyContinue
    Log-Success "Removed $khongaiDir"
}

# KhongAI data directory
$khongaiDataDir = "$env:USERPROFILE\.khongai"
if (Test-Path $khongaiDataDir) {
    Remove-Item -Recurse -Force $khongaiDataDir -ErrorAction SilentlyContinue
    Log-Success "Removed $khongaiDataDir"
}

# Telegram bot directory
$botDir = "$env:USERPROFILE\khongai-telegram-bot"
if (Test-Path $botDir) {
    Remove-Item -Recurse -Force $botDir -ErrorAction SilentlyContinue
    Log-Success "Removed $botDir"
}

# Remove management script
$managerScript = "$env:USERPROFILE\khongai-manager.bat"
if (Test-Path $managerScript) {
    Remove-Item -Force $managerScript -ErrorAction SilentlyContinue
    Log-Success "Removed management script"
}

# Remove docker-compose file
$composeFile = "$env:USERPROFILE\khongai\docker-compose.yml"
if (Test-Path $composeFile) {
    Remove-Item -Force $composeFile -ErrorAction SilentlyContinue
}

# Clean up Docker volumes (optional)
$removeVolumes = Read-Host "Remove Docker volumes as well? (yes/no)"
if ($removeVolumes -eq "yes") {
    Log-Step "Removing Docker volumes..."
    docker volume prune -f 2>$null
    Log-Success "Docker volumes cleaned"
}

# Final output
Write-Host "`n${GREEN}════════════════════════════════════════════════════════════════${NC}"
Write-Host "${GREEN}✅ KhongAI has been successfully uninstalled!${NC}"
Write-Host "${GREEN}════════════════════════════════════════════════════════════════${NC}`n"

Write-Host "${YELLOW}Note: The following items were NOT removed:${NC}"
Write-Host "  - Node.js (if installed separately)"
Write-Host "  - Docker Desktop (if installed separately)"
Write-Host "  - npm packages (system-wide)"
Write-Host ""
Write-Host "${CYAN}To manually remove Docker Desktop:${NC}"
Write-Host "  - Go to 'Add or Remove Programs'"
Write-Host "  - Find 'Docker Desktop' and uninstall"
Write-Host ""
Write-Host "${CYAN}To manually remove Node.js:${NC}"
Write-Host "  - Go to 'Add or Remove Programs'"
Write-Host "  - Find 'Node.js' and uninstall"
Write-Host ""

Log-Success "Uninstall complete!"
pause
