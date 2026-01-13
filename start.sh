#!/bin/bash
# Централізований скрипт для запуску LLM Proxy Server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Activate virtual environment if it exists
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
    echo -e "${GREEN}Virtual environment activated${NC}"
elif [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo -e "${GREEN}Virtual environment activated${NC}"
fi

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Конфігурація з config.json або значення за замовчуванням
if [ -f "config.json" ]; then
    MODEL_PATH=$(python3 -c "import json; print(json.load(open('config.json'))['model']['path'])" 2>/dev/null || echo "")
    LLAMA_HOST=$(python3 -c "import json; print(json.load(open('config.json'))['servers']['llama_server']['host'])" 2>/dev/null || echo "127.0.0.1")
    LLAMA_PORT=$(python3 -c "import json; print(json.load(open('config.json'))['servers']['llama_server']['port'])" 2>/dev/null || echo "8000")
    PROXY_HOST=$(python3 -c "import json; print(json.load(open('config.json'))['servers']['proxy_server']['host'])" 2>/dev/null || echo "0.0.0.0")
    PROXY_PORT=$(python3 -c "import json; print(json.load(open('config.json'))['servers']['proxy_server']['port'])" 2>/dev/null || echo "8080")
    N_GPU_LAYERS=$(python3 -c "import json; print(json.load(open('config.json'))['model']['n_gpu_layers'])" 2>/dev/null || echo "40")
    N_CTX=$(python3 -c "import json; print(json.load(open('config.json'))['model']['n_ctx'])" 2>/dev/null || echo "4096")
else
    echo -e "${RED}Помилка: config.json не знайдено${NC}"
    exit 1
fi

# Перетворення відносного шляху в абсолютний
if [[ "$MODEL_PATH" != /* ]]; then
    MODEL_PATH="$SCRIPT_DIR/$MODEL_PATH"
fi

# PID файли для відстеження процесів
LLAMA_PID_FILE="/tmp/llama_server.pid"
PROXY_PID_FILE="/tmp/proxy_server.pid"

echo -e "${GREEN}=== LLM Proxy Server Startup ===${NC}"

# Функція для очищення при виході
cleanup() {
    echo -e "\n${YELLOW}Зупинка серверів...${NC}"
    
    if [ -f "$PROXY_PID_FILE" ]; then
        PROXY_PID=$(cat "$PROXY_PID_FILE")
        if kill -0 "$PROXY_PID" 2>/dev/null; then
            echo "Зупинка proxy server (PID: $PROXY_PID)"
            kill "$PROXY_PID" 2>/dev/null || true
        fi
        rm -f "$PROXY_PID_FILE"
    fi
    
    if [ -f "$LLAMA_PID_FILE" ]; then
        LLAMA_PID=$(cat "$LLAMA_PID_FILE")
        if kill -0 "$LLAMA_PID" 2>/dev/null; then
            echo "Зупинка llama server (PID: $LLAMA_PID)"
            kill "$LLAMA_PID" 2>/dev/null || true
        fi
        rm -f "$LLAMA_PID_FILE"
    fi
    
    echo -e "${GREEN}Сервери зупинено${NC}"
}

trap cleanup EXIT INT TERM

# Перевірка наявності моделі
if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${RED}Помилка: Модель не знайдено за шляхом: $MODEL_PATH${NC}"
    exit 1
fi

# Запуск llama-cpp-python server
echo -e "${YELLOW}[1/2] Запуск llama-cpp-python server на $LLAMA_HOST:$LLAMA_PORT...${NC}"
python3 -m llama_cpp.server \
  --model "$MODEL_PATH" \
  --host "$LLAMA_HOST" \
  --port "$LLAMA_PORT" \
  --n_gpu_layers "$N_GPU_LAYERS" \
  --n_ctx "$N_CTX" &

LLAMA_PID=$!
echo $LLAMA_PID > "$LLAMA_PID_FILE"
echo -e "${GREEN}✓ Llama server запущено (PID: $LLAMA_PID)${NC}"

# Очікування готовності llama server
echo -e "${YELLOW}Очікування готовності llama server...${NC}"
for i in {1..30}; do
    if curl -s "http://$LLAMA_HOST:$LLAMA_PORT/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Llama server готовий${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Помилка: Llama server не запустився${NC}"
        exit 1
    fi
    sleep 2
done

# Запуск FastAPI proxy server
echo -e "${YELLOW}[2/2] Запуск FastAPI proxy server на $PROXY_HOST:$PROXY_PORT...${NC}"
uvicorn app_server:app --host "$PROXY_HOST" --port "$PROXY_PORT" &

PROXY_PID=$!
echo $PROXY_PID > "$PROXY_PID_FILE"
echo -e "${GREEN}✓ Proxy server запущено (PID: $PROXY_PID)${NC}"

# Очікування готовності proxy server
echo -e "${YELLOW}Очікування готовності proxy server...${NC}"
sleep 3
for i in {1..15}; do
    if curl -s "http://localhost:$PROXY_PORT/docs" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Proxy server готовий${NC}"
        break
    fi
    if [ $i -eq 15 ]; then
        echo -e "${RED}Попередження: Proxy server може бути ще не готовий${NC}"
    fi
    sleep 1
done

echo ""
echo -e "${GREEN}=== Сервери успішно запущено ===${NC}"
echo ""
echo -e "📊 Llama server:  http://$LLAMA_HOST:$LLAMA_PORT"
echo -e "🚀 Proxy server:  http://$PROXY_HOST:$PROXY_PORT"
echo -e "📖 API Docs:      http://localhost:$PROXY_PORT/docs"
echo ""
echo -e "${YELLOW}Натисніть Ctrl+C для зупинки серверів${NC}"
echo ""

# Очікування
wait $PROXY_PID $LLAMA_PID
