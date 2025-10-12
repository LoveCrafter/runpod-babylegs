#!/bin/bash

# ==============================================================================
# Unified Services Launcher for Vesper AI Pod
#
# Description:
# This script provides a single, reliable entry point to launch all necessary
# services for the AI model, including the RAG memory server and the main
# llama-server. It is designed to be run from your local machine to initialize
# a remote RunPod instance.
#
# Instructions:
# 1.  Fill in your Pod's IP Address and Port in the Configuration section below.
# 2.  Make this script executable:
#     chmod +x start_services.sh
# 3.  Run the script from your local terminal:
#     ./start_services.sh
# 4.  The script will handle launching the services on the pod and will provide
#     you with the necessary port-forwarding command to run in a new terminal.
# ==============================================================================

# --- Configuration ---
# Replace with your pod's actual connection details
POD_IP="<YOUR_POD_IP_ADDRESS>"
POD_PORT="<YOUR_POD_PORT>"

# --- Remote Path Configuration ---
# These paths are on the remote pod.
WORKSPACE_DIR="/workspace"
VENV_PATH="$WORKSPACE_DIR/vesper_env/bin/activate"
MODEL_PATH="$WORKSPACE_DIR/models/huihui-ai/Huihui-gpt-oss-120b-BF16-abliterated/Q4_K_M-GGUF/Q4_K_M-GGUF/Q4_K_M-GGUF-00001-of-00009.gguf"
RAG_SCRIPT_PATH="$WORKSPACE_DIR/build_memory.py"
LLAMA_SERVER_PATH="$WORKSPACE_DIR/llama.cpp/build/bin/llama-server"

# --- Service Port Configuration ---
# These ports are on the remote pod.
RAG_PORT="5000"
LLAMA_PORT="8080"

# --- LLM Parameter Configuration (Optimized) ---
# These are the high-performance settings we've tuned.
# NOTE: The model (81.8GB) is slightly larger than the H100's VRAM (80GB).
# Offloading 33 of 36 layers to the GPU provides the best performance while
# leaving a buffer to prevent "out of memory" errors.
GPU_LAYERS=33
GPU_LAYERS=-1    # -1 offloads all possible layers to the GPU
CONTEXT_SIZE=1024 # Optimized for reduced VRAM usage


# --- Main Execution via SSH Here-Document ---
echo "🚀 Connecting to pod to launch services..."
echo "This terminal will show the output from the remote server."

ssh root@$POD_IP -p $POD_PORT << EOF
  # All commands until 'EOF' are executed on the remote server.

  echo "✅ Connected to pod. Activating Python environment..."
  source "$VENV_PATH"

  # --- Launch RAG Memory Server (in the background) ---
  echo "🧠 Starting RAG Memory Server on port $RAG_PORT..."
  # Use nohup to ensure the process keeps running even if the shell closes.
  # Redirect stdout/stderr to a log file to capture output.
  nohup python3 "$RAG_SCRIPT_PATH" > "$WORKSPACE_DIR/rag_server.log" 2>&1 &
  # Brief pause to allow the server to initialize
  sleep 5

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
echo "ssh -L $LLAMA_PORT:localhost:$LLAMA_PORT root@$POD_IP -p $POD_PORT"
echo ""
echo "You can then interact with the model at http://localhost:$LLAMA_PORT"
echo ""
echo "To access the RAG memory server (e.g., for diagnostics), use:"
echo "ssh -L $RAG_PORT:localhost:$RAG_PORT root@$POD_IP -p $POD_PORT"
echo ""
