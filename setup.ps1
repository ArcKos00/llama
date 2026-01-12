# LLM Proxy Server - Windows Setup Script (PowerShell)
# Port of setup.sh for Windows

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Helper functions
function Write-Step { param([string]$msg) Write-Host "`n> $msg" -ForegroundColor Cyan }
function Write-OK { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Warn { param([string]$msg) Write-Host "[!] $msg" -ForegroundColor Yellow }

Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "  LLM Proxy Server - Windows Setup (Native)" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Running in Windows PowerShell`n" -ForegroundColor Green

# [1/8] Check Python 3.11
Write-Step "[1/8] Checking Python 3.11"
$pythonCmd = $null
$needInstall = $false

try {
    $pyVer = python --version 2>&1 | Out-String
    if ($pyVer -match "Python 3\.11\.") {
        $pythonCmd = "python"
        Write-OK "Python 3.11 found: $($pyVer.Trim())"
    } else {
        Write-Warn "Python found but not 3.11: $($pyVer.Trim())"
        $needInstall = $true
    }
} catch {
    Write-Warn "Python not found"
    $needInstall = $true
}

if ($needInstall) {
    $install = Read-Host "Install Python 3.11 automatically? (y/n)"
    if ($install -match "^[Yy]$") {
        Write-Host "Downloading Python 3.11.9..." -ForegroundColor Gray
        $pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
        $installerPath = "$env:TEMP\python-3.11.9-amd64.exe"
        
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
            Write-OK "Downloaded installer"
            
            Write-Host "Installing Python..." -ForegroundColor Gray
            Start-Process -FilePath $installerPath -ArgumentList "/quiet","InstallAllUsers=0","PrependPath=1","Include_pip=1" -Wait -NoNewWindow
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
            Start-Sleep -Seconds 2
            
            $pyVer = python --version 2>&1 | Out-String
            Write-OK "Python installed: $($pyVer.Trim())"
            $pythonCmd = "python"
            Remove-Item $installerPath -Force
        } catch {
            Write-Err "Failed to install Python: $_"
            Write-Host "Install manually from: https://www.python.org/downloads/" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Err "Python 3.11 is required"
        Write-Host "Install from: https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
}

# [2/8] Check pip
Write-Step "[2/8] Checking pip"
try {
    $pipVer = python -m pip --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-OK "pip found: $pipVer"
    } else {
        throw "pip not found"
    }
} catch {
    Write-Err "pip not found"
    exit 1
}

# [3/8] Virtual environment (optional)
Write-Step "[3/8] Virtual environment"
if (Test-Path "venv") {
    Write-Warn "Virtual environment already exists"
} else {
    $createVenv = Read-Host "Create virtual environment? (y/n)"
    if ($createVenv -match "^[Yy]$") {
        python -m venv venv
        Write-OK "Virtual environment created"
        Write-Warn "To activate: .\venv\Scripts\Activate.ps1"
    } else {
        Write-Warn "Continuing without virtual environment"
    }
}

# [4/8] Update pip
Write-Step "[4/8] Updating pip"
$mirrors = @(
    @{Name="Default (PyPI)"; Url=""},
    @{Name="Aliyun (China)"; Url="https://mirrors.aliyun.com/pypi/simple/"},
    @{Name="Tsinghua (China)"; Url="https://pypi.tuna.tsinghua.edu.cn/simple/"}
)

$pipUpdated = $false
$successfulMirror = ""

foreach ($mirror in $mirrors) {
    try {
        if ($mirror.Url -eq "") {
            Write-Host "Trying default PyPI..." -ForegroundColor Gray
            python -m pip install --upgrade pip --quiet 2>$null
        } else {
            Write-Host "Trying $($mirror.Name)..." -ForegroundColor Gray
            python -m pip install --upgrade pip -i $mirror.Url --quiet 2>$null
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-OK "pip updated (using $($mirror.Name))"
            $pipUpdated = $true
            $successfulMirror = $mirror.Url
            break
        }
    } catch {
        continue
    }
}

if (-not $pipUpdated) {
    Write-Warn "Could not update pip, continuing..."
}

# [5/8] Install basic dependencies
Write-Step "[5/8] Installing basic dependencies"
if (Test-Path "requirements.txt") {
    Write-Host "Installing packages from requirements.txt..." -ForegroundColor Gray
    
    $installSuccess = $false
    foreach ($mirror in $mirrors) {
        try {
            if ($mirror.Url -eq "") {
                Write-Host "Trying default PyPI..." -ForegroundColor Gray
                python -m pip install -r requirements.txt --quiet
            } else {
                Write-Host "Trying $($mirror.Name)..." -ForegroundColor Gray
                python -m pip install -r requirements.txt -i $mirror.Url --quiet
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Basic dependencies installed"
                $installSuccess = $true
                break
            }
        } catch {
            continue
        }
    }
    
    if (-not $installSuccess) {
        Write-Err "Failed to install basic dependencies"
        Write-Host "Try: python -m pip install -r requirements.txt" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Err "requirements.txt not found"
    exit 1
}

# [6/8] Install llama-cpp-python
Write-Step "[6/8] Installing llama-cpp-python (latest version)"

# Ask user about CUDA support
$wantCuda = Read-Host "Enable CUDA GPU support? (y/n)"

# Check for CUDA
$cudaAvailable = $false
$cudaPath = $null

if ($wantCuda -match "^[Yy]$") {
    # First, try to find nvcc location
    $nvccPath = (Get-Command nvcc -ErrorAction SilentlyContinue).Source
    
    if (-not $nvccPath) {
        Write-Warn "nvcc not found in PATH - CUDA not installed"
        $installCuda = Read-Host "Install CUDA Toolkit automatically? (~3 GB) (y/n)"
        
        if ($installCuda -match "^[Yy]$") {
            Write-Host "Downloading CUDA Toolkit 12.6..." -ForegroundColor Yellow
            $cudaUrl = "https://developer.download.nvidia.com/compute/cuda/12.6.0/network_installers/cuda_12.6.0_windows_network.exe"
            $cudaInstaller = "$env:TEMP\cuda_12.6.0_installer.exe"
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $cudaUrl -OutFile $cudaInstaller -UseBasicParsing
                Write-OK "Downloaded CUDA installer"
                
                Write-Host "Starting CUDA Toolkit installer..." -ForegroundColor Yellow
                Write-Host "Please follow the installation wizard instructions." -ForegroundColor Yellow
                Write-Host "Recommended: Select 'Custom' and install all components." -ForegroundColor Yellow
                Write-Host "" -ForegroundColor Yellow
                
                $cudaProcess = Start-Process -FilePath $cudaInstaller -Wait -PassThru
                
                if ($cudaProcess.ExitCode -eq 0) {
                    Write-OK "CUDA Toolkit installed successfully"
                    Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
                    
                    Write-Host "Refreshing environment variables..." -ForegroundColor Gray
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
                    Start-Sleep -Seconds 3
                    
                    # Retry detection
                    $nvccPath = (Get-Command nvcc -ErrorAction SilentlyContinue).Source
                    if ($nvccPath) {
                        Write-OK "nvcc now available in PATH"
                    } else {
                        Write-Warn "CUDA installed but nvcc still not in PATH"
                        Write-Host "You need to restart PowerShell or your computer" -ForegroundColor Yellow
                        Write-Host "Then run setup.ps1 again" -ForegroundColor Yellow
                        exit 0
                    }
                } else {
                    Write-Err "CUDA installation failed (exit code: $($cudaProcess.ExitCode))"
                    Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
                    
                    $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
                    if ($useCpuFallback -notmatch "^[Yy]$") {
                        exit 1
                    }
                    Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                    $nvccPath = $null
                }
            } catch {
                Write-Err "Failed to install CUDA: $_"
                Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
                
                Write-Host "Manual installation: https://developer.nvidia.com/cuda-downloads" -ForegroundColor Yellow
                
                $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
                if ($useCpuFallback -notmatch "^[Yy]$") {
                    exit 1
                }
                Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                $nvccPath = $null
            }
        } else {
            $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
            if ($useCpuFallback -notmatch "^[Yy]$") {
                Write-Err "CUDA not available"
                exit 1
            }
            Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
            $nvccPath = $null
        }
    }
    
    if ($nvccPath) {
        try {
            $nvccVer = nvcc --version 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $nvccVer -match "release") {
                $cudaVersion = $nvccVer -replace '.*release (\d+\.\d+).*','$1'
                Write-Host "CUDA version detected: $cudaVersion" -ForegroundColor Gray
                
                if ($nvccPath) {
                    Write-Host "nvcc found at: $nvccPath" -ForegroundColor Gray
                }
                
                # Find CUDA installation path
                $cudaPaths = @(
                    $env:CUDA_PATH,
                    $env:CUDA_HOME,
                    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$cudaVersion",
                    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6",
                    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.5",
                    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4",
                    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.3"
                )
                
                # If nvcc found, try to get CUDA path from its location
                if ($nvccPath) {
                    $possibleCudaPath = Split-Path (Split-Path $nvccPath -Parent) -Parent
                    if ($possibleCudaPath) {
                        $cudaPaths = @($possibleCudaPath) + $cudaPaths
                    }
                }
            
            Write-Host "Searching for CUDA installation..." -ForegroundColor Gray
            foreach ($path in $cudaPaths) {
                if ($path -and (Test-Path "$path\include\cuda_runtime.h")) {
                    $cudaPath = $path
                    Write-Host "  Found cuda_runtime.h at: $path\include\" -ForegroundColor Gray
                    break
                } elseif ($path -and (Test-Path $path)) {
                    Write-Host "  Checking: $path" -ForegroundColor DarkGray
                    
                    # Check what's actually there
                    if (Test-Path "$path\include") {
                        $headerFiles = Get-ChildItem "$path\include" -Filter "cuda*.h" -ErrorAction SilentlyContinue
                        if ($headerFiles) {
                            Write-Host "    Found include directory with $($headerFiles.Count) cuda header files" -ForegroundColor DarkGray
                        } else {
                            Write-Host "    Include directory exists but no cuda headers found" -ForegroundColor DarkGray
                        }
                    } else {
                        Write-Host "    Include directory not found" -ForegroundColor DarkGray
                    }
                    
                    if (Test-Path "$path\lib") {
                        Write-Host "    Found lib directory" -ForegroundColor DarkGray
                    }
                    if (Test-Path "$path\bin") {
                        Write-Host "    Found bin directory" -ForegroundColor DarkGray
                    }
                } elseif ($path) {
                    Write-Host "  Path does not exist: $path" -ForegroundColor DarkGray
                }
            }
            
            if ($cudaPath) {
                # Verify cudart library exists
                $cudartExists = (Test-Path "$cudaPath\lib\x64\cudart.lib") -or (Test-Path "$cudaPath\lib\cudart.lib")
                
                if ($cudartExists) {
                    Write-OK "CUDA detected: $cudaVersion at $cudaPath"
                    
                    # Check for CUDA Visual Studio Integration
                    $vsIntegrationPath = "$cudaPath\extras\visual_studio_integration\MSBuildExtensions"
                    $msbuildCudaPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Microsoft\VC\v170\BuildCustomizations"
                    
                    if (-not (Test-Path $msbuildCudaPath)) {
                        $msbuildCudaPath = "${env:ProgramFiles(x86)}\MSBuild\Microsoft.Cpp\v4.0\V170\BuildCustomizations"
                    }
                    
                    $cudaPropsExists = $false
                    if (Test-Path "$msbuildCudaPath\CUDA 12.6.props") {
                        $cudaPropsExists = $true
                        Write-Host "  CUDA Visual Studio Integration found" -ForegroundColor Gray
                    } else {
                        Write-Warn "CUDA Visual Studio Integration not found"
                        
                        # Try to install integration manually
                        if (Test-Path $vsIntegrationPath) {
                            Write-Host "  Installing CUDA VS Integration..." -ForegroundColor Gray
                            
                            try {
                                # Create MSBuild directory if it doesn't exist
                                if (-not (Test-Path $msbuildCudaPath)) {
                                    New-Item -ItemType Directory -Path $msbuildCudaPath -Force | Out-Null
                                }
                                
                                # Copy CUDA integration files
                                Copy-Item "$vsIntegrationPath\*" $msbuildCudaPath -Force -ErrorAction Stop
                                Write-OK "CUDA Visual Studio Integration installed"
                                $cudaPropsExists = $true
                            } catch {
                                Write-Warn "Failed to install CUDA VS Integration: $_"
                            }
                        }
                        
                        if (-not $cudaPropsExists) {
                            Write-Warn "Building with CUDA may fail without VS Integration"
                            $continueWithoutIntegration = Read-Host "Continue anyway? (y/n)"
                            if ($continueWithoutIntegration -notmatch "^[Yy]$") {
                                Write-Host "Please install CUDA Toolkit with Visual Studio Integration" -ForegroundColor Yellow
                                Write-Host "Or continue with CPU version" -ForegroundColor Yellow
                                $useCpuFallback = Read-Host "Continue with CPU version? (y/n)"
                                if ($useCpuFallback -notmatch "^[Yy]$") {
                                    exit 1
                                }
                                Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                                $cudaAvailable = $false
                            }
                        }
                    }
                    
                    if ($cudaPropsExists -or $cudaAvailable) {
                        $cudaAvailable = $true
                        
                        # Set environment variables for CMAKE
                        $env:CUDA_PATH = $cudaPath
                        $env:CUDA_HOME = $cudaPath
                        $env:CUDA_TOOLKIT_ROOT_DIR = $cudaPath
                        $env:CMAKE_ARGS = "-DGGML_CUDA=on -DCMAKE_CUDA_COMPILER=`"$cudaPath\bin\nvcc.exe`" -DCUDAToolkit_ROOT=`"$cudaPath`""
                        
                        # Add CUDA to PATH
                        $env:Path = "$cudaPath\bin;$cudaPath\lib\x64;" + $env:Path
                        
                        Write-Host "CUDA environment configured:" -ForegroundColor Gray
                        Write-Host "  CUDA_PATH=$cudaPath" -ForegroundColor Gray
                        Write-Host "  CMAKE_ARGS=$env:CMAKE_ARGS" -ForegroundColor Gray
                    }
                } else {
                    Write-Warn "CUDA headers found but cudart library missing at $cudaPath\lib\"
                    $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
                    if ($useCpuFallback -notmatch "^[Yy]$") {
                        Write-Err "CUDA installation incomplete"
                        exit 1
                    }
                    Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                }
            } else {
                Write-Warn "CUDA nvcc found but cuda_runtime.h not detected in standard locations"
                $installCuda = Read-Host "Install CUDA Toolkit automatically? (~3 GB) (y/n)"
                
                if ($installCuda -match "^[Yy]$") {
                    Write-Host "Downloading CUDA Toolkit 12.6..." -ForegroundColor Yellow
                    $cudaUrl = "https://developer.download.nvidia.com/compute/cuda/12.6.0/network_installers/cuda_12.6.0_windows_network.exe"
                    $cudaInstaller = "$env:TEMP\cuda_12.6.0_installer.exe"
                    
                    try {
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -Uri $cudaUrl -OutFile $cudaInstaller -UseBasicParsing
                        Write-OK "Downloaded CUDA installer"
                        
                        Write-Host "Starting CUDA Toolkit installer..." -ForegroundColor Yellow
                        Write-Host "Please follow the installation wizard instructions." -ForegroundColor Yellow
                        Write-Host "Recommended: Select 'Custom' and install all components." -ForegroundColor Yellow
                        Write-Host "" -ForegroundColor Yellow
                        
                        $cudaProcess = Start-Process -FilePath $cudaInstaller -Wait -PassThru
                        
                        if ($cudaProcess.ExitCode -eq 0) {
                            Write-OK "CUDA Toolkit installed successfully"
                            Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
                            
                            # Refresh environment and retry detection
                            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
                            Start-Sleep -Seconds 3
                            
                            # Retry CUDA detection
                            $cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
                            if (Test-Path "$cudaPath\include\cuda_runtime.h") {
                                Write-OK "CUDA verified at $cudaPath"
                                $cudaAvailable = $true
                                
                                $env:CUDA_PATH = $cudaPath
                                $env:CUDA_HOME = $cudaPath
                                $env:CUDA_TOOLKIT_ROOT_DIR = $cudaPath
                                $env:CMAKE_ARGS = "-DGGML_CUDA=on -DCMAKE_CUDA_COMPILER=`"$cudaPath\bin\nvcc.exe`" -DCUDAToolkit_ROOT=`"$cudaPath`""
                                $env:Path = "$cudaPath\bin;$cudaPath\lib\x64;" + $env:Path
                            } else {
                                Write-Warn "CUDA installed but still not detected properly"
                                Write-Host "You may need to restart your computer and run setup again" -ForegroundColor Yellow
                                $useCpuFallback = Read-Host "Continue with CPU version for now? (y/n)"
                                if ($useCpuFallback -notmatch "^[Yy]$") {
                                    exit 1
                                }
                                Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                            }
                        } else {
                            Write-Err "CUDA installation failed (exit code: $($cudaProcess.ExitCode))"
                            Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
                            
                            $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
                            if ($useCpuFallback -notmatch "^[Yy]$") {
                                exit 1
                            }
                            Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Err "Failed to download/install CUDA: $_"
                        Remove-Item $cudaInstaller -Force -ErrorAction SilentlyContinue
                        
                        Write-Host ""
                        Write-Host "Manual installation:" -ForegroundColor Yellow
                        Write-Host "  https://developer.nvidia.com/cuda-downloads" -ForegroundColor White
                        
                        $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
                        if ($useCpuFallback -notmatch "^[Yy]$") {
                            exit 1
                        }
                        Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                    }
                } else {
                    $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
                    if ($useCpuFallback -notmatch "^[Yy]$") {
                        Write-Err "CUDA installation not found"
                        exit 1
                    }
                    Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
                }
            }
            }
        } catch {
            Write-Warn "CUDA detection error: $_"
            $useCpuFallback = Read-Host "Continue with CPU version instead? (y/n)"
            if ($useCpuFallback -notmatch "^[Yy]$") {
                exit 1
            }
            Write-Host "Continuing with CPU version..." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "CUDA support disabled by user, will use CPU version" -ForegroundColor Yellow
}

