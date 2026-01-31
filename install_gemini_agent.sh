#!/bin/bash

# ==============================================================================
# Gemini Agent Installer for RunPod
# ==============================================================================

echo "✨ Initializing Gemini Agent Installation..."

# 1. Install Node.js (Prerequisite)
if ! command -v node &> /dev/null; then
    echo "📦 Node.js not found. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "✅ Node.js is already installed."
fi

# 2. Install Gemini CLI via NPM
if ! command -v gemini &> /dev/null; then
    echo "🤖 Installing @google/gemini-cli..."
    npm install -g @google/gemini-cli
else
    echo "✅ Gemini CLI is already installed."
fi

# 3. Configure Environment
# We assume the API key is passed via ENV variable 'GEMINI_API_KEY'
# or stored in a file by the user.
# Here we set a helpful alias for the 'root' user.

if ! grep -q "alias jarvis=" ~/.bashrc; then
    echo "alias jarvis='gemini'" >> ~/.bashrc
    echo "✅ Alias 'jarvis' added to .bashrc"
fi

echo "🚀 Gemini Agent is ready. Run 'gemini' or 'jarvis' to engage."
