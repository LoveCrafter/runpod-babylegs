# AI Model Inference Project

This project runs an open-source GGUF model using a custom, flexible inference script.

## Setup Instructions

1.  **Clone this repository.**
2.  **Download the Model:** Download the 82 GB GGUF model file and place it in a directory named `models/`. For sharded models (multiple `.gguf` files), ensure all parts are in the same directory.
3.  **Setup Python Environment:** Create and activate a virtual environment.
    ```bash
    python3 -m venv vesper_env
    source vesper_env/bin/activate
    ```
4.  **Install Dependencies:** Install all required Python packages.
    ```bash
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
