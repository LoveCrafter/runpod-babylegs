# AI Model Inference Project

This project runs a high-performance, open-source GGUF model and a supporting RAG memory server.
This project runs an open-source GGUF model using a custom, flexible inference script.

## Quick Start: Initializing the Pod

The entire environment, including the main model and the RAG memory server, is managed by a single, unified startup script.

### Instructions

1.  **Configure the Launcher:**
    Open the `start_services.sh` script and replace the placeholder values for `POD_IP` and `POD_PORT` with your RunPod instance's details.

2.  **Make the Script Executable:**
    If you haven't already, open your local terminal and run:
1.  **Clone this repository.**
2.  **Download the Model:** Download the 82 GB GGUF model file and place it in a directory named `models/`. For sharded models (multiple `.gguf` files), ensure all parts are in the same directory.
3.  **Setup Python Environment:** Create and activate a virtual environment.
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
## Usage

The primary script for running inference is `run_vesper.py`. It has been refactored to accept command-line arguments for key parameters, allowing for flexible configuration without editing the source code.

### Running the Model

To run the model, execute the `run_vesper.py` script from your terminal.

**Basic Example:**

This command runs the script with its default settings, loading the pre-configured model and offloading all possible layers to the GPU.

```bash
python run_vesper.py
```

**Custom Configuration Example:**

You can customize the execution by providing arguments. For example, to run a different model and specify the number of GPU layers:

```bash
python run_vesper.py \
  --model-path /path/to/your/model.gguf \
  --n-gpu-layers 60
```

### Command-Line Arguments

*   `-m`, `--model-path`: Path to the GGUF model file.
*   `-ngl`, `--n-gpu-layers`: Number of layers to offload to the GPU. Use `-1` to offload all possible layers.
*   `-c`, `--n-ctx`: The context size to use for the model.
*   `-p`, `--prompt`: The prompt to start text generation with.
*   `-t`, `--max-tokens`: The maximum number of tokens to generate in the response.

You can see all options by running the script with the `-h` or `--help` flag:
```bash
python run_vesper.py --help
```
