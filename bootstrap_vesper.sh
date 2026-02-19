#!/bin/bash
set -e

# ==============================================================================
# Vesper Bootstrap Wrapper (Hotfix V3.2)
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

if [ "$MISSING_PACKAGES" -eq 1 ]; then
    echo "⬇️  Installing missing system packages..."
    apt-get update
    apt-get install -y nginx lsof cmake build-essential libcurl4-openssl-dev
fi

# --- 2. PYTHON ENVIRONMENT (The Surgical Fix) ---
echo "🐍 Phase 2: Python Environment Repair..."

REPO_DIR=$(pwd)
VENV_DIR="vesper_env"
VENV_PATH="$REPO_DIR/$VENV_DIR/bin/activate"
VENV_PYTHON="$REPO_DIR/$VENV_DIR/bin/python3"

# ALWAYS run with --upgrade. This fixes broken symlinks instantly.
# It does NOT delete your installed libraries (tqdm, torch, etc).
echo "🛠️  Ensuring virtual environment is linked to current Python..."
python3 -m venv --upgrade "$VENV_DIR"

echo "🔌 Activating virtual environment..."
source "$VENV_PATH"

echo "⬆️  Ensuring pip is available..."
"$VENV_PYTHON" -m ensurepip --upgrade --default-pip
"$VENV_PYTHON" -m pip install --upgrade pip setuptools wheel

if [ -f "$REPO_DIR/requirements.txt" ]; then
    echo "📦 Installing Python dependencies from requirements.txt..."
    "$VENV_PYTHON" -m pip install -r "$REPO_DIR/requirements.txt"
fi

# --- 3. GEMINI AGENT (JARVIS) INSTALLATION ---
echo "🤖 Phase 3: Gemini Agent Installation..."

# Node.js check & install (Prerequisite for Gemini CLI)
if ! command -v node &> /dev/null; then
    echo "📦 Node.js not found. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# Install Gemini CLI via NPM
if ! command -v gemini &> /dev/null; then
    echo "🤖 Installing @google/gemini-cli..."
    npm install -g @google/gemini-cli
fi

# Set up 'jarvis' alias if not present
if ! grep -q "alias jarvis=" ~/.bashrc; then
    echo "alias jarvis='gemini'" >> ~/.bashrc
    echo "✅ Alias 'jarvis' added to .bashrc"
fi

# --- 4. EXECUTION HANDOFF ---
echo "🚀 Phase 4: Handoff to Engine..."
chmod +x ./start_remote_services.sh
exec ./start_remote_services.sh "$@"
