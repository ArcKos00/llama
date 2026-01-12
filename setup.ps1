# LLM Proxy Server - Complete Setup Script
# PowerShell version

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[OK] $Message" "Green"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

Write-ColorOutput "========================================" "Cyan"
Write-ColorOutput "  LLM Proxy Server - Setup Environment  " "Cyan"
Write-ColorOutput "========================================" "Cyan"

# 1. Check Python
Write-Step "[1/8] Checking Python"
try {
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python not found"
    }
    Write-Success "Python found: $pythonVersion"
} catch {
    Write-Error-Custom "Python not found. Install Python 3.8 or newer"
    exit 1
}

# 2. Check pip
Write-Step "[2/8] Checking pip"
try {
    $pipVersion = python -m pip --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "pip not found"
    }
    Write-Success "pip found: $pipVersion"
} catch {
    Write-Error-Custom "pip not found. Install pip"
    exit 1
}

# 3. Create virtual environment (optional)
Write-Step "[3/8] Virtual environment"
if (Test-Path "venv") {
    Write-Warning-Custom "Virtual environment already exists, skipping"
} else {
    $response = Read-Host "Create virtual environment? (y/n)"
    if ($response -match "^[Yy]$") {
        python -m venv venv
        Write-Success "Virtual environment created"
        Write-Warning-Custom "To activate: .\venv\Scripts\Activate.ps1"
    } else {
        Write-Warning-Custom "Virtual environment not created"
    }
}

# 4. Update pip
Write-Step "[4/8] Updating pip"
try {
    python -m pip install --upgrade pip --no-warn-script-location 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "pip updated"
    } else {
        Write-Warning-Custom "Could not update pip (network issue?), continuing..."
    }
} catch {
    Write-Warning-Custom "Could not update pip, continuing with current version..."
}

# 5. Install dependencies
Write-Step "[5/8] Installing dependencies from requirements.txt"
if (Test-Path "requirements.txt") {
    Write-Host "Installing packages... (this may take a while)"
    try {
        python -m pip install -r requirements.txt --no-warn-script-location
        Write-Success "Dependencies installed"
    } catch {
        Write-Error-Custom "Failed to install dependencies. Check your internet connection"
        Write-Host "You can try running: python -m pip install -r requirements.txt"
        exit 1
    }
} else {
    Write-Error-Custom "requirements.txt not found"
    exit 1
}

# 6. Check and install CUDA
Write-Step "[6/8] Checking CUDA"
$cudaAvailable = $false
try {
    $nvccVersion = nvcc --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $cudaAvailable = $true
        Write-Success "CUDA already installed"
    }
} catch {
    $cudaAvailable = $false
}

if (-not $cudaAvailable) {
    Write-Warning-Custom "CUDA not found"
    
    # Check for NVIDIA GPU
    $hasNvidiaGPU = $false
    try {
        $gpuInfo = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
        if ($gpuInfo) {
            $hasNvidiaGPU = $true
            Write-Warning-Custom "Found NVIDIA GPU: $($gpuInfo.Name)"
        }
    } catch {
        Write-Warning-Custom "Could not detect NVIDIA GPU"
    }
    
    if ($hasNvidiaGPU) {
        Write-Host ""
        Write-Warning-Custom "CUDA Toolkit recommended for best performance"
        $installCuda = Read-Host "Install CUDA Toolkit 12.x? (y/n)"
        
        if ($installCuda -match "^[Yy]$") {
            Write-Warning-Custom "Downloading CUDA Toolkit..."
            Write-Warning-Custom "This may take 10-20 minutes"
            
            $cudaInstallerUrl = "https://developer.download.nvidia.com/compute/cuda/12.6.0/network_installers/cuda_12.6.0_windows_network.exe"
            $cudaInstaller = "$env:TEMP\cuda_installer.exe"
            
            try {
                Write-Host "Downloading from $cudaInstallerUrl..."
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($cudaInstallerUrl, $cudaInstaller)
                
                Write-Success "Download complete"
                Write-Warning-Custom "Running CUDA installer..."
                Write-Warning-Custom "Select 'Custom' and install: CUDA Toolkit, CUDA Runtime"
                
                Start-Process -FilePath $cudaInstaller -Wait
                
                Write-Success "CUDA installation complete"
                Write-Warning-Custom "RESTART PowerShell to apply PATH changes"
                Write-Warning-Custom "Then run setup.ps1 again"
                
                Remove-Item $cudaInstaller -ErrorAction SilentlyContinue
                
                Read-Host "Press Enter to exit"
                exit 0
                
            } catch {
                Write-Error-Custom "Error downloading/installing CUDA: $_"
                Write-Warning-Custom "Download and install CUDA manually:"
                Write-Warning-Custom "https://developer.nvidia.com/cuda-downloads"
            }
        } else {
            Write-Warning-Custom "Continuing without CUDA (CPU will be used)"
        }
    } else {
        Write-Warning-Custom "NVIDIA GPU not found, CPU version will be used"
    }
}

