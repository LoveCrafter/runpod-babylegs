#!/bin/bash
set -e

# ==============================================================================
# Unified Remote Services Launcher for Vesper AI Pod
#
# Description:
# This script is the single source of truth for starting services on the pod.
# It reads its configuration from `vesper.conf` and is designed to be idempotent.
#
# It can be executed in several modes:
# 1. Default Mode (`./start_remote_services.sh`):
#    Starts all services in the background if they are not already running.
#    Ideal for the Termius mobile client's startup snippet.
#
# 2. Foreground Mode (`./start_remote_services.sh --foreground-llm`):
#    Launches the LLM server in the foreground to stream logs.
#    Used by the local `start_services.sh` and `start_services.ps1` scripts.
#
# 3. Restart Mode (`./start_remote_services.sh --restart-llm`):
#    Stops the existing LLM server and starts it again with the latest settings
#    from `vesper.conf`. The RAG server is not affected.
#
# Usage:
# ./start_remote_services.sh [--foreground-llm] [--restart-llm]
# ==============================================================================

# --- Path and Environment Configuration ---
WORKSPACE_DIR="/workspace"
REPO_DIR="$WORKSPACE_DIR/runpod-babylegs"
VENV_PATH="$REPO_DIR/vesper_env/bin/activate"
CONFIG_FILE="$REPO_DIR/vesper.conf"
LLAMA_SERVER_PATH="$REPO_DIR/llama.cpp/build/bin/llama-server"
LLAMA_CPP_DIR="$REPO_DIR/llama.cpp"
RAG_SCRIPT_PATH="$REPO_DIR/build_memory.py"

# --- Log File Configuration ---
RAG_LOG_FILE="$WORKSPACE_DIR/rag_server.log"
LLAMA_LOG_FILE="$WORKSPACE_DIR/llama_server.log"

# --- Function Definitions ---
is_running() {
  # Check if a process is listening on the given TCP port.
  lsof -i tcp:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
}

stop_llm_server() {
  echo "🛑 Stopping existing LLM Server..."
  PID=$(lsof -t -i tcp:"$LLAMA_PORT" -sTCP:LISTEN || true)
  if [ -n "$PID" ]; then
    echo "🔪 Killing process with PID: $PID"
    kill "$PID"
    sleep 2
    if is_running "$LLAMA_PORT"; then
        echo "❌ Failed to stop the LLM server. Trying with KILL -9."
        kill -9 "$PID"
        sleep 2
        if is_running "$LLAMA_PORT"; then
            echo "🔥 CRITICAL: Could not kill process $PID on port $LLAMA_PORT. Manual intervention required." >&2
            exit 1
        fi
    fi
    echo "✅ LLM Server stopped."
  else
    echo "🤷 No running LLM server found to stop."
  fi
}

# --- Dependency & Configuration Checks ---
if ! command -v lsof &> /dev/null; then
    echo "❌ Error: 'lsof' command not found. Please install it to continue." >&2
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: Configuration file not found at $CONFIG_FILE." >&2
  exit 1
fi

# --- Configuration Loading ---
echo "📜 Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"
# Allow environment variable to override the model path from the config file
MODEL_PATH="${VESPER_MODEL_PATH:-$MODEL_PATH}"

# --- Argument Parsing ---
RESTART_LLM=false
FOREGROUND_LLM=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart-llm) RESTART_LLM=true; shift ;;
    --foreground-llm) FOREGROUND_LLM=true; shift ;;
    *) shift ;; # Ignore unknown options
  esac
done

# --- Main Execution ---
echo "--- Unified Remote Service Launcher ---"

# Activate Python environment
echo "🐍 Activating Python environment..."
source "$VENV_PATH"

# If --restart-llm is passed, only restart the LLM server.
if [ "$RESTART_LLM" = true ]; then
  stop_llm_server
else
  # --- Auto-compile llama-server if it doesn't exist ---
  if [ ! -f "$LLAMA_SERVER_PATH" ]; then
    echo "🛠️ 'llama-server' not found. Compiling now..."
    cd "$LLAMA_CPP_DIR"
    make
    echo "✅ Compilation complete."
    cd "$REPO_DIR" # Return to the repo directory
  fi

  # --- Check and start RAG Memory Server ---
  if is_running $RAG_PORT; then
    echo "🧠 RAG Memory Server is already running on port $RAG_PORT."
  else
    echo "🧠 Starting RAG Memory Server in the background..."
    nohup python3 "$RAG_SCRIPT_PATH" > "$RAG_LOG_FILE" 2>&1 &
    echo "⏳ Waiting for RAG server to become healthy..."
    SECONDS=0
    while true; do
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${RAG_PORT}/")
      if [ "$STATUS" -eq 200 ]; then echo "✅ RAG server is healthy!"; break; fi
      if [ $SECONDS -ge 30 ]; then echo "❌ RAG server timed out. Check $RAG_LOG_FILE."; exit 1; fi
      sleep 1
    done
  fi
fi

# --- Check and start Main LLM Server ---
if is_running $LLAMA_PORT; then
  echo "🧠 Main LLM Server is already running on port $LLAMA_PORT."
else
  LLM_COMMAND_ARGS=(
    --model "$MODEL_PATH"
    --n-gpu-layers "$GPU_LAYERS"
    --ctx-size "$CONTEXT_SIZE"
    --host "0.0.0.0"
    --port "$LLAMA_PORT"
  )

  if [ "$FOREGROUND_LLM" = true ]; then
    echo "🧠 Launching Main LLM Server in the foreground with $GPU_LAYERS GPU layers and context size $CONTEXT_SIZE..."
    "$LLAMA_SERVER_PATH" "${LLM_COMMAND_ARGS[@]}"
  else
    echo "🧠 Launching Main LLM Server in the background with $GPU_LAYERS GPU layers and context size $CONTEXT_SIZE..."
    nohup "$LLAMA_SERVER_PATH" "${LLM_COMMAND_ARGS[@]}" > "$LLAMA_LOG_FILE" 2>&1 &
  fi
fi

echo "✅ Service check complete."
echo "-----------------------------------------------------"