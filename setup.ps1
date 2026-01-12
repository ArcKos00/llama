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

# Function to download and install Python 3.11
function Install-Python311 {
    Write-Step "Installing Python 3.11"
    
    $pythonVersion = "3.11.9"
    $pythonInstaller = "python-$pythonVersion-amd64.exe"
    $pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/$pythonInstaller"
    $installerPath = Join-Path $env:TEMP $pythonInstaller
    
    Write-Host "Downloading Python $pythonVersion..." -ForegroundColor Gray
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
        Write-Success "Downloaded Python installer"
    } catch {
        Write-Error-Custom "Failed to download Python: $_"
        Write-Host "Please download manually from: https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Installing Python $pythonVersion..." -ForegroundColor Gray
    Write-Host "This will take a few minutes..." -ForegroundColor Gray
    
    $installArgs = @(
        "/quiet",
        "InstallAllUsers=0",
        "PrependPath=1",
        "Include_test=0",
        "Include_pip=1",
        "Include_doc=0"
    )
    
    try {
        Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -NoNewWindow
        Write-Success "Python $pythonVersion installed"
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
        
        # Clean up
        Remove-Item $installerPath -Force
        
        # Wait a bit for PATH to update
        Start-Sleep -Seconds 3
        
        return $true
    } catch {
        Write-Error-Custom "Failed to install Python: $_"
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

# 1. Check Python 3.11
Write-Step "[1/8] Checking Python 3.11"

$pythonExe = "python"
$needInstall = $false

try {
    $pythonVersion = & python --version 2>&1 | Out-String
    
    # Check if Python 3.11.x
    if ($pythonVersion -match "Python 3\.11\.") {
        Write-Success "Python 3.11 found: $($pythonVersion.Trim())"
    } else {
        Write-Warning-Custom "Python found but not 3.11: $($pythonVersion.Trim())"
        $needInstall = $true
    }
} catch {
    Write-Warning-Custom "Python not found in PATH"
    $needInstall = $true
}

if ($needInstall) {
    $install = Read-Host "Install Python 3.11 automatically? (y/n)"
    if ($install -match "^[Yy]$") {
        Install-Python311
        
        # Verify installation
        try {
            $pythonVersion = & python --version 2>&1 | Out-String
            Write-Success "Python 3.11 installed: $($pythonVersion.Trim())"
        } catch {
            Write-Error-Custom "Python installation failed"
            exit 1
        }
    } else {
        Write-Error-Custom "Python 3.11 is required. Install manually from: https://www.python.org/downloads/"
        exit 1
    }
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

# Try with alternative mirrors if default fails
$pipMirrors = @(
    @{Name="Default (PyPI)"; Url=""},
    @{Name="Aliyun (China)"; Url="https://mirrors.aliyun.com/pypi/simple/"},
    @{Name="Tsinghua (China)"; Url="https://pypi.tuna.tsinghua.edu.cn/simple"}
)

$pipUpdated = $false
foreach ($mirror in $pipMirrors) {
    try {
        if ($mirror.Url -eq "") {
            Write-Host "Trying default PyPI..." -ForegroundColor Gray
            python -m pip install --upgrade pip --no-warn-script-location 2>$null
        } else {
            Write-Host "Trying $($mirror.Name) mirror..." -ForegroundColor Gray
            python -m pip install --upgrade pip -i $($mirror.Url) --no-warn-script-location 2>$null
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "pip updated (using $($mirror.Name))"
            $pipUpdated = $true
            # Save successful mirror for later use
            $script:successfulMirror = $mirror.Url
            break
        }
    } catch {
        continue
    }
}

if (-not $pipUpdated) {
    Write-Warning-Custom "Could not update pip, continuing with current version..."
    Write-Host ""
    Write-Host "NETWORK ISSUE DETECTED!" -ForegroundColor Red
    Write-Host "Python cannot connect to PyPI. Possible solutions:" -ForegroundColor Yellow
    Write-Host "1. Run as Administrator: .\fix_firewall.ps1" -ForegroundColor White
    Write-Host "2. Check Windows Firewall settings" -ForegroundColor White
    Write-Host "3. Temporarily disable antivirus" -ForegroundColor White
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -notmatch "^[Yy]$") {
        exit 1
    }
}

# 5. Install dependencies
Write-Step "[5/8] Installing dependencies from requirements.txt"
if (Test-Path "requirements.txt") {
    Write-Host "Installing packages... (this may take a while)" -ForegroundColor Gray
    
    # Use successful mirror if found, otherwise try alternatives
    $installSuccess = $false
    $mirrorsToTry = @()
    
    if ($script:successfulMirror) {
        $mirrorsToTry += @{Name="Previous successful"; Url=$script:successfulMirror}
    }
    $mirrorsToTry += @(
        @{Name="Default (PyPI)"; Url=""},
        @{Name="Aliyun (China)"; Url="https://mirrors.aliyun.com/pypi/simple/"},
        @{Name="Tsinghua (China)"; Url="https://pypi.tuna.tsinghua.edu.cn/simple"}
    )
    
    foreach ($mirror in $mirrorsToTry) {
        try {
            Write-Host "Trying $($mirror.Name) mirror..." -ForegroundColor Gray
            if ($mirror.Url -eq "") {
                python -m pip install -r requirements.txt --no-warn-script-location 2>&1 | Out-Null
            } else {
                python -m pip install -r requirements.txt -i $($mirror.Url) --no-warn-script-location 2>&1 | Out-Null
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Dependencies installed (using $($mirror.Name))"
                $script:successfulMirror = $mirror.Url
                $installSuccess = $true
                break
            }
        } catch {
            continue
        }
    }
    
    if (-not $installSuccess) {
        Write-Error-Custom "Failed to install dependencies"
        Write-Host ""
        Write-Host "SOLUTION: Run as Administrator: .\fix_firewall.ps1" -ForegroundColor Yellow
        Write-Host "Then run this script again" -ForegroundColor Yellow
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
                exit 0 -ForegroundColor Gray
    
    $installCmd = "llama-cpp-python[server]"
    $installSuccess = $false
    
    foreach ($mirror in $mirrorsToTry) {
        try {
            Write-Host "Trying $($mirror.Name) mirror..." -ForegroundColor Gray
            if ($mirror.Url -eq "") {
                python -m pip install $installCmd --upgrade --force-reinstall --no-cache-dir --no-warn-script-location 2>&1 | Out-Null
            } else {
                python -m pip install $installCmd --upgrade --force-reinstall --no-cache-dir -i $($mirror.Url) --no-warn-script-location 2>&1 | Out-Null
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "llama-cpp-python[server] installed with CUDA (using $($mirror.Name))"
                $installSuccess = $true
                break
            }
        } catch {
            continue
        }
    }
    
    if (-not $installSuccess) {
        Write-Warning-Custom "Failed to install with CUDA, trying CPU version..."
        $cudaAvailable = $false
    }
}

if (-not $cudaAvailable) {
    Write-Warning-Custom "Installing CPU version"
    Write-Host "Installing llama-cpp-python... (this may take a few minutes)" -ForegroundColor Gray
    
    $installCmd = "llama-cpp-python[server]"
    $installSuccess = $false
    
    foreach ($mirror in $mirrorsToTry) {
        try {
            Write-Host "Trying $($mirror.Name) mirror..." -ForegroundColor Gray
            if ($mirror.Url -eq "") {
                python -m pip install $installCmd --no-warn-script-location 2>&1 | Out-Null
            } else {
                python -m pip install $installCmd -i $($mirror.Url) --no-warn-script-location 2>&1 | Out-Null
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "llama-cpp-python[server] installed (CPU, using $($mirror.Name))"
                $installSuccess = $true
                break
            }
        } catch {
            continue
        }
    }
    
    if (-not $installSuccess) {
        Write-Error-Custom "Failed to install llama-cpp-python"
        Write-Host ""
        Write-Host "SOLUTION: Run as Administrator: .\fix_firewall.ps1" -ForegroundColor Yellow

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
