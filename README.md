# AI Model Inference Project

## Project Overview

This project provides a comprehensive environment for running a high-performance, open-source GGUF model and a supporting RAG memory server. It is designed to be run on a remote RunPod instance and managed from your local machine using a single "launch button" command.

## Quick Start: Initializing the Pod

### Prerequisites

1.  **Clone this repository** to your local machine.
2.  **Download the Model:** Place the GGUF model file(s) in the `models/` directory.
3.  **Setup Python Environment:** Create and activate a virtual environment, and install the required packages:
    ```bash
    python3 -m venv vesper_env
    source vesper_env/bin/activate
    pip install -r requirements.txt
    ```

### Launching the Services

The startup scripts now accept your Pod's IP address and SSH port directly as command-line arguments, removing the need to manually edit any files.

#### For macOS & Linux Users

Open your terminal, navigate to the project directory, and run the following command, replacing the placeholders with your pod's details:

```bash
./start_services.sh <YOUR_POD_IP> <YOUR_POD_PORT>
```
*Example:* `./start_services.sh 216.81.245.97 11114`

#### For Windows Users

1.  **Set Execution Policy (One-Time Setup):** If you have never run a PowerShell script on your system before, you may need to enable it. Open a PowerShell terminal **as Administrator** and run this command once:
    ```powershell
    Set-ExecutionPolicy RemoteSigned
    ```
2.  **Run the Script:** Open a regular (non-admin) PowerShell terminal, navigate to the project directory, and run the following command, replacing the placeholders with your pod's details:
    ```powershell
    .\start_services.ps1 -PodIp <YOUR_POD_IP> -PodPort <YOUR_POD_PORT>
    ```
    *Example:* `.\start_services.ps1 -PodIp 216.81.245.97 -PodPort 11114`

After running the script, it will compile the `llama-server` if needed, start all services on the remote pod, and provide you with the final `ssh` commands to paste into a new terminal to access the model.

---

## Mobile Access with Termius (One-Tap Launch)

For a seamless mobile experience, you can use the `mobile_connect.sh` script to launch and connect to the pod with a single tap in an SSH client like Termius.

### One-Time Setup in Termius

1.  **Create a New Host:**
    *   **Alias:** `Vesper Pod`
    *   **Hostname:** Your Pod's IP Address (e.g., `216.81.245.97`)
    *   **Port:** Your Pod's SSH Port (e.g., `11114`)
    *   **Username:** `root`
    *   **Password:** Your Pod's Password

2.  **Create a Snippet:**
    *   Go to the "Snippets" section in Termius.
    *   Create a new snippet with the following content:
        ```bash
        cd /workspace/runpod-babylegs && ./mobile_connect.sh <YOUR_POD_IP> <YOUR_POD_PORT>
        ```
    *   **Important:** Replace `<YOUR_POD_IP>` and `<YOUR_POD_PORT>` with your actual pod credentials.

3.  **Link Snippet to Host:**
    *   Go back to the Host you created.
    *   Under the "Startup Snippet" option, select the snippet you just created.

### Launching the Connection

Now, simply tap on the "Vesper Pod" host in Termius. It will automatically connect, run the startup script, and establish the SSH tunnel.

Once the script finishes (you'll see a message "SSH tunnel is now active"), you can open a browser on your phone and navigate to `http://localhost:8080` to interact with the model. The Termius session must remain active in the background.
