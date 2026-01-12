#!/bin/bash
# Скрипт для зупинки серверів

LLAMA_PID_FILE="/tmp/llama_server.pid"
PROXY_PID_FILE="/tmp/proxy_server.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Зупинка серверів...${NC}"

STOPPED=0

# Зупинка proxy server
if [ -f "$PROXY_PID_FILE" ]; then
    PROXY_PID=$(cat "$PROXY_PID_FILE")
    if kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "Зупинка proxy server (PID: $PROXY_PID)"
        kill "$PROXY_PID" 2>/dev/null && STOPPED=$((STOPPED+1))
        sleep 1
        # Примусова зупинка якщо не зупинився
        kill -9 "$PROXY_PID" 2>/dev/null || true
    fi
    rm -f "$PROXY_PID_FILE"
fi

# Зупинка llama server
if [ -f "$LLAMA_PID_FILE" ]; then
    LLAMA_PID=$(cat "$LLAMA_PID_FILE")
    if kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "Зупинка llama server (PID: $LLAMA_PID)"
        kill "$LLAMA_PID" 2>/dev/null && STOPPED=$((STOPPED+1))
        sleep 1
        # Примусова зупинка якщо не зупинився
        kill -9 "$LLAMA_PID" 2>/dev/null || true
    fi
    rm -f "$LLAMA_PID_FILE"
fi

# Додатково: зупинка за портами якщо PID файли відсутні
echo "Перевірка процесів на портах..."
LLAMA_PID=$(lsof -ti:8000 2>/dev/null)
if [ ! -z "$LLAMA_PID" ]; then
    echo "Знайдено процес на порту 8000 (PID: $LLAMA_PID), зупинка..."
    kill "$LLAMA_PID" 2>/dev/null || kill -9 "$LLAMA_PID" 2>/dev/null || true
    STOPPED=$((STOPPED+1))
fi

PROXY_PID=$(lsof -ti:8080 2>/dev/null)
if [ ! -z "$PROXY_PID" ]; then
    echo "Знайдено процес на порту 8080 (PID: $PROXY_PID), зупинка..."
    kill "$PROXY_PID" 2>/dev/null || kill -9 "$PROXY_PID" 2>/dev/null || true
    STOPPED=$((STOPPED+1))
fi

if [ $STOPPED -gt 0 ]; then
    echo -e "${GREEN}✓ Зупинено $STOPPED процес(ів)${NC}"
else
    echo -e "${YELLOW}Сервери не запущені${NC}"
fi
