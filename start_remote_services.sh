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

# --- Global VRAM Protection (The "Global Blackout") ---
# Whitelist Strategy: Capture keys to the Kingdom (GPUs) then blind everyone else.
if [ -z "${CUDA_VISIBLE_DEVICES+x}" ]; then
    # Variable is unset (default = all GPUs). We will need to UNSET it to restore access.
    PRIVILEGED_GPU_CMD="env -u CUDA_VISIBLE_DEVICES"
else
    # Variable is set. We restore exactly this value.
    PRIVILEGED_GPU_CMD="env CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"
fi

# Apply Global Blackout: Hide GPUs from ALL future processes by default.
export CUDA_VISIBLE_DEVICES=""
echo "🛡️  VRAM Protection Active: Global GPU Blackout applied. Only privileged processes will see GPUs."

# --- Path and Environment Configuration ---
WORKSPACE_DIR="/workspace"
REPO_DIR="$WORKSPACE_DIR/runpod-babylegs"
VENV_PATH="$REPO_DIR/vesper_env/bin/activate"
PYTHON_EXEC="$REPO_DIR/vesper_env/bin/python3"
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

# --- OpenWebUI Defaults ---
ENABLE_OPENWEBUI="${ENABLE_OPENWEBUI:-false}"
OPENWEBUI_PORT="${OPENWEBUI_PORT:-3000}"
OPENWEBUI_DATA_DIR="$WORKSPACE_DIR/open-webui-data"

# --- Log File Configuration ---
RAG_LOG_FILE="$WORKSPACE_DIR/rag_server.log"
LLAMA_LOG_FILE="$WORKSPACE_DIR/llama_server.log"
OPENWEBUI_LOG_FILE="$WORKSPACE_DIR/open-webui.log"
NGINX_LOG_FILE="$WORKSPACE_DIR/nginx.log"

# --- Function Definitions ---
is_running() {
  lsof -i tcp:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
}

setup_tailscale() {
    if [ -n "$TAILSCALE_AUTH_KEY" ]; then
        echo "🔌 Tailscale configuration detected."

        # 1. Install Tailscale if missing
        if ! command -v tailscale &> /dev/null; then
            echo "⬇️  Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
        fi

        # 2. Start tailscaled if not running
        if ! pgrep tailscaled > /dev/null; then
             echo "⚙️  Starting tailscaled manually..."
             # Ensure directories exist
             mkdir -p /var/run/tailscale /var/lib/tailscale
             # Start daemon in userspace networking mode (best for containers)
             tailscaled --state=/var/lib/tailscale/tailscaled.state \
                        --socket=/var/run/tailscale/tailscaled.sock \
                        --tun=userspace-networking &
             sleep 3
        fi

        # 3. Authenticate
        TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-vesper-pod}"
        echo "🔗 Connecting to Tailscale as '$TAILSCALE_HOSTNAME'..."
        # --ssh enables Tailscale SSH access
        tailscale up --authkey="$TAILSCALE_AUTH_KEY" --hostname="$TAILSCALE_HOSTNAME" --ssh --accept-routes

        TS_IP=$(tailscale ip -4)
        echo "✅ Tailscale connected. You can SSH to: root@$TS_IP"
    fi
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
        if [ -f "$REPO_DIR/vesper.conf.example" ]; then
            echo "⚠️  Config file not found. Creating '$CONFIG_FILE' from example..."
            cp "$REPO_DIR/vesper.conf.example" "$CONFIG_FILE"
        else
            echo "❌ CRITICAL: Config file not found at $CONFIG_FILE." >&2; all_checks_passed=false
        fi
    fi
    if [ ! -f "$NGINX_CONFIG_TEMPLATE" ]; then
        echo "❌ CRITICAL: Nginx config template not found at $NGINX_CONFIG_TEMPLATE." >&2; all_checks_passed=false
    fi
    source "$CONFIG_FILE"

    # --- Smart Model Discovery ---
    # 1. Check configured path
    local configured_model="${VESPER_MODEL_PATH:-$MODEL_PATH}"
    if [ -f "$configured_model" ]; then
        MODEL_PATH="$configured_model"
        echo "✅ Found configured model at: $MODEL_PATH"
    else
        echo "⚠️  Configured model not found at '$configured_model'. Searching workspace..."
        # 2. Search for any GGUF > 20GB in workspace
        local found_model=$(find "$WORKSPACE_DIR" -maxdepth 4 -name "*.gguf" -size +20G -print -quit)
        if [ -n "$found_model" ]; then
            MODEL_PATH="$found_model"
            echo "🎉 Smart Discovery found existing model: $MODEL_PATH"
        else
            echo "❌ CRITICAL: No model file found (checked config and workspace search)." >&2
            all_checks_passed=false
        fi
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
    stop_service_on_port "$OPENWEBUI_PORT" "OpenWebUI"
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
# Ensure MODEL_PATH is exported if it was updated by pre_flight_checks
export MODEL_PATH

