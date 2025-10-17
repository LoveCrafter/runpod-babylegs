# ==============================================================================
# Desktop Services Launcher for Vesper AI Pod (PowerShell Edition)
#
# Description:
# This script provides a single "launch button" to initialize all services
# on a remote RunPod instance from your local Windows terminal. It will prompt
# for the Pod IP and Port, then connect and execute the remote startup script.
#
# The remote script will launch the LLM server in the foreground, streaming
# its logs to this terminal.
#
# Usage:
# .\start_services.ps1
# ==============================================================================

# --- Configuration ---
# Prompt the user for the Pod IP and Port
$PodIp = Read-Host "Enter the Pod IP Address"
$PodPort = Read-Host "Enter the Pod SSH Port"

# --- Remote Path Configuration ---
$RemoteScriptPath = "/workspace/runpod-babylegs/start_remote_services.sh"
$LlamaPort = "8080" # Used for the final instructions

# --- Main Execution Block ---
Write-Host "🚀 Connecting to pod to launch services..." -ForegroundColor Green
Write-Host "This terminal will show the output from the remote LLM server."

# The -t flag allocates a pseudo-terminal, which is required for the
# remote script to run interactively and stream logs back to us.
ssh "root@$PodIp" -p $PodPort -t "bash $RemoteScriptPath --foreground-llm"

# --- Final Instructions for User ---
Write-Host "`n`n"
Write-Host "✅ Service launch sequence initiated on the pod." -ForegroundColor Green
Write-Host "The terminal above is now streaming logs from the main LLM server."
Write-Host "------------------------------------------------------------------"
Write-Host "➡️  NEXT STEP: Open a NEW PowerShell terminal and run this command to" -ForegroundColor Yellow
Write-Host "   access the main LLM server:"
Write-Host "------------------------------------------------------------------"
Write-Host ""
Write-Host "ssh -L $LlamaPort:127.0.0.1:$LlamaPort root@$PodIp -p $PodPort"
Write-Host ""
Write-Host "You can then interact with the model at http://localhost:$LlamaPort"
Write-Host ""