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

For a seamless mobile experience, you can use Termius's built-in features to launch and connect to the pod with a single tap. This method is more robust and reliable than the previous script-based approach.

### One-Time Setup in Termius

1.  **Create/Edit your Host:**
    *   Navigate to the "Hosts" section in Termius and select your Vesper pod host.
    *   Ensure the `Hostname`, `Port`, `Username`, and `Password` are correctly filled in.

2.  **Configure Port Forwarding:**
    *   In the Host settings, find the "Port Forwarding" section.
    *   Create a new **Local** port forwarding rule:
        *   **Port (on your phone):** `8080`
        *   **Destination Host (on the pod):** `127.0.0.1`
        *   **Destination Port (on the pod):** `8080`

3.  **Create and Assign a Startup Snippet:**
    *   Go to the "Snippets" section and create a new snippet with the following command:
        ```bash
        /workspace/runpod-babylegs/start_remote_services.sh
        ```
    *   Go back to your Host settings.
    *   Under the "Startup Snippet" option, select the snippet you just created.

### Launching the Connection

Now, simply tap on the "Vesper Pod" host in Termius. It will automatically:
1.  Establish the SSH connection.
2.  Activate the port forwarding rule you created.
3.  Run the startup snippet on the remote pod, which ensures the RAG and LLM servers are running.

Once connected, you can open a browser on your phone and navigate to `http://localhost:8080` to interact with the model. The Termius session must remain active in the background.
