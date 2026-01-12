#!/bin/bash
# Скрипт для встановлення та налаштування Python 3.11
# Bash версія для Linux/WSL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Конфігурація
REQUIRED_PYTHON_VERSION="3.11"
VENV_NAME=".venv"

# Кольори
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функції
step() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Функція для перевірки версії Python
get_python_version() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=$($cmd --version 2>&1 | grep -oP 'Python \K\d+\.\d+' || echo "")
        echo "$version"
    else
        echo ""
    fi
}

echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      Python 3.11 - Налаштування оточення       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"

# 1. Перевірка наявності Python 3.11
step "[1/5] Перевірка Python 3.11"

PYTHON311_FOUND=false
PYTHON_CMD=""

# Спроба знайти python3.11
for cmd in python3.11 python3 python; do
    version=$(get_python_version "$cmd")
    if [ "$version" = "$REQUIRED_PYTHON_VERSION" ]; then
        PYTHON311_FOUND=true
        PYTHON_CMD="$cmd"
        success "Python 3.11 знайдено: $cmd"
        break
    fi
done

if [ "$PYTHON311_FOUND" = false ]; then
    warning "Python 3.11 не знайдено"
    
    # Визначення дистрибутиву
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        DISTRO="unknown"
    fi
    
    echo ""
    read -p "Встановити Python 3.11? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        case $DISTRO in
            ubuntu|debian)
                warning "Встановлення Python 3.11 на Ubuntu/Debian..."
                
                # Оновлення списку пакетів
                sudo apt-get update
                
                # Додавання deadsnakes PPA для Ubuntu
                if [ "$DISTRO" = "ubuntu" ]; then
                    sudo apt-get install -y software-properties-common
                    sudo add-apt-repository -y ppa:deadsnakes/ppa
                    sudo apt-get update
                fi
                
                # Встановлення Python 3.11
                sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
                
                success "Python 3.11 встановлено"
                PYTHON_CMD="python3.11"
                ;;
                
            fedora|rhel|centos)
                warning "Встановлення Python 3.11 на Fedora/RHEL/CentOS..."
                sudo dnf install -y python3.11 python3.11-devel
                success "Python 3.11 встановлено"
                PYTHON_CMD="python3.11"
                ;;
                
            arch|manjaro)
                warning "Встановлення Python 3.11 на Arch/Manjaro..."
                sudo pacman -S --noconfirm python
                success "Python 3.11 встановлено"
                PYTHON_CMD="python3.11"
                ;;
                
            *)
                error "Автоматичне встановлення не підтримується для $DISTRO"
                warning "Встановіть Python 3.11 вручну та запустіть скрипт знову"
                exit 1
                ;;
        esac
    else
        error "Python 3.11 обов'язковий для роботи проекту"
        exit 1
    fi
fi

# Перевірка після встановлення
if [ -z "$PYTHON_CMD" ]; then
    for cmd in python3.11 python3 python; do
        version=$(get_python_version "$cmd")
        if [ "$version" = "$REQUIRED_PYTHON_VERSION" ]; then
            PYTHON_CMD="$cmd"
            break
        fi
    done
fi

if [ -z "$PYTHON_CMD" ]; then
    error "Python 3.11 не знайдено після встановлення"
    exit 1
fi

# 2. Перевірка pip
step "[2/5] Перевірка pip"
if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
    warning "pip не знайдено, встановлення..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get install -y python3-pip
            ;;
        fedora|rhel|centos)
            sudo dnf install -y python3-pip
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm python-pip
            ;;
    esac
    
    success "pip встановлено"
else
    success "pip знайдено: $($PYTHON_CMD -m pip --version)"
fi

# 3. Створення віртуального середовища
step "[3/5] Створення віртуального середовища"
if [ -d "$VENV_NAME" ]; then
    warning "Віртуальне середовище вже існує: $VENV_NAME"
    read -p "Перестворити віртуальне середовище? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        warning "Видалення старого віртуального середовища..."
        rm -rf "$VENV_NAME"
        
        echo "Створення нового віртуального середовища..."
        $PYTHON_CMD -m venv "$VENV_NAME"
        success "Віртуальне середовище створено: $VENV_NAME"
    else
        warning "Використовується існуюче віртуальне середовище"
    fi
else
    echo "Створення віртуального середовища..."
    $PYTHON_CMD -m venv "$VENV_NAME"
    success "Віртуальне середовище створено: $VENV_NAME"
fi

# Шлях до Python у віртуальному середовищі
VENV_PYTHON="$VENV_NAME/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    error "Не вдалося створити віртуальне середовище"
    exit 1
fi

# 4. Оновлення pip у віртуальному середовищі
step "[4/5] Оновлення pip у віртуальному середовищі"
$VENV_PYTHON -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1
success "pip оновлено у віртуальному середовищі"

# 5. Встановлення залежностей
step "[5/5] Встановлення залежностей проекту"
if [ -f "requirements.txt" ]; then
    warning "Встановлення залежностей з requirements.txt..."
    $VENV_PYTHON -m pip install -r requirements.txt
    success "Залежності встановлено"
else
    warning "requirements.txt не знайдено, пропускаємо встановлення залежностей"
fi

# Підсумок
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Python 3.11 середовище налаштовано!       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
success "✓ Python 3.11 встановлено та налаштовано"
success "✓ Віртуальне середовище: $VENV_NAME"
success "✓ Всі залежності встановлено"
echo ""
echo -e "${CYAN}Для активації віртуального середовища:${NC}"
echo -e "${YELLOW}  source $VENV_NAME/bin/activate${NC}"
echo ""
echo -e "${CYAN}Для деактивації:${NC}"
echo -e "${YELLOW}  deactivate${NC}"
echo ""
echo -e "${CYAN}Для перевірки версії Python:${NC}"
echo -e "${YELLOW}  python --version${NC}"
echo ""
