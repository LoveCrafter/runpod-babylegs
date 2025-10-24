#!/bin/bash
set -e

# ==============================================================================
# Unified Remote Services Launcher for Vesper AI Pod (with Nginx Reverse Proxy)
#
# Description:
# This script is the single source of truth for starting services on the pod.
# It uses Nginx as a reverse proxy to serve multiple applications on a single
# public port, solving the RunPod single-port limitation.
#
# Architecture:
# - Nginx listens on the public port (e.g., 8080).
# - RAG Memory Server runs on an internal port (5000).
# - Main LLM Server runs on an internal port (8081).
# - Nginx routes traffic based on URL: `/rag/*` -> RAG, `/` -> LLM.
#
# Usage:
# ./start_remote_services.sh [--foreground-llm] [--restart]
# ==============================================================================

# --- Path and Environment Configuration ---
WORKSPACE_DIR="/workspace"
REPO_DIR="$WORKSPACE_DIR/runpod-babylegs"
VENV_PATH="$REPO_DIR/vesper_env/bin/activate"
CONFIG_FILE="$REPO_DIR/vesper.conf"
LLAMA_SERVER_PATH="$REPO_DIR/llama.cpp/build/bin/llama-server"
LLAMA_CPP_DIR="$REPO_DIR/llama.cpp"
RAG_SCRIPT_PATH="$REPO_DIR/build_memory.py"
NGINX_CONFIG_TEMPLATE="$REPO_DIR/nginx.conf"
TEMP_NGINX_CONFIG="/tmp/nginx.conf"

# --- Port Configuration ---
# Public port exposed by RunPod.
PUBLIC_PORT="${RUNPOD_TCP_PORT_8080:-8080}"
INTERNAL_RAG_PORT=5000
INTERNAL_LLAMA_PORT=8081

# --- Log File Configuration ---
RAG_LOG_FILE="$WORKSPACE_DIR/rag_server.log"
LLAMA_LOG_FILE="$WORKSPACE_DIR/llama_server.log"
NGINX_LOG_FILE="$WORKSPACE_DIR/nginx.log"

# --- Function Definitions ---
is_running() {
  lsof -i tcp:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
}

pre_flight_checks() {
    echo "--- Running Pre-flight Checks ---"
    local all_checks_passed=true

    if [ ! -d "$REPO_DIR" ]; then
        echo "❌ CRITICAL: Repository directory not found at $REPO_DIR." >&2; all_checks_passed=false
    fi
    if [ ! -f "$VENV_PATH" ]; then
        echo "❌ CRITICAL: Python venv not found at $VENV_PATH." >&2; all_checks_passed=false
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ CRITICAL: Config file not found at $CONFIG_FILE." >&2; all_checks_passed=false
    fi
    if [ ! -f "$NGINX_CONFIG_TEMPLATE" ]; then
        echo "❌ CRITICAL: Nginx config template not found at $NGINX_CONFIG_TEMPLATE." >&2; all_checks_passed=false
    fi
    source "$CONFIG_FILE"
    MODEL_PATH_CHECK="${VESPER_MODEL_PATH:-$MODEL_PATH}"
    if [ ! -f "$MODEL_PATH_CHECK" ]; then
        echo "❌ CRITICAL: Model file not found at '$MODEL_PATH_CHECK'." >&2; all_checks_passed=false
    fi

    if [ "$all_checks_passed" = false ]; then
        echo "🔥 Pre-flight checks failed. Please resolve the issues above." >&2
        exit 1
    fi
    echo "✅ All pre-flight checks passed."
}

stop_service_on_port() {
  local port=$1
  local service_name=$2
  echo "🛑 Stopping $service_name on port $port..."
  PID=$(lsof -t -i tcp:"$port" -sTCP:LISTEN || true)
  if [ -n "$PID" ]; then
    echo "🔪 Killing process with PID: $PID"
    kill "$PID"
    sleep 2
    if is_running "$port"; then
        echo "❌ Failed to stop $service_name. Trying with KILL -9."
        kill -9 "$PID"
        sleep 2
    fi
    if is_running "$port"; then
         echo "🔥 CRITICAL: Could not kill process on port $port. Manual intervention required." >&2
         exit 1
    else
         echo "✅ $service_name stopped."
    fi
  else
    echo "🤷 No running $service_name found to stop."
  fi
}

