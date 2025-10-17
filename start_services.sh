#!/bin/bash
set -e

# ==============================================================================
# Desktop Services Launcher for Vesper AI Pod
#
# Description:
# This script provides a single "launch button" to initialize all services
# on a remote RunPod instance from your local terminal. It will prompt for
# the Pod IP and Port, then connect and execute the remote startup script.
#
# The remote script will launch the LLM server in the foreground, streaming
# its logs to this terminal.
#
# Usage:
# ./start_services.sh
# ==============================================================================

# --- Configuration ---
# Prompt the user for the Pod IP and Port
read -p "Enter the Pod IP Address: " POD_IP
read -p "Enter the Pod SSH Port: " POD_PORT

# --- Remote Path Configuration ---
REMOTE_SCRIPT_PATH="/workspace/runpod-babylegs/start_remote_services.sh"
LLAMA_PORT="8080" # Used for the final instructions

# --- Main Execution via SSH ---
echo "🚀 Connecting to pod to launch services..."
echo "This terminal will show the output from the remote LLM server."

# Connect and execute the remote script with the --foreground-llm flag.
# The -t flag allocates a pseudo-terminal, which is required for the
# remote script to run interactively and stream logs back to us.
ssh "root@$POD_IP" -p "$POD_PORT" -t "bash $REMOTE_SCRIPT_PATH --foreground-llm"

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