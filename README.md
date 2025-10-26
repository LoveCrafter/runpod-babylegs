# AI Model Inference Project

## Project Overview

This project provides a comprehensive environment for running a high-performance, open-source GGUF model and a supporting RAG memory server. It is designed to be run on a remote RunPod instance and managed from your local machine using a single "launch button" command.

## Quick Start: Initializing the Pod

### Prerequisites on the Remote Pod

Before running the local startup scripts, ensure the following steps have been completed on your RunPod instance. The `start_remote_services.sh` script includes pre-flight checks and will report an error if these are not correctly in place.

1.  **Clone the Repository:** The entire project must be cloned into the persistent `/workspace` directory.
    ```bash
    # Connect to your pod and run:
    cd /workspace
    git clone https://github.com/LoveCrafter/runpod-babylegs.git
    ```
2.  **Download the Model:** Place the GGUF model file(s) in the `/workspace/runpod-babylegs/models/` directory. The expected path is configured in `vesper.conf`.
3.  **Setup Python Environment:** Create and activate a virtual environment inside the repository folder.
    ```bash
    # From the /workspace/runpod-babylegs directory:
    python3 -m venv vesper_env
    source vesper_env/bin/activate
    pip install -r requirements.txt
    ```

### Configuring the Services

All key parameters for the model, such as the number of GPU layers and the context size, are controlled via the `vesper.conf` file.

1.  **Edit the Configuration:** Open the `vesper.conf` file and adjust the values as needed.
2.  **Apply the Changes:** To apply your new settings, you must restart the LLM server. You can do this without rebooting the pod. Simply SSH into the pod and run the following command from the repository root:
    ```bash
    ./start_remote_services.sh --restart-llm
    ```
    This will safely stop the current server and launch a new one with your updated configuration.

### Launching the Services

The local startup scripts (`start_services.sh` and `start_services.ps1`) connect to your pod and execute the remote `start_remote_services.sh` script, which reads its settings from `vesper.conf` and launches the services.

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

After running the script, it will start all services on the remote pod and stream the `llama-server` logs to your terminal. You will then need to open a **second terminal** to create an SSH tunnel to access the model.

---

## Mobile Access with Termius (One-Tap Launch)

For a seamless mobile experience, you can use Termius's built-in features to launch and connect to the pod with a single tap. This method is the recommended way to interact with the pod, as it ensures your code is always up-to-date.

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
        /workspace/runpod-babylegs/termius_launch.sh
        ```
    *   Go back to your Host settings.
    *   Under the "Startup Snippet" option, select the snippet you just created.

### Launching the Connection

Now, simply tap on the "Vesper Pod" host in Termius. It will automatically:
1.  Establish the SSH connection.
2.  Activate the port forwarding rule you created.
3.  Run the startup snippet, which will:
    *   **Sync the Code:** Pull the latest changes from the `master` branch on GitHub.
    *   **Launch Services:** Start the RAG and LLM servers in the background.

Once connected, you can open a browser on your phone and navigate to `http://localhost:8080` to interact with the model. The Termius session must remain active in the background.