$ErrorActionPreference = "Continue"
$installSuccess = $false

# Try 1: Prebuilt wheels (fast, no compilation)
Write-Host "Attempting to install prebuilt wheel (no compilation)..." -ForegroundColor Gray

foreach ($mirror in $mirrors) {
    try {
        if ($mirror.Url -eq "") {
            Write-Host "  Trying default PyPI..." -ForegroundColor Gray
            python -m pip install llama-cpp-python --prefer-binary --upgrade
        } else {
            Write-Host "  Trying $($mirror.Name)..." -ForegroundColor Gray
            python -m pip install llama-cpp-python --prefer-binary --upgrade -i $mirror.Url
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-OK "llama-cpp-python installed from prebuilt wheel"
            $installSuccess = $true
            break
        }
    } catch {
        continue
    }
}

# Try 2: Install Build Tools (if prebuilt failed and Build Tools not found)
if (-not $installSuccess) {
    Write-Warn "Prebuilt wheel not available, checking for Build Tools..."
    
    # Check if Build Tools are installed
    $buildToolsPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
    )
    
    $buildToolsFound = $false
    foreach ($path in $buildToolsPaths) {
        if (Test-Path $path) {
            Write-OK "Build Tools found at: $path"
            $buildToolsFound = $true
            break
        }
    }
    
    if (-not $buildToolsFound) {
        Write-Warn "Build Tools not found"
        Write-Host "Installing Visual Studio Build Tools automatically (~2 GB)..." -ForegroundColor Yellow
        
        Write-Host "Downloading Build Tools installer..." -ForegroundColor Gray
        $btUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
        $btInstaller = "$env:TEMP\vs_buildtools.exe"
        
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $btUrl -OutFile $btInstaller -UseBasicParsing
            Write-OK "Downloaded installer"
            
            Write-Host "Installing Build Tools (C++ only, this may take 10-15 minutes)..." -ForegroundColor Gray
            Write-Host "Please wait, do not close this window..." -ForegroundColor Yellow
            
            $installArgs = @(
                "--wait",
                "--norestart",
                "--add", "Microsoft.VisualStudio.Workload.VCTools",
                "--includeRecommended"
            )
            
            $process = Start-Process -FilePath $btInstaller -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                Write-OK "Build Tools installed successfully"
                Remove-Item $btInstaller -Force -ErrorAction SilentlyContinue
                
                if ($process.ExitCode -eq 3010) {
                    Write-Warn "Installation complete, but system restart is recommended"
                }
            } else {
                Write-Err "Build Tools installation failed (exit code: $($process.ExitCode))"
                Remove-Item $btInstaller -Force -ErrorAction SilentlyContinue
                
                Write-Host ""
                Write-Host "RECOMMENDED: Use WSL instead!" -ForegroundColor Green
                Write-Host "  Run: wsl" -ForegroundColor White
                Write-Host "  Then: ./setup.sh" -ForegroundColor White
                exit 1
            }
        } catch {
            Write-Err "Failed to install Build Tools: $_"
            Remove-Item $btInstaller -Force -ErrorAction SilentlyContinue
            
            Write-Host ""
            Write-Host "Manual installation:" -ForegroundColor Yellow
            Write-Host "  https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
            Write-Host "  Select: Desktop development with C++" -ForegroundColor White
            exit 1
        }
    }
}

