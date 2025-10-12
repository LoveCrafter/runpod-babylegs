# AI Model Inference Project

This project runs a high-performance, open-source GGUF model and a supporting RAG memory server.

## Quick Start: Initializing the Pod

The entire environment, including the main model and the RAG memory server, is managed by a single, unified startup script.

### Instructions

1.  **Configure the Launcher:**
    Open the `start_services.sh` script and replace the placeholder values for `POD_IP` and `POD_PORT` with your RunPod instance's details.

2.  **Make the Script Executable:**
    If you haven't already, open your local terminal and run:
    ```bash
    chmod +x start_services.sh
    ```

3.  **Launch Everything:**
    Execute the script from your local terminal:
    ```bash
    ./start_services.sh
    ```

That's it. The script will handle connecting to your pod, launching both the RAG server and the main `llama-server` with optimized settings, and then provide you with the necessary `ssh` command to forward the ports for access.

---

## Advanced Information

### Included Scripts

*   `start_services.sh`: The main entry point for starting all services.
*   `run_vesper.py`: A flexible Python script for performing single-shot inference tests. Can be run on the pod after activating the venv (`source /workspace/vesper_env/bin/activate`). Use `python run_vesper.py --help` for options.
*   `build_memory.py`: The script for the RAG memory server. It is automatically launched by `start_services.sh`.

### Original Setup (For Reference)

The following instructions are for reference only and are no longer the recommended workflow.

1.  **Download Model:** Place the GGUF model files in the `/workspace/models` directory on the pod.
2.  **Setup Python Environment:**
    ```bash
    python3 -m venv /workspace/vesper_env
    source /workspace/vesper_env/bin/activate
    pip install -r requirements.txt
    ```