source "$VENV_PATH"

# --- Dynamic Context Calculation ---
CALC_SCRIPT="$REPO_DIR/calculate_context.py"
if [ -f "$CALC_SCRIPT" ]; then
    echo "🧮 Calculating optimal context size based on VRAM..."
    # Run the python script, capturing stdout. Stderr goes to terminal.
    # PRIVILEGED: Needs GPU access to query VRAM via nvidia-smi
    # Use explicit python executable
    CALCULATED_CTX=$($PRIVILEGED_GPU_CMD "$PYTHON_EXEC" "$CALC_SCRIPT" "$MODEL_PATH")
    RET_CODE=$?

    if [ $RET_CODE -eq 0 ] && [[ "$CALCULATED_CTX" =~ ^[0-9]+$ ]]; then
        echo "✅ Dynamic Context Size: $CALCULATED_CTX (Overrides config: $CONTEXT_SIZE)"
        CONTEXT_SIZE="$CALCULATED_CTX"
    else
        echo "⚠️  Context calculation failed. Using config value: $CONTEXT_SIZE"
    fi
else
    echo "⚠️  Calculation script not found. Using config value: $CONTEXT_SIZE"
fi

# --- Setup Tailscale (Optional) ---
setup_tailscale

# --- Auto-clone and Auto-compile llama-server ---
if [ ! -d "$LLAMA_CPP_DIR/.git" ]; then
    echo "🛠️ 'llama.cpp' source not found. Cloning from upstream..."
    # If directory exists but isn't a git repo (e.g. empty dir), remove it to allow clone
    if [ -d "$LLAMA_CPP_DIR" ]; then rm -rf "$LLAMA_CPP_DIR"; fi
    git clone https://github.com/ggerganov/llama.cpp "$LLAMA_CPP_DIR"
fi

if [ ! -f "$LLAMA_SERVER_PATH" ]; then
    echo "🛠️ 'llama-server' binary not found. Compiling with CMake..."
    cd "$LLAMA_CPP_DIR"
    mkdir -p build
    cd build
    # Constraint: Must use -DGGML_CUDA=ON
    cmake .. -DGGML_CUDA=ON
    cmake --build . --config Release -j$(nproc)
    echo "✅ Compilation complete."
    cd "$REPO_DIR"
fi

# --- Check and start RAG Memory Server ---
if is_running $INTERNAL_RAG_PORT; then
    echo "✅ RAG Server is already running on internal port $INTERNAL_RAG_PORT."
else
    echo "🧠 Starting RAG Server on internal port $INTERNAL_RAG_PORT..."

    # Security: Generate a random API secret if one isn't provided
    if [ -z "$API_SECRET" ]; then
        echo "🔑 Generating ephemeral API Secret for RAG Server..."
        export API_SECRET=$(openssl rand -hex 32)
    fi

    # Optimization: Force RAG to CPU to reserve VRAM for the 120B model
    echo "🔧 Forcing RAG embeddings to CPU to save VRAM..."
    export RAG_DEVICE="cpu"

    # (Global Blackout applies here automatically)
    # Use explicit python executable
    nohup "$PYTHON_EXEC" "$RAG_SCRIPT_PATH" > "$RAG_LOG_FILE" 2>&1 &
    echo "⏳ Waiting for RAG server to become healthy..."
    SECONDS=0
    # Timeout increased to 600s as requested
    while ! is_running $INTERNAL_RAG_PORT; do
      if [ $SECONDS -ge 600 ]; then echo "❌ RAG server timed out. Check $RAG_LOG_FILE."; exit 1; fi
      sleep 1
    done
    echo "✅ RAG server is healthy!"
