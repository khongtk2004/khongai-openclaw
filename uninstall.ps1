# KhongAI Uninstaller - Windows PowerShell Version

param(
    [string]$InstallDir = "$env:USERPROFILE\khongai",
    [switch]$KeepData,
    [switch]$KeepImage,
    [switch]$Force,
    [switch]$Help
)

$Image = "ghcr.io/khongtk2004/khongai-openclaw:latest"
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
    Write-Host "║            Docker Uninstaller by KhongAI                      ║" -ForegroundColor Cyan
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

function Confirm-Action {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )
    
    if ($Force) {
        return $true
    }
    
    if ($Default -eq "y") {
        $PromptText = "$Prompt [Y/n] "
    } else {
        $PromptText = "$Prompt [y/N] "
    }
    
    while ($true) {
        Write-Host $PromptText -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        if ([string]::IsNullOrEmpty($response)) {
            $response = $Default
        }
        
        switch -Regex ($response) {
            '^[Yy]' { return $true }
            '^[Nn]' { return $false }
            default { Write-Host "Please answer yes or no." }
        }
    }
}

if ($Help) {
    Write-Host "KhongAI Uninstaller - Windows"
    Write-Host ""
    Write-Host "Usage: uninstall.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR   Installation directory (default: ~\khongai)"
    Write-Host "  -KeepData         Keep configuration and workspace data"
    Write-Host "  -KeepImage        Keep Docker image"
    Write-Host "  -Force            Skip confirmation prompts"
    Write-Host "  -Help             Show this help message"
    return
}

Write-Banner

Write-Host "This will uninstall KhongAI from your system." -ForegroundColor Yellow
Write-Host ""

Write-Step "Stopping and removing containers..."

$ContainersRemoved = $false
try {
    $containers = docker ps -a --format "{{.Names}}" 2>$null
    
    if ($containers -match "khongai") {
        docker stop khongai 2>$null | Out-Null
        docker rm khongai 2>$null | Out-Null
        Write-Success "Removed khongai container"
        $ContainersRemoved = $true
    }
} catch {
    # Ignore errors
}

if (-not $ContainersRemoved) {
    Write-Warning "No KhongAI containers found"
}

$ConfigDir = "$env:USERPROFILE\.khongai"

if (-not $KeepData -and (Test-Path $ConfigDir)) {
    Write-Step "Data directories found at $ConfigDir"
    
    if (Confirm-Action "Remove configuration and workspace data? (This cannot be undone)") {
        Remove-Item -Path $ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Removed data directory: $ConfigDir"
    } else {
        Write-Warning "Keeping data directory: $ConfigDir"
    }
} elseif ($KeepData -and (Test-Path $ConfigDir)) {
    Write-Warning "Keeping data directory: $ConfigDir"
}

if (-not $KeepImage) {
    try {
        $images = docker images --format "{{.Repository}}:{{.Tag}}" 2>$null
        
        if ($images -match [regex]::Escape($Image)) {
            Write-Step "Docker image found: $Image"
            
            if (Confirm-Action "Remove Docker image? (You can re-download it later)") {
                try {
                    docker rmi $Image 2>$null | Out-Null
                    Write-Success "Removed Docker image"
                } catch {
                    Write-Warning "Could not remove image (may be in use)"
                }
            } else {
                Write-Warning "Keeping Docker image: $Image"
            }
        }
    } catch {
        Write-Warning "Could not check for Docker image"
    }
} else {
    Write-Warning "Keeping Docker image: $Image"
}

if (Test-Path $InstallDir) {
    Write-Step "Installation directory found at $InstallDir"
    
    if (Confirm-Action "Remove installation directory?") {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Removed installation directory: $InstallDir"
    } else {
        Write-Warning "Keeping installation directory: $InstallDir"
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║         KhongAI has been uninstalled successfully! 👋        ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "To reinstall KhongAI:" -ForegroundColor White
Write-Host "  irm https://raw.githubusercontent.com/khongtk2004/khongai-openclaw/main/install.ps1 | iex" -ForegroundColor Cyan

Write-Host ""
Write-Host "Thank you for using KhongAI! 🦙" -ForegroundColor Yellow
Write-Host ""