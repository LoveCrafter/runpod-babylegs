#!/bin/bash
set -e

# ==============================================================================
# Vesper Bootstrap Wrapper (Hotfix V3.1)
# ==============================================================================

echo "--- Vesper Bootstrap Sequence Initiated ---"

# --- 1. SYSTEM AUDIT & INSTALL ---
echo "🔍 Phase 1: System Audit..."
if ! command -v tailscale &> /dev/null; then
    echo "⬇️  Tailscale not found. Installing..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Ensure system tools are present (fixes "command not found" errors)
MISSING_PACKAGES=0
for pkg in nginx lsof cmake build-essential libcurl4-openssl-dev; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PACKAGES=1
        break
    fi
done

if [ $MISSING_PACKAGES -eq 1 ]; then
    echo "⬇️  Installing missing system packages..."
    apt-get update
    apt-get install -y nginx lsof cmake build-essential libcurl4-openssl-dev
fi

# --- 2. PYTHON ENVIRONMENT (The Surgical Fix) ---
echo "🐍 Phase 2: Python Environment Repair..."

REPO_DIR=$(pwd)
VENV_DIR="vesper_env"
VENV_PATH="$REPO_DIR/$VENV_DIR/bin/activate"

# ALWAYS run with --upgrade. This fixes broken symlinks instantly.
# It does NOT delete your installed libraries (tqdm, torch, etc).
echo "🛠️  Ensuring virtual environment is linked to current Python..."
python3 -m venv --upgrade "$VENV_DIR"

echo "🔌 Activating virtual environment..."
source "$VENV_PATH"

echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Priority installs (Fast checks)
pip install open-webui gguf
pip install hf_transfer tqdm lancedb orjson sentence-transformers

# --- 3. EXECUTION HANDOFF ---
echo "🚀 Phase 3: Handoff to Engine..."
chmod +x ./start_remote_services.sh
exec ./start_remote_services.sh "$@"
