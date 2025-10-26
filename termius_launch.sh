#!/bin/bash
set -e

# ==============================================================================
# Termius One-Tap Launcher for Vesper AI Pod
#
# Description:
# This script is designed to be used as a startup snippet in an SSH client
# like Termius. It fully automates the process of keeping the pod's code
# up-to-date and launching all necessary services.
#
# What it does:
# 1. Navigates to the project directory.
# 2. Fetches the latest updates from the 'master' branch on GitHub.
# 3. Force-resets the local repository to match the remote, ensuring a
#    clean, up-to-date state.
# 4. Executes the main remote services script to start the RAG and LLM
#    servers in the background.
#
# Usage:
# Set this script as the "Startup Snippet" for your pod's host entry in
# Termius. No arguments are needed.
# ==============================================================================

# --- Configuration ---
REPO_DIR="/workspace/runpod-babylegs"
REMOTE_LAUNCH_SCRIPT="./start_remote_services.sh"

# --- Main Execution ---
echo "--- Termius Auto-Launch Sequence Initiated ---"

# 1. Navigate to the repository directory
echo " cd $REPO_DIR"
cd "$REPO_DIR"

# 2. Fetch the latest changes from the remote repository
echo "git fetch origin"
git fetch origin

# 3. Reset the local branch to match the remote 'master'
echo "git reset --hard origin/master"
git reset --hard origin/master

# 4. Launch the main services
echo "$REMOTE_LAUNCH_SCRIPT"
# The script is executed without any flags, so it will run services
# in the background and disconnect cleanly.
"$REMOTE_LAUNCH_SCRIPT"

echo "✅ Termius launch sequence complete. Services are running."
echo "--------------------------------------------------------"
