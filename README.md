# AI Model Inference Project

This project runs a high-performance, open-source GGUF model and a supporting RAG memory server.

## Quick Start: Initializing the Pod

The entire environment, including the main model and the RAG memory server, is managed by a single, unified startup script. Please follow the instructions for your operating system.

### Instructions for macOS and Linux

1.  **Configure the Launcher:**
    Open the `start_services.sh` script and replace the placeholder values for `POD_IP` and `POD_PORT` with your RunPod instance's details.

2.  **Make the Script Executable:**
    Open your terminal and run:
    ```bash
    chmod +x start_services.sh
    ```

3.  **Launch Everything:**
    Execute the script from your terminal:
    ```bash
    ./start_services.sh
    ```

### Instructions for Windows (PowerShell)

1.  **Configure the Launcher:**
    Open the `start_services.ps1` script in a text editor and replace the placeholder values for `$PodIp` and `$PodPort` with your RunPod instance's details.

2.  **Launch Everything:**
    Open PowerShell, navigate to the project directory, and run the script:
    ```powershell
    .\start_services.ps1
    ```

After running the script, it will guide you through the final steps for port-forwarding to access the chat interface in your browser.

---

## Advanced Information

### Core Components

*   **`start_services.sh` / `start_services.ps1`**: The primary entry point for launching the entire environment. This script starts the main, high-performance C++ model server (`llama-server`) and the RAG memory server. This is the recommended way to run the project.
*   **`build_memory.py`**: The script for the RAG memory server. It's launched automatically by the `start_services` scripts and does not need to be run manually.

### Utility Scripts

*   **`run_vesper.py`**: A flexible Python command-line utility for performing single-shot inference tests. This is useful for quick, one-off model checks but is **not** part of the main persistent server environment.