# 7. Install llama-cpp-python[server]
Write-Step "[7/8] Installing llama-cpp-python[server]"
Write-Warning-Custom "This may take several minutes..."

# Re-check CUDA after possible installation
$cudaAvailable = $false
try {
    $nvccVersion = nvcc --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $cudaAvailable = $true
    }
} catch {
    $cudaAvailable = $false
}

if ($cudaAvailable) {
    Write-Success "CUDA available, installing with GPU support"
    $env:CMAKE_ARGS = "-DLLAMA_CUBLAS=on"
    Write-Host "Building with CUDA support... (this will take 5-10 minutes)"
    try {
        python -m pip install llama-cpp-python[server] --upgrade --force-reinstall --no-cache-dir --no-warn-script-location
        Write-Success "llama-cpp-python[server] installed with CUDA"
    } catch {
        Write-Error-Custom "Failed to install llama-cpp-python with CUDA"
        Write-Host "Trying CPU version instead..."
        python -m pip install "llama-cpp-python[server]" --no-warn-script-location
    }
} else {
    Write-Warning-Custom "Installing CPU version"
    Write-Host "Installing llama-cpp-python... (this may take a few minutes)"
    try {
        python -m pip install "llama-cpp-python[server]" --no-warn-script-location
        Write-Success "llama-cpp-python[server] installed (CPU)"
    } catch {
        Write-Error-Custom "Failed to install llama-cpp-python"
        Write-Host "Check your internet connection and try again"
        exit 1
    }
}

# 8. Check PowerShell scripts
Write-Step "[8/8] Checking PowerShell scripts"
$scripts = @("start.ps1", "stop.ps1")
foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Success "$script - found"
    } else {
        Write-Warning-Custom "$script - not found"
    }
}

# Check models
Write-Host ""
Write-Step "Checking models"
$modelsDir = ".\models"
if (-not (Test-Path $modelsDir)) {
    Write-Warning-Custom "models\ directory not found, creating..."
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
}

$models = Get-ChildItem -Path $modelsDir -Filter "*.gguf" -File -ErrorAction SilentlyContinue
$modelCount = $models.Count

if ($modelCount -eq 0) {
    Write-Warning-Custom ".gguf models not found in $modelsDir\"
    Write-Warning-Custom "Download GGUF models to models\ directory"
    Write-Warning-Custom "For example from: https://huggingface.co/"
} else {
    Write-Success "Found $modelCount model(s)"
    foreach ($model in $models) {
        Write-Host "  - $($model.Name)" -ForegroundColor Green
    }
}

# Check configuration
Write-Host ""
Write-Step "Checking configuration"
if (Test-Path "config.json") {
    try {
        $config = Get-Content "config.json" | ConvertFrom-Json
        $modelPath = $config.model.path
        
        if ($modelPath -match "^/") {
            # Unix path
            if (Test-Path $modelPath) {
                Write-Success "Model in config.json exists: $(Split-Path -Leaf $modelPath)"
            } else {
                Write-Warning-Custom "Model in config.json not found: $modelPath"
                Write-Warning-Custom "Update model path in config.json"
            }
        } else {
            # Windows path
            if (Test-Path $modelPath) {
                Write-Success "Model in config.json exists: $(Split-Path -Leaf $modelPath)"
            } else {
                Write-Warning-Custom "Model in config.json not found: $modelPath"
                Write-Warning-Custom "Update model path in config.json"
            }
        }
    } catch {
        Write-Warning-Custom "Error reading config.json"
    }
} else {
    Write-Error-Custom "config.json not found"
}

# Summary
Write-Host ""
Write-ColorOutput "========================================" "Cyan"
Write-ColorOutput "       Setup Complete!                  " "Cyan"
Write-ColorOutput "========================================" "Cyan"
Write-Host ""
Write-Success "All dependencies installed"
Write-Success "Environment ready to use"
Write-Host ""
Write-Warning-Custom "Next steps:"
Write-Host "  1. Make sure model exists in models\ directory"
Write-Host "  2. Check config.json (model path)"
Write-ColorOutput "  3. Start server: " "White" -NoNewline
Write-ColorOutput ".\start.ps1" "Green"
Write-Host ""
Write-ColorOutput "Documentation: README.md" "Cyan"
Write-Host ""
