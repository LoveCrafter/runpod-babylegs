#!/bin/bash
set -e

# ==============================================================================
# Unified Remote Services Launcher for Vesper AI Pod
#
# Description:
# This script is the single source of truth for starting services on the pod.
# It is designed to be idempotent and can be executed in two modes:
#
# 1. Background Mode (default):
#    Starts all services in the background (using nohup). This is for use
#    with mobile clients like Termius where the terminal session is just for
#    kicking off the services.
#
# 2. Foreground Mode (`--foreground-llm`):
#    Starts the RAG server in the background but launches the main LLM server
#    in the foreground. This allows desktop scripts to stream logs directly
#    to the user's terminal.
#
# Usage:
# ./start_remote_services.sh [--foreground-llm]
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
  # Check if a process is listening on the given TCP port.
  lsof -i tcp:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
}

# --- Main Execution ---
echo "--- Unified Remote Service Launcher ---"

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
  echo "🧠 RAG Memory Server is already running on port $RAG_PORT."
else
  echo "🧠 Starting RAG Memory Server in the background..."
  nohup python3 "$RAG_SCRIPT_PATH" > "$RAG_LOG_FILE" 2>&1 &
fi

# Check and start Main LLM Server
if is_running $LLAMA_PORT; then
  echo "🧠 Main LLM Server is already running on port $LLAMA_PORT."
else
  LLM_COMMAND="\"$LLAMA_SERVER_PATH\" --model \"$MODEL_PATH\" --n-gpu-layers $GPU_LAYERS --ctx-size $CONTEXT_SIZE --host 0.0.0.0 --port $LLAMA_PORT"

  if [ "$1" == "--foreground-llm" ]; then
    echo "🧠 Launching Main LLM Server in the foreground..."
    eval $LLM_COMMAND
  else
    echo "🧠 Launching Main LLM Server in the background..."
    nohup $LLM_COMMAND > "$LLAMA_LOG_FILE" 2>&1 &
  fi
fi

echo "✅ Service check complete. All services should be running."
echo "-----------------------------------------------------"