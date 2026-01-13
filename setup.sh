#!/bin/bash
# LLM Proxy Server - Complete Setup Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "=============================================="
echo "  LLM Proxy Server - Linux/WSL Setup        "
echo "=============================================="
echo -e "${NC}"

# Check if running in WSL or native Linux
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo -e "${GREEN}[✓] Running in WSL (Windows Subsystem for Linux)${NC}"
elif [ -f /proc/version ]; then
    echo -e "${GREEN}[✓] Running in Linux${NC}"
else
    echo -e "${YELLOW}[!] Unknown environment${NC}"
fi
echo ""

# Helper functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

step() {
    echo -e "\n${CYAN}> $1${NC}"
}

success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to install Python 3.11
install_python311() {
    step "Installing Python 3.11"
    
    if command_exists apt-get; then
        # Ubuntu/Debian
        echo "Using apt-get to install Python 3.11..."
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update
        sudo apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
        success "Python 3.11 installed via apt"
    elif command_exists yum; then
        # CentOS/RHEL
        echo "Using yum to install Python 3.11..."
        sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel
        cd /tmp
        wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
        tar xzf Python-3.11.9.tgz
        cd Python-3.11.9
        ./configure --enable-optimizations
        sudo make altinstall
        cd "$SCRIPT_DIR"
        success "Python 3.11 installed from source"
    else
        error "Cannot install Python automatically. Please install Python 3.11 manually"
        exit 1
    fi
}

# 1. Check Python 3.11
step "[1/8] Checking Python 3.11"

PYTHON_CMD=""
NEED_INSTALL=false

# Try python3.11 first
if command_exists python3.11; then
    PYTHON_CMD="python3.11"
    PYTHON_VERSION=$(python3.11 --version 2>&1)
    success "Python 3.11 found: $PYTHON_VERSION"
# Then try python3
elif command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    if [[ $PYTHON_VERSION == *"3.11."* ]]; then
        PYTHON_CMD="python3"
        success "Python 3.11 found: $PYTHON_VERSION"
    else
        warning "Python found but not 3.11: $PYTHON_VERSION"
        NEED_INSTALL=true
    fi
else
    warning "Python not found"
    NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = true ]; then
    success "Install Python 3.11 automatically? (y/n): "
        install_python311
        if command_exists python3.11; then
            PYTHON_CMD="python3.11"
            PYTHON_VERSION=$(python3.11 --version 2>&1)
            success "Python 3.11 installed: $PYTHON_VERSION"
        else
            error "Python 3.11 installation failed"
            exit 1
        fi

fi

# 2. Check pip
step "[2/8] Checking pip"
if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
    error "pip not found. Installing pip..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
fi
PIP_VERSION=$($PYTHON_CMD -m pip --version)
success "pip found: $PIP_VERSION"

# 3. Create virtual environment
step "[3/8] Creating virtual environment"
if [ -d ".venv" ]; then
    warning "Virtual environment already exists"
else
    echo "Creating .venv with Python 3.11..."
    $PYTHON_CMD -m venv .venv
    success "Virtual environment created"
fi

# Activate virtual environment
source .venv/bin/activate
success "Virtual environment activated"

# 4. Update pip
step "[4/8] Updating pip"

# Try with alternative mirrors if default fails
MIRRORS=(
    ""
    "https://mirrors.aliyun.com/pypi/simple/"
    "https://pypi.tuna.tsinghua.edu.cn/simple/"
)

PIP_UPDATED=false
SUCCESSFUL_MIRROR=""

for MIRROR in "${MIRRORS[@]}"; do
    if [ -z "$MIRROR" ]; then
        echo "Trying default PyPI..."
        python -m pip install --upgrade pip >/dev/null 2>&1 && PIP_UPDATED=true && SUCCESSFUL_MIRROR="Default PyPI"
    else
        echo "Trying mirror: $MIRROR"
        python -m pip install --upgrade pip -i "$MIRROR" >/dev/null 2>&1 && PIP_UPDATED=true && SUCCESSFUL_MIRROR="$MIRROR"
    fi
    
    if [ "$PIP_UPDATED" = true ]; then
        success "pip updated (using $SUCCESSFUL_MIRROR)"
        break
    fi
done

if [ "$PIP_UPDATED" = false ]; then
    warning "Could not update pip, continuing with current version..."
fi

# 5. Install basic dependencies
step "[5/8] Installing basic dependencies"
if [ -f "requirements.txt" ]; then
    echo "Installing packages from requirements.txt..."
    
    INSTALL_SUCCESS=false
    
    for MIRROR in "${MIRRORS[@]}"; do
        if [ -z "$MIRROR" ]; then
            echo "Trying default PyPI..."
            python -m pip install -r requirements.txt && INSTALL_SUCCESS=true
        else
            echo "Trying mirror: $MIRROR"
            python -m pip install -r requirements.txt -i "$MIRROR" && INSTALL_SUCCESS=true && SUCCESSFUL_MIRROR="$MIRROR"
        fi
        
        if [ "$INSTALL_SUCCESS" = true ]; then
            success "Basic dependencies installed"
            break
        fi
    done
    
    if [ "$INSTALL_SUCCESS" = false ]; then
        error "Failed to install basic dependencies"
        echo "Try manually: python -m pip install -r requirements.txt"
        exit 1
    fi
