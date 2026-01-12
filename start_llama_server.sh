#!/bin/bash
# Скрипт для запуску llama-cpp-python server

MODEL_PATH="/home/kostanich/llama/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf"
HOST="127.0.0.1"
PORT="8000"
N_GPU_LAYERS="40"
N_CTX="4096"

python3 -m llama_cpp.server \
  --model "$MODEL_PATH" \
  --host "$HOST" \
  --port "$PORT" \
  --n_gpu_layers "$N_GPU_LAYERS" \
  --n_ctx "$N_CTX" \
  --verbose
