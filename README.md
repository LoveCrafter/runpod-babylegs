# AI Model Inference Project

## Project Overview

This project provides a comprehensive environment for running a high-performance, open-source GGUF model and a supporting RAG memory server. It is designed to be run on a remote RunPod instance and managed from your local machine.

The core of the project is the `start_services.sh` script, which automates the setup and launch of all necessary services, including the main `llama-server` and the RAG memory server.

## Quick Start: Initializing the Pod

These instructions will guide you through the process of setting up and launching the project on a RunPod instance.

### Prerequisites

1.  **Clone this repository** to your local machine.
2.  **Download the Model:** Download the 82 GB GGUF model file and place it in a directory named `models/`. For sharded models (multiple `.gguf` files), ensure all parts are in the same directory.
3.  **Setup Python Environment:** Create and activate a virtual environment, and install the required packages:
    ```bash
    python3 -m venv vesper_env
    source vesper_env/bin/activate
    pip install -r requirements.txt
    ```

### Launching the Services

1.  **Configure the Launcher:**
    Open the `start_services.sh` script and replace the placeholder values for `POD_IP` and `POD_PORT` with your RunPod instance's details.

2.  **Make the Script Executable:**
    Open your local terminal and run:
    ```bash
    chmod +x start_services.sh
    ```

3.  **Launch Everything:**
    Execute the script from your local terminal:
    ```bash
    ./start_services.sh
    ```

That's it! The script will connect to your pod, launch the RAG server and the `llama-server`, and provide you with the necessary `ssh` command to forward the ports for access.

---

## Advanced Information

### Core Components

*   **`start_services.sh`**: The primary entry point for launching the entire environment. This script starts the main, high-performance C++ model server (`llama-server`) and the RAG memory server. This is the recommended way to run the project.
*   **`build_memory.py`**: The script for the RAG memory server. It's launched automatically by the `start_services.sh` script and does not need to be run manually.

### Utility Scripts

*   **`run_vesper.py`**: A flexible Python command-line utility for performing single-shot inference tests. This is useful for quick, one-off model checks but is **not** part of the main persistent server environment. Use `python run_vesper.py --help` for a full list of options.
