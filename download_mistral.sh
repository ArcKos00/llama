#!/bin/bash
# Script to download Mistral 7B Instruct v0.3 Q4_K_M GGUF model

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/models"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "=============================================="
echo "  Download Mistral 7B Instruct v0.3 Q4_K_M  "
echo "=============================================="
echo -e "${NC}"

# Model details
MODEL_NAME="mistral-7b-instruct-v0.3.Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/lmstudio-community/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3.Q4_K_M.gguf"
MODEL_PATH="$MODELS_DIR/$MODEL_NAME"

# Check if model already exists
if [ -f "$MODEL_PATH" ]; then
    echo -e "${YELLOW}[WARNING] Model already exists: $MODEL_PATH${NC}"
    read -p "Do you want to re-download it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}[OK] Using existing model${NC}"
        exit 0
    fi
    rm -f "$MODEL_PATH"
fi

# Create models directory if it doesn't exist
mkdir -p "$MODELS_DIR"

echo -e "${CYAN}> Downloading $MODEL_NAME...${NC}"
echo -e "${CYAN}> URL: $MODEL_URL${NC}"
echo -e "${CYAN}> Destination: $MODEL_PATH${NC}"
echo

# Check if wget is available
if command -v wget >/dev/null 2>&1; then
    echo -e "${GREEN}Using wget for download...${NC}"
    wget --show-progress --progress=bar:force:noscroll -O "$MODEL_PATH" "$MODEL_URL"
# Check if curl is available
elif command -v curl >/dev/null 2>&1; then
    echo -e "${GREEN}Using curl for download...${NC}"
    curl -L --progress-bar -o "$MODEL_PATH" "$MODEL_URL"
else
    echo -e "${RED}[ERROR] Neither wget nor curl is available. Please install one of them.${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install wget"
    echo "  Fedora/RHEL:   sudo dnf install wget"
    echo "  macOS:         brew install wget"
    exit 1
fi

# Verify download
if [ -f "$MODEL_PATH" ]; then
    FILE_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    echo
    echo -e "${GREEN}[OK] Model downloaded successfully!${NC}"
    echo -e "${GREEN}[OK] File size: $FILE_SIZE${NC}"
    echo -e "${GREEN}[OK] Location: $MODEL_PATH${NC}"
else
    echo
    echo -e "${RED}[ERROR] Download failed. File not found: $MODEL_PATH${NC}"
    exit 1
fi

echo
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Download complete!${NC}"
echo -e "${CYAN}========================================${NC}"
