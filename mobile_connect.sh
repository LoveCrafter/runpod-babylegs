#!/bin/bash
set -e

# ==============================================================================
# Mobile Connect Script for Vesper AI Pod
#
# Description:
# This script is designed for a one-tap launch from a mobile SSH client like
# Termius. It connects to the remote pod, ensures all services are running,
# and establishes a persistent SSH tunnel to the main LLM server.
#
# This allows you to interact with the model from your mobile browser at
# http://localhost:8080 after running.
#
# Usage (in Termius or any SSH client):
# ./mobile_connect.sh <YOUR_POD_IP> <YOUR_POD_PORT>
#
# Example:
# ./mobile_connect.sh 216.81.245.97 11114
# ==============================================================================

# --- Argument Validation ---
if [ "$#" -ne 2 ]; then
    echo "❌ Error: Missing arguments."
    echo "Usage: $0 <POD_IP> <POD_PORT>"
    exit 1
fi

POD_IP=$1
POD_PORT=$2

# --- Remote Configuration ---
# This is the local port on your mobile device that will be forwarded.
LOCAL_PORT="8080"
# This is the port the llama-server is listening on inside the pod.
REMOTE_PORT="8080"
# Path to the remote launcher script on the pod.
REMOTE_SCRIPT_PATH="/workspace/runpod-babylegs/start_remote_services.sh"

# --- Main Execution ---
echo "🚀 Initiating mobile connection to Vesper..."
echo "This will start remote services and create an SSH tunnel."
echo "Once connected, access the model at http://localhost:$LOCAL_PORT on your device's browser."
echo "Press Ctrl+C in this terminal to close the connection."

# Connect, execute the remote script, and establish the port forward.
# -L: Forwards the local port to the remote port.
# -N: Do not execute a remote command (after the initial script runs). This keeps the tunnel open.
# -t: Force pseudo-terminal allocation to run the remote script.
ssh -L "$LOCAL_PORT:127.0.0.1:$REMOTE_PORT" "root@$POD_IP" -p "$POD_PORT" -t "bash $REMOTE_SCRIPT_PATH"

echo "✅ Connection closed."