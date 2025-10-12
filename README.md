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

### Included Scripts

*   `start_services.sh`: The main entry point for starting all services.
*   `run_vesper.py`: A flexible Python script for performing single-shot inference tests. Can be run on the pod after activating the venv (`source /workspace/vesper_env/bin/activate`). Use `python run_vesper.py --help` for options.
*   `build_memory.py`: The script for the RAG memory server. It is automatically launched by `start_services.sh`.

### `run_vesper.py` Usage

The `run_vesper.py` script is a command-line tool for running single-shot inference tests.

**Basic Example:**
```bash
python run_vesper.py
```

**Custom Configuration Example:**
```bash
python run_vesper.py \
  --model-path /path/to/your/model.gguf \
  --n-gpu-layers 60
```

**Command-Line Arguments:**

*   `-m`, `--model-path`: Path to the GGUF model file.
*   `-ngl`, `--n-gpu-layers`: Number of layers to offload to the GPU. Use `-1` to offload all possible layers.
*   `-c`, `--n-ctx`: The context size to use for the model.
*   `-p`, `--prompt`: The prompt to start text generation with.
*   `-t`, `--max-tokens`: The maximum number of tokens to generate in the response.

You can see all options by running the script with the `-h` or `--help` flag:
```bash
python run_vesper.py --help
```
