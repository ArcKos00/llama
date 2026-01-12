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
echo "========================================"
echo "  LLM Proxy Server - Setup Environment  "
echo "========================================"
echo -e "${NC}"

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
    read -p "Install Python 3.11 automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_python311
        if command_exists python3.11; then
            PYTHON_CMD="python3.11"
            PYTHON_VERSION=$(python3.11 --version 2>&1)
            success "Python 3.11 installed: $PYTHON_VERSION"
        else
            error "Python 3.11 installation failed"
            exit 1
        fi
    else
        error "Python 3.11 is required. Install from: https://www.python.org/downloads/"
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

# 5. Install dependencies
step "[5/8] Installing dependencies from requirements.txt"
if [ -f "requirements.txt" ]; then
    echo "Installing packages... (this may take a while)"
    
    INSTALL_SUCCESS=false
    
    for MIRROR in "${MIRRORS[@]}"; do
        if [ -z "$MIRROR" ]; then
            echo "Trying default PyPI..."
            python -m pip install -r requirements.txt >/dev/null 2>&1 && INSTALL_SUCCESS=true
        else
            echo "Trying mirror: $MIRROR"
            python -m pip install -r requirements.txt -i "$MIRROR" >/dev/null 2>&1 && INSTALL_SUCCESS=true && SUCCESSFUL_MIRROR="$MIRROR"
        fi
        
        if [ "$INSTALL_SUCCESS" = true ]; then
            success "Dependencies installed"
            break
        fi
    done
    
    if [ "$INSTALL_SUCCESS" = false ]; then
        error "Failed to install dependencies"
        echo "Try manually: python -m pip install -r requirements.txt"
        exit 1
    fi
else
    error "requirements.txt not found"
    exit 1
fi

# 6. Install llama-cpp-python[server]
step "[6/8] Installing llama-cpp-python[server]"

# First, test network connectivity from WSL
echo "Testing network from WSL..."
if ! curl -s --connect-timeout 5 https://pypi.org > /dev/null 2>&1; then
    error "Cannot connect to PyPI from WSL"
    echo ""
    echo "Network troubleshooting:"
    echo "  1. Check WSL network: ping google.com"
    echo "  2. Check DNS: cat /etc/resolv.conf"
    echo "  3. Try restarting WSL: wsl --shutdown (from Windows)"
    echo "  4. Check Windows firewall/antivirus"
    echo ""
    echo "Try manually:"
    echo "  python -m pip install llama-cpp-python[server] -vvv"
    echo ""
    exit 1
fi
success "Network connection OK"

echo "This may take several minutes..."

# Check for CUDA
CUDA_AVAILABLE=false
if command_exists nvcc; then
    warning "CUDA detected, installing with GPU support"
    CUDA_AVAILABLE=true
fi

if [ "$CUDA_AVAILABLE" = true ]; then
    success "CUDA available, installing with GPU support"
    export CMAKE_ARGS="-DLLAMA_CUBLAS=on"
    echo "Building with CUDA support... (this will take 5-10 minutes)"
    echo "Showing output (this may be verbose)..."
    echo ""
    
    INSTALL_SUCCESS=false
    for MIRROR in "${MIRRORS[@]}"; do
        if [ -z "$MIRROR" ]; then
            echo "Trying default PyPI..."
            python -m pip install llama-cpp-python[server] --upgrade --force-reinstall --no-cache-dir && INSTALL_SUCCESS=true
        else
            echo "Trying mirror: $MIRROR"
            python -m pip install llama-cpp-python[server] --upgrade --force-reinstall --no-cache-dir -i "$MIRROR" && INSTALL_SUCCESS=true
        fi
        
        if [ "$INSTALL_SUCCESS" = true ]; then
            success "llama-cpp-python[server] installed with CUDA"
            break
        fi
    done
    
    if [ "$INSTALL_SUCCESS" = false ]; then
        warning "Failed to install with CUDA, trying CPU version..."
        CUDA_AVAILABLE=false
    fi
fi

if [ "$CUDA_AVAILABLE" = false ]; then
    warning "Installing CPU version"
    echo "Installing llama-cpp-python... (this may take a few minutes)"
    echo "Showing output..."
    echo ""
    
    INSTALL_SUCCESS=false
    LAST_ERROR=""
    
    for MIRROR in "${MIRRORS[@]}"; do
        if [ -z "$MIRROR" ]; then
            echo "Trying default PyPI..."
            if python -m pip install llama-cpp-python[server] 2>&1 | tee /tmp/pip_install.log; then
                INSTALL_SUCCESS=true
            else
                LAST_ERROR=$(tail -20 /tmp/pip_install.log)
            fi
        else
            echo "Trying mirror: $MIRROR"
            if python -m pip install llama-cpp-python[server] -i "$MIRROR" 2>&1 | tee /tmp/pip_install.log; then
                INSTALL_SUCCESS=true
            else
                LAST_ERROR=$(tail -20 /tmp/pip_install.log)
            fi
        fi
        
        if [ "$INSTALL_SUCCESS" = true ]; then
            success "llama-cpp-python[server] installed (CPU)"
            break
        fi
    done
    
    if [ "$INSTALL_SUCCESS" = false ]; then
        error "Failed to install llama-cpp-python"
        echo ""
        echo "Last error:"
        echo "$LAST_ERROR"
        echo ""
        echo "Try manually with verbose output:"
        echo "  python -m pip install llama-cpp-python[server] -vvv"
        echo ""
        exit 1
    fi
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
