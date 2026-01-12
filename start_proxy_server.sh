#!/bin/bash
# Скрипт для запуску FastAPI проксі сервера

HOST="0.0.0.0"
PORT="8080"

uvicorn app_server:app --host "$HOST" --port "$PORT" --reload
