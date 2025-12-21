#!/bin/bash
set -e

# ==============================================================================
# Vesper Bootstrap Wrapper (Idempotent Overlord)
#
# Description:
# This script is designed to run on a fresh RunPod instance. It performs a
# system audit, handles dependency hell by prioritizing OpenWebUI and unpinning
# other requirements, and then hands off control to start_remote_services.sh.
#
# Usage:
# ./bootstrap_vesper.sh [arguments for start_remote_services.sh]
# ==============================================================================

echo "--- Vesper Bootstrap Sequence Initiated ---"

# --- 1. SYSTEM AUDIT & INSTALL (Idempotent) ---
echo "🔍 Phase 1: System Audit..."

# Check Tailscale
if ! command -v tailscale &> /dev/null; then
    echo "⬇️  Tailscale not found. Installing..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "✅ Tailscale is installed."
fi

# Check Nginx
if ! command -v nginx &> /dev/null; then
    echo "⬇️  Nginx not found. Installing..."
    apt-get update && apt-get install -y nginx
else
    echo "✅ Nginx is installed."
fi

# --- 2. PYTHON DEPENDENCY STRATEGY (The "Unpinning" Fix) ---
echo "🐍 Phase 2: Python Dependency Resolution..."

REPO_DIR=$(pwd)
VENV_DIR="vesper_env"
VENV_PATH="$REPO_DIR/$VENV_DIR/bin/activate"

# Ensure venv exists
if [ ! -f "$VENV_PATH" ]; then
    echo "🛠️  Creating virtual environment '$VENV_DIR'..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv
echo "🔌 Activating virtual environment..."
source "$VENV_PATH"

echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Priority 1: OpenWebUI (Let it claim dependencies)
echo "📦 Installing OpenWebUI (Priority 1)..."
pip install open-webui

# Priority 2: GGUF (Explicit fix for calculate_context.py)
echo "📦 Installing GGUF (Priority 2 - Critical Fix)..."
pip install gguf

# Priority 3: Remaining requirements (Unpinned)
echo "📦 Installing remaining requirements (Unpinned)..."
if [ -f "requirements.txt" ]; then
    # Create unpinned requirements file
    # Removes ==version and >=version
    sed -E 's/==[^ ]+//g; s/>=[^ ]+//g' requirements.txt > requirements.unpinned.txt

    echo "📄 Generated requirements.unpinned.txt from requirements.txt"
    pip install -r requirements.unpinned.txt

    # Clean up
    rm requirements.unpinned.txt
else
    echo "⚠️  requirements.txt not found!"
fi

# --- 3. EXECUTION HANDOFF ---
echo "🚀 Phase 3: Handoff to Engine..."

START_SCRIPT="./start_remote_services.sh"

if [ -f "$START_SCRIPT" ]; then
    chmod +x "$START_SCRIPT"
    echo "⏩ Executing $START_SCRIPT..."
    exec "$START_SCRIPT" "$@"
else
    echo "❌ CRITICAL: $START_SCRIPT not found!"
    exit 1
fi
