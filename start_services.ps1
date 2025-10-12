# ==============================================================================
# Unified Services Launcher for Vesper AI Pod (PowerShell Edition)
#
# Description:
# This script provides a single, reliable entry point for Windows users to
# launch all necessary services for the AI model on a remote RunPod instance.
#
# Instructions:
# 1.  Fill in your Pod's IP Address and Port in the Configuration section below.
# 2.  Open PowerShell and navigate to the directory containing this script.
# 3.  Run the script:
#     .\start_services.ps1
# 4.  The script will guide you through the next steps for port-forwarding.
# ==============================================================================

# --- Configuration ---
# Replace with your pod's actual connection details
$PodIp = "<YOUR_POD_IP_ADDRESS>"
$PodPort = "<YOUR_POD_PORT>"

if ($PodIp -eq "<YOUR_POD_IP_ADDRESS>" -or $PodPort -eq "<YOUR_POD_PORT>") {
  Write-Host "❌ Error: Please replace the placeholder values for PodIp and PodPort in the script before running." -ForegroundColor Red
  exit 1
}

# --- Remote Path Configuration ---
$WorkspaceDir = "/workspace"
$VenvPath = "$WorkspaceDir/vesper_env/bin/activate"
# Allow overriding the model path with an environment variable for flexibility
$DefaultModelPath = "$WorkspaceDir/models/huihui-ai/Huihui-gpt-oss-120b-BF16-abliterated/Q4_K_M-GGUF/Q4_K_M-GGUF/Q4_K_M-GGUF-00001-of-00009.gguf"
$ModelPath = if ($env:VESPER_MODEL_PATH) { $env:VESPER_MODEL_PATH } else { $DefaultModelPath }
$RagScriptPath = "$WorkspaceDir/build_memory.py"
$LlamaServerPath = "$WorkspaceDir/llama.cpp/build/bin/llama-server"

# --- Service Port Configuration ---
$RagPort = "5000"
$LlamaPort = "8080"

# --- LLM Parameter Configuration (Optimized) ---
$GpuLayers = 34
$ContextSize = 1024


# --- Main Execution Block ---
Write-Host "🚀 Connecting to pod to launch services..." -ForegroundColor Green
Write-Host "This terminal will show the output from the remote server."

# Define the block of commands to be executed on the remote server
$SshCommands = @"
echo "✅ Connected to pod. Activating Python environment..."
source "$VenvPath"

echo "🧠 Starting RAG Memory Server on port $RagPort..."
nohup python3 "$RagScriptPath" > "$WorkspaceDir/rag_server.log" 2>&1 &
# --- Wait for RAG Server to be healthy ---
echo "⏳ Waiting for RAG server to become healthy..."
SECONDS=0
while true; do
  # Use curl to check the health endpoint. The server is ready when it returns a 200 status.
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${RagPort}/")

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

echo "🧠 Launching Main LLM Server on port $LlamaPort with optimized settings..."
"$LlamaServerPath" --model "$ModelPath" --n-gpu-layers $GpuLayers --ctx-size $ContextSize --host 0.0.0.0 --port $LlamaPort

echo "✅ Server processes have been launched on the pod."
"@

# Execute the commands on the remote pod by piping the command block to the SSH client
$SshCommands | ssh "root@$PodIp" -p $PodPort


# --- Final Instructions for User ---
Write-Host "`n`n"
Write-Host "✅ Service launch sequence initiated on the pod." -ForegroundColor Green
Write-Host "The terminal above is now streaming logs from the main LLM server."
Write-Host "------------------------------------------------------------------"
Write-Host "➡️  NEXT STEP: Open a NEW PowerShell terminal and run this command to" -ForegroundColor Yellow
Write-Host "   access the main LLM server:"
Write-Host "------------------------------------------------------------------"
Write-Host ""
Write-Host "ssh -L $LlamaPort`:localhost:$LlamaPort root@$PodIp -p $PodPort"
Write-Host ""
Write-Host "You can then interact with the model at http://localhost:$LlamaPort"
Write-Host ""
Write-Host "To access the RAG memory server (e.g., for diagnostics), use:"
Write-Host "ssh -L $RagPort`:localhost:$RagPort root@$PodIp -p $PodPort"
Write-Host ""