# Try 3: Build from source (with Build Tools)
if (-not $installSuccess) {
    Write-Host "Building llama-cpp-python from source..." -ForegroundColor Gray
    
    if ($cudaAvailable) {
        Write-Host "Building with CUDA support (this will take 5-10 minutes)..." -ForegroundColor Gray
    }
    
    foreach ($mirror in $mirrors) {
        try {
            if ($mirror.Url -eq "") {
                Write-Host "  Trying default PyPI..." -ForegroundColor Gray
                python -m pip install llama-cpp-python --upgrade --verbose
            } else {
                Write-Host "  Trying $($mirror.Name)..." -ForegroundColor Gray
                python -m pip install llama-cpp-python --upgrade --verbose -i $mirror.Url
            }
            
            if ($LASTEXITCODE -eq 0) {
                if ($cudaAvailable) {
                    Write-OK "llama-cpp-python built with CUDA support"
                } else {
                    Write-OK "llama-cpp-python built from source (CPU version)"
                }
                $installSuccess = $true
                break
            }
        } catch {
            continue
        }
    }
}

$ErrorActionPreference = "Stop"

if (-not $installSuccess) {
    Write-Err "Failed to install llama-cpp-python"
    Write-Host ""
    Write-Host "Windows requires Visual Studio Build Tools for compilation." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "RECOMMENDED: Use WSL (Linux) instead - much easier!" -ForegroundColor Green
    Write-Host "  1. Run: wsl" -ForegroundColor White
    Write-Host "  2. Run: cd /home/kostanich/llama" -ForegroundColor White
    Write-Host "  3. Run: ./setup.sh" -ForegroundColor White
    Write-Host ""
    Write-Host "Alternative: Install Build Tools (~6 GB)" -ForegroundColor Yellow
    Write-Host "  Download: https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
    Write-Host "  Select: Desktop development with C++" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Verify installation
Write-Host "Verifying llama-cpp-python..." -ForegroundColor Gray

$ErrorActionPreference = "Continue"
$verifyError = $null
try {
    $verifyOutput = & python -c "import llama_cpp" 2>&1 | Out-String
    $verifyError = $verifyOutput
} catch {
    $verifyError = $_.Exception.Message
}
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -eq 0 -and -not $verifyError) {
    Write-OK "llama-cpp-python verified"
} else {
    Write-Warn "Verification failed (prebuilt wheel may be incompatible)"
    
    # Check if error is architecture mismatch
    $errorText = "$verifyError"
    if ($errorText -match "WinError 193" -or $errorText -match "not a valid Win32 application") {
        Write-Host "Rebuilding from source for correct architecture..." -ForegroundColor Yellow
        
        # Uninstall current version
        python -m pip uninstall llama-cpp-python -y | Out-Null
        
        # Install dependencies first (use prebuilt wheels)
        Write-Host "Installing build dependencies..." -ForegroundColor Gray
        python -m pip install --upgrade cmake ninja scikit-build-core[pyproject] | Out-Null
        
        # Build from source
        Write-Host "Building llama-cpp-python from source..." -ForegroundColor Gray
        if ($cudaAvailable) {
            Write-Host "Building with CUDA support (this may take 5-10 minutes)..." -ForegroundColor Gray
        }
        
        $ErrorActionPreference = "Continue"
        python -m pip install llama-cpp-python --no-binary llama-cpp-python --force-reinstall --verbose
        $buildResult = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        
        if ($buildResult -eq 0) {
            # Verify again
            try {
                python -c "import llama_cpp" 2>&1 | Out-Null
            } catch {}
            
            if ($LASTEXITCODE -eq 0) {
                Write-OK "llama-cpp-python rebuilt and verified successfully"
            } else {
                Write-Err "Rebuild verification failed"
                exit 1
            }
        } else {
            Write-Err "Failed to rebuild llama-cpp-python"
            exit 1
        }
    } else {
        Write-Err "Installation verification failed"
        Write-Host "Error output:" -ForegroundColor Yellow
        Write-Host "$errorText" -ForegroundColor Red
        exit 1
    }
}

