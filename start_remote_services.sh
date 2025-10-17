#!/bin/bash
set -e

# ==============================================================================
# Remote Services Launcher for Vesper AI Pod
#
# Description:
# This script is executed remotely by another script (e.g., mobile_connect.sh).
# It ensures that all necessary services (RAG server, LLM server) are running
# on the pod. It is designed to be non-interactive.
#
# It handles auto-compilation of llama-server and runs the servers in the
# background so that the SSH connection that started it can be used for
# port-forwarding.
# ==============================================================================

# --- Path Configuration ---
WORKSPACE_DIR="/workspace"
REPO_DIR="$WORKSPACE_DIR/runpod-babylegs"
VENV_PATH="$REPO_DIR/vesper_env/bin/activate"
MODEL_PATH="${VESPER_MODEL_PATH:-$REPO_DIR/models/huihui-ai/Huihui-gpt-oss-120b-BF16-abliterated/Q4_K_M-GGUF/Q4_K_M-GGUF/Q4_K_M-GGUF-00001-of-00009.gguf}"
RAG_SCRIPT_PATH="$REPO_DIR/build_memory.py"
LLAMA_SERVER_PATH="$REPO_DIR/llama.cpp/build/bin/llama-server"
LLAMA_CPP_DIR="$REPO_DIR/llama.cpp"

# --- Service Port Configuration ---
RAG_PORT="5000"
LLAMA_PORT="8080"

# --- LLM Parameter Configuration ---
GPU_LAYERS=34
CONTEXT_SIZE=1024

# --- Log File Configuration ---
RAG_LOG_FILE="$WORKSPACE_DIR/rag_server.log"
LLAMA_LOG_FILE="$WORKSPACE_DIR/llama_server.log"

# --- Function to check if a process is running on a given port ---
is_running() {
  if lsof -i -P -n | grep -q ":$1 (LISTEN)"; then
    return 0 # 0 means true in bash
  else
    return 1
  fi
}

# --- Main Execution ---
echo "--- Remote Service Check ---"

# Activate Python environment
echo "🐍 Activating Python environment..."
source "$VENV_PATH"

# Auto-compile llama-server if it doesn't exist
if [ ! -f "$LLAMA_SERVER_PATH" ]; then
  echo "🛠️ 'llama-server' not found. Compiling now..."
  cd "$LLAMA_CPP_DIR"
  make
  echo "✅ Compilation complete."
  cd "$REPO_DIR" # Return to the repo directory
fi

# Check and start RAG Memory Server
if is_running $RAG_PORT; then
  echo "🧠 RAG Memory Server is already running."
else
  echo "🧠 Starting RAG Memory Server in the background..."
  nohup python3 "$RAG_SCRIPT_PATH" > "$RAG_LOG_FILE" 2>&1 &
fi

# Check and start Main LLM Server
if is_running $LLAMA_PORT; then
  echo "🧠 Main LLM Server is already running."
else
  echo "🧠 Launching Main LLM Server in the background..."
  nohup "$LLAMA_SERVER_PATH" \
    --model "$MODEL_PATH" \
    --n-gpu-layers $GPU_LAYERS \
    --ctx-size $CONTEXT_SIZE \
    --host 0.0.0.0 \
    --port $LLAMA_PORT > "$LLAMA_LOG_FILE" 2>&1 &
fi

echo "✅ Remote services are running."
echo "-----------------------------------------------------"
# This final message is to let the user of mobile_connect.sh know it's safe to proceed.
echo "SSH tunnel is now active. You can connect to http://localhost:$LLAMA_PORT"
echo "This terminal window will now idle to keep the connection alive. Press Ctrl+C to close."
# The 'sleep infinity' is a simple way to keep the script (and thus the SSH session) alive.
sleep infinity