#!/bin/bash
set -e

# ==============================================================================
# Unified Services Launcher for Vesper AI Pod
#
# Description:
# This script provides a single, reliable "launch button" to initialize all
# services on a remote RunPod instance from your local terminal.
#
# It accepts the Pod IP and Port as command-line arguments.
#
# Usage:
# ./start_services.sh <POD_IP_ADDRESS> <POD_PORT>
# ==============================================================================

# --- Configuration ---
# Accept Pod IP and Port from command-line arguments
if [ "$#" -ne 2 ]; then
    echo "❌ Error: Incorrect number of arguments."
    echo "Usage: $0 <POD_IP_ADDRESS> <POD_PORT>"
    exit 1
fi
POD_IP="$1"
POD_PORT="$2"

# --- Remote Path Configuration ---
# These paths are on the remote pod.
WORKSPACE_DIR="/workspace"
VENV_PATH="$WORKSPACE_DIR/vesper_env/bin/activate"
# Allow overriding the model path with an environment variable for flexibility
MODEL_PATH="${VESPER_MODEL_PATH:-$WORKSPACE_DIR/models/huihui-ai/Huihui-gpt-oss-120b-BF16-abliterated/Q4_K_M-GGUF/Q4_K_M-GGUF/Q4_K_M-GGUF-00001-of-00009.gguf}"
RAG_SCRIPT_PATH="$WORKSPACE_DIR/build_memory.py"
LLAMA_SERVER_PATH="$WORKSPACE_DIR/llama.cpp/build/bin/llama-server"

# --- Service Port Configuration ---
# These ports are on the remote pod.
RAG_PORT="5000"
LLAMA_PORT="8080"

# --- LLM Parameter Configuration (Optimized) ---
GPU_LAYERS=34
CONTEXT_SIZE=1024


# --- Main Execution via SSH Here-Document ---
echo "🚀 Connecting to pod to launch services..."
echo "This terminal will show the output from the remote server."

ssh root@$POD_IP -p $POD_PORT << EOF
  set -e
  echo "✅ Connected to pod. Activating Python environment..."
  source "$VENV_PATH"

  # --- Auto-compile llama-server if it doesn't exist ---
  if [ ! -f "$LLAMA_SERVER_PATH" ]; then
    echo "🛠️ 'llama-server' not found. Compiling llama.cpp... (This may take several minutes)"
    cd /workspace/llama.cpp
    make
    echo "✅ Compilation complete."
  fi

  # --- Launch RAG Memory Server (in the background) ---
  echo "🧠 Starting RAG Memory Server on port $RAG_PORT..."
  nohup python3 "$RAG_SCRIPT_PATH" > "$WORKSPACE_DIR/rag_server.log" 2>&1 &
  # --- Wait for RAG Server to be healthy ---
  echo "⏳ Waiting for RAG server to become healthy..."
  SECONDS=0
  while true; do
    # Use curl to check the health endpoint. The server is ready when it returns a 200 status.
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${RAG_PORT}/")

    if [ "$STATUS" -eq 200 ]; then
      echo "✅ RAG server is healthy!"
      break
    fi

    if [ $SECONDS -ge 30 ]; then
      echo "❌ RAG server did not become healthy within 30 seconds. Check rag_server.log for errors."
      exit 1
    fi

    sleep 1
  done

  # --- Launch Main LLM Server (in the foreground) ---
  echo "🧠 Launching Main LLM Server on port $LLAMA_PORT with optimized settings..."
  "$LLAMA_SERVER_PATH" \
    --model "$MODEL_PATH" \
    --n-gpu-layers $GPU_LAYERS \
    --ctx-size $CONTEXT_SIZE \
    --host 0.0.0.0 \
    --port $LLAMA_PORT

  echo "✅ Server processes have been launched on the pod."
EOF


# --- Final Instructions for User ---
echo -e "\n\n"
echo "✅ Service launch sequence initiated on the pod."
echo "The terminal above is now streaming logs from the main LLM server."
echo "------------------------------------------------------------------"
echo "➡️  NEXT STEP: Open a NEW local terminal and run this command to"
echo "   access the main LLM server:"
echo "------------------------------------------------------------------"
echo ""
echo "ssh -L $LLAMA_PORT:127.0.0.1:$LLAMA_PORT root@$POD_IP -p $POD_PORT"
echo ""
echo "You will then be able to interact with the model at http://localhost:$LLAMA_PORT"
echo ""
echo "To access the RAG memory server (e.g., for diagnostics), use this command in a third terminal:"
echo "ssh -L $RAG_PORT:127.0.0.1:$RAG_PORT root@$POD_IP -p $POD_PORT"
echo ""