# [7/8] Check scripts
Write-Step "[7/8] Checking PowerShell scripts"
$scripts = @("start.ps1", "stop.ps1")
foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-OK "$script - found"
    } else {
        Write-Warn "$script - not found"
    }
}

# [8/8] Check models
Write-Step "[8/8] Checking models"
if (-not (Test-Path "models")) {
    Write-Warn "models/ directory not found, creating..."
    New-Item -ItemType Directory -Path "models" -Force | Out-Null
}

$models = Get-ChildItem -Path "models" -Filter "*.gguf" -ErrorAction SilentlyContinue
if ($models.Count -eq 0) {
    Write-Warn "No .gguf models found in models/"
    Write-Host "Download GGUF models to models/ directory" -ForegroundColor Yellow
    Write-Host "For example from: https://huggingface.co/" -ForegroundColor Yellow
} else {
    Write-OK "Found $($models.Count) model(s)"
    foreach ($model in $models) {
        Write-Host "  [OK] $($model.Name)" -ForegroundColor Green
    }
}

# Check configuration
Write-Host ""
Write-Step "Checking configuration"
if (Test-Path "config.json") {
    try {
        $config = Get-Content "config.json" | ConvertFrom-Json
        $modelPath = $config.model.path
        
        if (Test-Path $modelPath) {
            Write-OK "Model in config.json exists: $(Split-Path -Leaf $modelPath)"
        } else {
            Write-Warn "Model in config.json not found: $modelPath"
            Write-Host "Update model path in config.json" -ForegroundColor Yellow
        }
    } catch {
        Write-Warn "Error reading config.json"
    }
} else {
    Write-Err "config.json not found"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-OK "All dependencies installed"
Write-OK "Scripts ready to use"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Make sure model is in models/ directory" -ForegroundColor White
Write-Host "  2. Check config.json (model path)" -ForegroundColor White
Write-Host "  3. Start server: " -NoNewline -ForegroundColor White
Write-Host ".\start.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "Documentation: README.md" -ForegroundColor Cyan
Write-Host ""
