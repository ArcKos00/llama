#!/bin/bash
# Скрипт для повного налаштування середовища LLM Proxy Server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Кольори
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║   LLM Proxy Server - Налаштування середовища  ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

# Функція для перевірки команди
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Функція для виведення кроку
step() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

# Функція для виведення успіху
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Функція для виведення помилки
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Функція для виведення попередження
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 1. Перевірка Python
step "[1/8] Перевірка Python"
if ! command_exists python3; then
    error "Python3 не знайдено. Встановіть Python 3.8 або новіше"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
success "Python знайдено: $PYTHON_VERSION"

# 2. Перевірка pip
step "[2/8] Перевірка pip"
if ! command_exists pip3; then
    error "pip3 не знайдено. Встановіть pip"
    exit 1
fi
success "pip знайдено: $(pip3 --version)"

# 3. Створення віртуального середовища (опційно)
step "[3/8] Віртуальне середовище"
if [ -d "venv" ]; then
    warning "Віртуальне середовище вже існує, пропускаємо створення"
else
    read -p "Створити віртуальне середовище? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        python3 -m venv venv
        success "Віртуальне середовище створено"
        echo -e "${YELLOW}Для активації використайте: source venv/bin/activate${NC}"
    else
        warning "Віртуальне середовище не створено"
    fi
fi

# 4. Оновлення pip
step "[4/8] Оновлення pip"
python3 -m pip install --upgrade pip > /dev/null 2>&1
success "pip оновлено"

# 5. Встановлення основних залежностей
step "[5/8] Встановлення залежностей з requirements.txt"
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt
    success "Залежності встановлено"
else
    error "requirements.txt не знайдено"
    exit 1
fi

# 6. Встановлення llama-cpp-python[server]
step "[6/8] Встановлення llama-cpp-python[server]"
echo -e "${YELLOW}Це може зайняти кілька хвилин...${NC}"

# Перевірка наявності CUDA для GPU підтримки
if command_exists nvcc; then
    warning "CUDA знайдено, встановлюємо з підтримкою GPU"
    CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip3 install llama-cpp-python[server] --upgrade --force-reinstall --no-cache-dir
    success "llama-cpp-python[server] встановлено з підтримкою CUDA"
else
    warning "CUDA не знайдено, встановлюємо CPU версію"
    pip3 install llama-cpp-python[server]
    success "llama-cpp-python[server] встановлено (CPU)"
fi

# 7. Налаштування прав доступу до скриптів
step "[7/8] Налаштування прав доступу"
chmod +x start.sh 2>/dev/null && success "start.sh - виконуваний" || warning "start.sh не знайдено"
chmod +x stop.sh 2>/dev/null && success "stop.sh - виконуваний" || warning "stop.sh не знайдено"
chmod +x start_llama_server.sh 2>/dev/null && success "start_llama_server.sh - виконуваний" || warning "start_llama_server.sh не знайдено"
chmod +x start_proxy_server.sh 2>/dev/null && success "start_proxy_server.sh - виконуваний" || warning "start_proxy_server.sh не знайдено"

# 8. Перевірка моделей
step "[8/8] Перевірка моделей"
MODELS_DIR="./models"
if [ ! -d "$MODELS_DIR" ]; then
    warning "Директорія models/ не знайдена, створюємо..."
    mkdir -p "$MODELS_DIR"
fi

MODEL_COUNT=$(find "$MODELS_DIR" -name "*.gguf" 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -eq 0 ]; then
    warning "Моделі .gguf не знайдено в $MODELS_DIR/"
    echo -e "${YELLOW}Завантажте моделі у форматі GGUF в директорію models/${NC}"
    echo -e "${YELLOW}Наприклад з: https://huggingface.co/${NC}"
else
    success "Знайдено моделей: $MODEL_COUNT"
    find "$MODELS_DIR" -name "*.gguf" -exec basename {} \; | while read model; do
        echo -e "  ${GREEN}•${NC} $model"
    done
fi

# Перевірка конфігурації
echo ""
step "Перевірка конфігурації"
if [ -f "config.json" ]; then
    MODEL_PATH=$(python3 -c "import json; print(json.load(open('config.json'))['model']['path'])" 2>/dev/null)
    if [ -f "$MODEL_PATH" ]; then
        success "Модель в config.json існує: $(basename $MODEL_PATH)"
    else
        warning "Модель в config.json не знайдена: $MODEL_PATH"
        echo -e "${YELLOW}Оновіть шлях до моделі в config.json${NC}"
    fi
else
    error "config.json не знайдено"
fi

# Підсумок
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Налаштування завершено!            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Всі залежності встановлено${NC}"
echo -e "${GREEN}✓ Скрипти готові до використання${NC}"
echo ""
echo -e "${YELLOW}Наступні кроки:${NC}"
echo -e "  1. Переконайтесь що модель є в директорії models/"
echo -e "  2. Перевірте config.json (шлях до моделі)"
echo -e "  3. Запустіть сервер: ${GREEN}./start.sh${NC}"
echo ""
echo -e "${BLUE}Документація: README.md${NC}"
echo ""
