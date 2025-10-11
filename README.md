# My AI Model Project

This project runs an open-source model using a custom inference script.

## Setup Instructions

1.  **Clone this repository.**
2.  **Download the Model:** Download the 82 GB GGUF model file and place it in a directory named `models/`.
3.  **Setup Python Environment:** Create and activate a virtual environment.
    ```bash
    python3 -m venv vesper_env
    source vesper_env/bin/activate
    ```
4.  **Install Dependencies:** Install all required Python packages.
    ```bash
    pip install -r requirements.txt
    ```
5.  **Setup llama.cpp:** Initialize and compile the `llama.cpp` submodule.
    ```bash
    git submodule update --init --recursive
    cd llama.cpp && make && cd ..
    ```