else
    error "requirements.txt not found"
    exit 1
fi

# 6. Install llama-cpp-python
step "[6/8] Installing llama-cpp-python"

# Check for NVIDIA GPU
GPU_AVAILABLE=false
CUDA_AVAILABLE=false

echo "Checking for NVIDIA GPU..."
if command_exists nvidia-smi; then
    GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
    if [ -n "$GPU_INFO" ]; then
        success "NVIDIA GPU detected: $GPU_INFO"
        GPU_AVAILABLE=true
    fi
elif lspci 2>/dev/null | grep -qi nvidia; then
    GPU_INFO=$(lspci | grep -i nvidia | head -n 1)
    success "NVIDIA GPU detected: $GPU_INFO"
    GPU_AVAILABLE=true
else
    warning "No NVIDIA GPU detected, will use CPU version"
fi

# If GPU available, try to setup CUDA
if [ "$GPU_AVAILABLE" = true ]; then
    echo ""
    echo -e "${CYAN}NVIDIA GPU detected! Checking CUDA setup...${NC}"
    
    if command_exists nvcc; then
        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        success "CUDA Toolkit already installed: $CUDA_VERSION"
        CUDA_AVAILABLE=true
        export CMAKE_ARGS="-DGGML_CUDA=on"
    else
        warning "CUDA Toolkit not installed"
        echo -e "${YELLOW}Install CUDA Toolkit to enable GPU acceleration? (y/n): ${NC}"
        read -r INSTALL_CUDA
        
        if [[ $INSTALL_CUDA =~ ^[Yy]$ ]]; then
            step "Installing CUDA Toolkit"
            
            # Detect WSL vs native Linux
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "Installing CUDA for WSL..."
                
                # WSL-specific CUDA installation
                if command_exists apt-get; then
                    # Remove old CUDA GPG key if exists
                    sudo apt-key del 7fa2af80 2>/dev/null || true
                    
                    # Install CUDA keyring
                    echo "Downloading CUDA keyring..."
                    wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
                    sudo dpkg -i cuda-keyring_1.1-1_all.deb
                    rm cuda-keyring_1.1-1_all.deb
                    
                    # Update and install CUDA toolkit
                    echo "Installing CUDA Toolkit (this may take 10-15 minutes)..."
                    sudo apt-get update
                    sudo apt-get install -y cuda-toolkit-12-6 || sudo apt-get install -y cuda-toolkit
                    
                    # Add to PATH
                    export PATH="/usr/local/cuda/bin:$PATH"
                    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
                    
                    # Make permanent
                    if ! grep -q "/usr/local/cuda/bin" ~/.bashrc; then
                        echo 'export PATH="/usr/local/cuda/bin:$PATH"' >> ~/.bashrc
                        echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc
                    fi
                    
                    if command_exists nvcc; then
                        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
                        success "CUDA Toolkit installed: $CUDA_VERSION"
                        CUDA_AVAILABLE=true
                        export CMAKE_ARGS="-DGGML_CUDA=on"
                    else
                        warning "CUDA installed but nvcc not found in PATH"
                        echo "You may need to restart the terminal and run setup.sh again"
                        echo -e "${YELLOW}Continue with CPU version for now? (y/n): ${NC}"
                        read -r USE_CPU
                        if [[ ! $USE_CPU =~ ^[Yy]$ ]]; then
                            exit 1
                        fi
                    fi
                else
                    error "apt-get not found. Cannot install CUDA automatically"
                    echo -e "${YELLOW}Continue with CPU version? (y/n): ${NC}"
                    read -r USE_CPU
                    if [[ ! $USE_CPU =~ ^[Yy]$ ]]; then
                        exit 1
                    fi
                fi
            else
                echo "Installing CUDA for native Linux..."
                
                if command_exists apt-get; then
                    # Ubuntu/Debian
                    echo "Downloading CUDA keyring..."
                    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu$(lsb_release -rs | tr -d '.')/x86_64/cuda-keyring_1.1-1_all.deb
                    sudo dpkg -i cuda-keyring_1.1-1_all.deb
                    rm cuda-keyring_1.1-1_all.deb
                    
                    echo "Installing CUDA Toolkit (this may take 10-15 minutes)..."
                    sudo apt-get update
                    sudo apt-get install -y cuda-toolkit-12-6 || sudo apt-get install -y cuda-toolkit
                    
                    export PATH="/usr/local/cuda/bin:$PATH"
                    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
                    
                    if ! grep -q "/usr/local/cuda/bin" ~/.bashrc; then
                        echo 'export PATH="/usr/local/cuda/bin:$PATH"' >> ~/.bashrc
                        echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc
                    fi
                    
                    if command_exists nvcc; then
                        CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
                        success "CUDA Toolkit installed: $CUDA_VERSION"
                        CUDA_AVAILABLE=true
                        export CMAKE_ARGS="-DGGML_CUDA=on"
                    else
                        warning "CUDA installed but nvcc not found"
                        echo "Restart terminal and run setup.sh again"
                        exit 0
                    fi
                else
                    error "Cannot install CUDA automatically on this system"
                    echo "Manual installation: https://developer.nvidia.com/cuda-downloads"
                    echo -e "${YELLOW}Continue with CPU version? (y/n): ${NC}"
                    read -r USE_CPU
                    if [[ ! $USE_CPU =~ ^[Yy]$ ]]; then
                        exit 1
                    fi
                fi
            fi
        else
            warning "Continuing with CPU version (GPU will not be used)"
        fi
    fi