stop_all_services() {
    echo "--- Stopping All Services ---"
    stop_service_on_port "$PUBLIC_PORT" "Nginx"
    stop_service_on_port "$INTERNAL_RAG_PORT" "RAG Server"
    stop_service_on_port "$INTERNAL_LLAMA_PORT" "LLM Server"
}

# --- Dependency & Configuration Checks ---
if ! command -v lsof &> /dev/null || ! command -v nginx &> /dev/null; then
    echo "❌ Error: 'lsof' or 'nginx' command not found. Please install them." >&2
    exit 1
fi

# --- Argument Parsing ---
RESTART_SERVICES=false
FOREGROUND_LLM=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart) RESTART_SERVICES=true; shift ;;
    --foreground-llm) FOREGROUND_LLM=true; shift ;;
    *) shift ;;
  esac
done

# --- Main Execution ---
pre_flight_checks

if [ "$RESTART_SERVICES" = true ]; then
  stop_all_services
fi

echo "--- Unified Remote Service Launcher ---"

source "$CONFIG_FILE"
MODEL_PATH="${VESPER_MODEL_PATH:-$MODEL_PATH}"
source "$VENV_PATH"

# --- Auto-compile llama-server if it doesn't exist ---
if [ ! -f "$LLAMA_SERVER_PATH" ]; then
    echo "🛠️ 'llama-server' not found. Compiling with CMake..."
    cd "$LLAMA_CPP_DIR"; mkdir -p build; cd build
    cmake .. && cmake --build .
    echo "✅ Compilation complete."; cd "$REPO_DIR"
fi

# --- Check and start RAG Memory Server ---
if is_running $INTERNAL_RAG_PORT; then
    echo "✅ RAG Server is already running on internal port $INTERNAL_RAG_PORT."
else
    echo "🧠 Starting RAG Server on internal port $INTERNAL_RAG_PORT..."
    nohup python3 "$RAG_SCRIPT_PATH" > "$RAG_LOG_FILE" 2>&1 &
    echo "⏳ Waiting for RAG server to become healthy..."
    SECONDS=0
    while ! is_running $INTERNAL_RAG_PORT; do
      if [ $SECONDS -ge 30 ]; then echo "❌ RAG server timed out. Check $RAG_LOG_FILE."; exit 1; fi
      sleep 1
    done
    echo "✅ RAG server is healthy!"
fi

# --- Check and start Main LLM Server ---
if is_running $INTERNAL_LLAMA_PORT; then
    echo "✅ Main LLM Server is already running on internal port $INTERNAL_LLAMA_PORT."
else
    echo "🧠 Launching LLM Server on internal port $INTERNAL_LLAMA_PORT..."
    LLM_COMMAND_ARGS=(
        --model "$MODEL_PATH"
        --n-gpu-layers "$GPU_LAYERS"
        --ctx-size "$CONTEXT_SIZE"
        --host "127.0.0.1"
        --port "$INTERNAL_LLAMA_PORT"
    )
    nohup "$LLAMA_SERVER_PATH" "${LLM_COMMAND_ARGS[@]}" > "$LLAMA_LOG_FILE" 2>&1 &
fi

# --- Check and start Nginx Reverse Proxy ---
if is_running $PUBLIC_PORT; then
    echo "✅ Nginx is already running on public port $PUBLIC_PORT."
else
    echo "🚀 Starting Nginx on public port $PUBLIC_PORT..."
    # Dynamically set the listening port in the Nginx config
    sed "s/listen 8080 default_server;/listen ${PUBLIC_PORT} default_server;/" "$NGINX_CONFIG_TEMPLATE" > "$TEMP_NGINX_CONFIG"
    nginx -c "$TEMP_NGINX_CONFIG" -g "error_log ${NGINX_LOG_FILE} warn;"
fi

# --- Handle Foreground Mode ---
if [ "$FOREGROUND_LLM" = true ]; then
    echo "--- Tailing LLM Server logs ---"
    touch "$LLAMA_LOG_FILE"
    tail -f "$LLAMA_LOG_FILE"
else
    echo "✅ All services are running. Connect at port $PUBLIC_PORT."
    echo "-----------------------------------------------------"
fi
