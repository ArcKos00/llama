# Script to download Mistral 7B Instruct v0.3 Q4_K_M GGUF model
# PowerShell version

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModelsDir = Join-Path $ScriptDir "models"

# Output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "==============================================" "Cyan"
Write-ColorOutput "  Download Mistral 7B Instruct v0.3 Q4_K_M  " "Cyan"
Write-ColorOutput "==============================================" "Cyan"

# Model details
$ModelName = "mistral-7b-instruct-v0.3.Q4_K_M.gguf"
$ModelUrl = "https://huggingface.co/lmstudio-community/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3.Q4_K_M.gguf"
$ModelPath = Join-Path $ModelsDir $ModelName

# Check if model already exists
if (Test-Path $ModelPath) {
    Write-ColorOutput "[WARNING] Model already exists: $ModelPath" "Yellow"
    $response = Read-Host "Do you want to re-download it? (y/N)"
    if ($response -notmatch '^[Yy]$') {
        Write-ColorOutput "[OK] Using existing model" "Green"
        exit 0
    }
    Remove-Item $ModelPath -Force
}

# Create models directory if it doesn't exist
if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir | Out-Null
}

Write-ColorOutput "`n> Downloading $ModelName..." "Cyan"
Write-ColorOutput "> URL: $ModelUrl" "Cyan"
Write-ColorOutput "> Destination: $ModelPath" "Cyan"
Write-Host ""

try {
    # Use Invoke-WebRequest with progress bar
    Write-ColorOutput "Starting download (this may take several minutes)..." "Green"
    
    # Download with progress
    $ProgressPreference = 'Continue'
    Invoke-WebRequest -Uri $ModelUrl -OutFile $ModelPath -UseBasicParsing
    
    # Verify download
    if (Test-Path $ModelPath) {
        $fileSize = (Get-Item $ModelPath).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
        $fileSizeGB = [math]::Round($fileSize / 1GB, 2)
        
        Write-Host ""
        Write-ColorOutput "[OK] Model downloaded successfully!" "Green"
        Write-ColorOutput "[OK] File size: $fileSizeGB GB ($fileSizeMB MB)" "Green"
        Write-ColorOutput "[OK] Location: $ModelPath" "Green"
    } else {
        Write-ColorOutput "[ERROR] Download failed. File not found: $ModelPath" "Red"
        exit 1
    }
}
catch {
    Write-ColorOutput "[ERROR] Download failed: $_" "Red"
    exit 1
}

Write-Host ""
Write-ColorOutput "========================================" "Cyan"
Write-ColorOutput "Download complete!" "Green"
Write-ColorOutput "========================================" "Cyan"