fi

echo ""
echo "Installing llama-cpp-python..."
if [ "$CUDA_AVAILABLE" = true ]; then
    echo -e "${GREEN}Building with CUDA support (this may take 5-10 minutes)...${NC}"
else
    echo "Building CPU version..."
fi

INSTALL_SUCCESS=false

for MIRROR in "${MIRRORS[@]}"; do
    if [ -z "$MIRROR" ]; then
        echo "Trying default PyPI..."
        python -m pip install llama-cpp-python && INSTALL_SUCCESS=true
    else
        echo "Trying mirror: $MIRROR"
        python -m pip install llama-cpp-python -i "$MIRROR" && INSTALL_SUCCESS=true
    fi
    
    if [ "$INSTALL_SUCCESS" = true ]; then
        if [ "$CUDA_AVAILABLE" = true ]; then
            success "llama-cpp-python installed with CUDA support"
        else
            success "llama-cpp-python installed (CPU version)"
        fi
        break
    fi
done

if [ "$INSTALL_SUCCESS" = false ]; then
    error "Failed to install llama-cpp-python"
    echo "Try manually: python -m pip install llama-cpp-python"
    exit 1
fi

# Verify llama-cpp-python installation
echo "Verifying llama-cpp-python installation..."
if python -c "import llama_cpp" 2>/dev/null; then
    success "llama-cpp-python is properly installed"
else
    error "llama-cpp-python installation verification failed"
    echo "Try reinstalling: python -m pip install --force-reinstall llama-cpp-python[server]"
    exit 1
fi

# 7. Set execute permissions
step "[7/8] Setting execute permissions"
chmod +x start.sh 2>/dev/null && success "start.sh executable" || warning "start.sh not found"
chmod +x stop.sh 2>/dev/null && success "stop.sh executable" || warning "stop.sh not found"
chmod +x start_llama_server.sh 2>/dev/null && success "start_llama_server.sh executable" || warning "start_llama_server.sh not found"
chmod +x start_proxy_server.sh 2>/dev/null && success "start_proxy_server.sh executable" || warning "start_proxy_server.sh not found"

# 8. Check models
step "[8/8] Checking models"
MODELS_DIR="./models"
if [ ! -d "$MODELS_DIR" ]; then
    warning "models/ directory not found, creating..."
    mkdir -p "$MODELS_DIR"
fi

MODEL_COUNT=$(find "$MODELS_DIR" -name "*.gguf" 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -eq 0 ]; then
    warning "No .gguf models found in $MODELS_DIR/"
    echo -e "${YELLOW}Download GGUF models to models/ directory${NC}"
    echo -e "${YELLOW}For example from: https://huggingface.co/${NC}"
else
    success "Found $MODEL_COUNT model(s)"
    find "$MODELS_DIR" -name "*.gguf" -exec basename {} \; | while read model; do
        echo -e "  ${GREEN}[OK]${NC} $model"
    done
fi

# Check configuration
echo ""
step "Checking configuration"
if [ -f "config.json" ]; then
    MODEL_PATH=$(python -c "import json; print(json.load(open('config.json'))['model']['path'])" 2>/dev/null)
    if [ -f "$MODEL_PATH" ]; then
        success "Model in config.json exists: $(basename $MODEL_PATH)"
    else
        warning "Model in config.json not found: $MODEL_PATH"
        echo -e "${YELLOW}Update model path in config.json${NC}"
    fi
else
    error "config.json not found"
fi

# Summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}           Setup Complete!             ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${GREEN}[OK] All dependencies installed${NC}"
echo -e "${GREEN}[OK] Scripts ready to use${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Make sure model is in models/ directory"
echo -e "  2. Check config.json (model path)"
echo -e "  3. Start server: ${GREEN}./start.sh${NC}"
echo ""
echo -e "${CYAN}Documentation: README.md${NC}"
echo ""