fi

# --- Check and start Main LLM Server ---
if is_running $INTERNAL_LLAMA_PORT; then
    echo "✅ Main LLM Server is already running on internal port $INTERNAL_LLAMA_PORT."
else
    echo "🧠 Launching LLM Server on internal port $INTERNAL_LLAMA_PORT..."

    # Detect GPU count for auto-optimization
    GPU_COUNT=$(nvidia-smi -L 2>/dev/null | wc -l)
    echo "🔍 Detected $GPU_COUNT GPU(s)."

    LLM_COMMAND_ARGS=(
        --model "$MODEL_PATH"
        --n-gpu-layers "$GPU_LAYERS"
        --ctx-size "$CONTEXT_SIZE"
        --host "127.0.0.1"
        --port "$INTERNAL_LLAMA_PORT"
    )

    if [ "$GPU_COUNT" -gt 1 ]; then
        echo "⚡ Multi-GPU detected! Enabling split-mode row."
        LLM_COMMAND_ARGS+=(--split-mode row)
    fi

    # PRIVILEGED: This is the Model Engine. It gets the keys to the Kingdom.
    nohup $PRIVILEGED_GPU_CMD "$LLAMA_SERVER_PATH" "${LLM_COMMAND_ARGS[@]}" > "$LLAMA_LOG_FILE" 2>&1 &
fi

# --- Check and start OpenWebUI (Optional) ---
if [ "$ENABLE_OPENWEBUI" = "true" ]; then
    if is_running "$OPENWEBUI_PORT"; then
        echo "✅ OpenWebUI is already running on port $OPENWEBUI_PORT."
    else
        echo "🌐 Starting OpenWebUI on port $OPENWEBUI_PORT..."
        mkdir -p "$OPENWEBUI_DATA_DIR"

        # OpenWebUI Environment Variables
        export PORT="$OPENWEBUI_PORT"
        export DATA_DIR="$OPENWEBUI_DATA_DIR"
        export OPENAI_API_BASE_URL="http://127.0.0.1:$INTERNAL_LLAMA_PORT/v1"
        export OPENAI_API_KEY="sk-no-key-required"
        # Prevent auto-opening browser
        export WEBUI_AUTH="True"

        # (Global Blackout applies here automatically)
        nohup open-webui serve > "$OPENWEBUI_LOG_FILE" 2>&1 &

        # Wait for OpenWebUI to start (it can be slow)
        echo "⏳ Waiting for OpenWebUI to initialize..."
        SECONDS=0
        while ! is_running "$OPENWEBUI_PORT"; do
            if [ $SECONDS -ge 60 ]; then
                echo "⚠️  OpenWebUI taking a long time to start. Check $OPENWEBUI_LOG_FILE. Continuing..."
                break
            fi
            sleep 1
        done
    fi
fi

# --- Check and start Nginx Reverse Proxy ---
if is_running $PUBLIC_PORT; then
    echo "✅ Nginx is already running on public port $PUBLIC_PORT."
else
    echo "🚀 Starting Nginx on public port $PUBLIC_PORT..."
    # Dynamically set the listening port in the Nginx config
    sed "s/listen 8080 default_server;/listen ${PUBLIC_PORT} default_server;/" "$NGINX_CONFIG_TEMPLATE" > "$TEMP_NGINX_CONFIG"

    # If OpenWebUI is enabled, hijack the root route upstream
    if [ "$ENABLE_OPENWEBUI" = "true" ]; then
        echo "🔀 Routing public traffic to OpenWebUI..."
        sed -i "s/server 127.0.0.1:$INTERNAL_LLAMA_PORT;/server 127.0.0.1:$OPENWEBUI_PORT;/" "$TEMP_NGINX_CONFIG"
    fi

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
