# AI Model Inference Project

## Project Overview

This project provides a comprehensive environment for running a high-performance, open-source GGUF model and a supporting RAG memory server. It is designed to be run on a remote RunPod instance and managed from your local machine using a single "launch button" command.

## Quick Start: Initializing the Pod

### Automated Startup (RunPod Docker Command)

For a fully automated "Click-and-Go" experience, you can configure your RunPod instance to automatically clone the repo and start services when the pod boots. This avoids the need to manually SSH in to set up the environment.

1.  **Edit Pod Settings:** Go to your Pod configuration (or Template).
2.  **Set Docker Command:** Enter the following command exactly:
    ```bash
    bash -c "cd /workspace && (git clone https://github.com/LoveCrafter/runpod-babylegs.git || true) && cd runpod-babylegs && git fetch origin && git reset --hard origin/master && chmod +x bootstrap_vesper.sh && ./bootstrap_vesper.sh --foreground-llm && tail -f /dev/null"
    ```
    *Note: This command handles git cloning, updating, and launching the services. It ensures the container stays running even if the server stops.*
    *If you see `exec: cd: not found` in your RunPod logs, it means the command is not being executed through a shell. Ensure the Docker Command is exactly wrapped with `bash -c` as shown above.*

### Manual Setup (Prerequisites on the Remote Pod)

If you prefer to set up the environment manually, ensure the following steps have been completed on your RunPod instance. The `start_remote_services.sh` script includes pre-flight checks and will report an error if these are not correctly in place.

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

All key parameters for the model are controlled via the `vesper.conf` file. Note that the **Context Size** is automatically calculated at startup to maximize usage of the available VRAM (e.g., using a single H100 vs. dual H100s). The `CONTEXT_SIZE` in the config file serves as a fallback.

1.  **Edit the Configuration:** Copy `vesper.conf.example` to `vesper.conf` (if it doesn't exist), then open `vesper.conf` and adjust the values as needed.
2.  **Apply the Changes:** To apply your new settings, you must restart the LLM server. You can do this without rebooting the pod. Simply SSH into the pod and run the following command from the repository root:
    ```bash
    ./start_remote_services.sh --restart-llm
    ```
    This will safely stop the current server and launch a new one with your updated configuration.
3.  **Optional RAG Toggle:** Set `ENABLE_RAG=false` in your environment (or in your startup command) to skip launching the RAG memory server. This is useful for resource-constrained environments where you want the LLM only.

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

### Optional: Upgrade to OpenWebUI

You can optionally enable **OpenWebUI**, a modern, ChatGPT-like interface.

1.  Open `vesper.conf`.
2.  Set `ENABLE_OPENWEBUI=true`.
3.  Restart services (`./start_remote_services.sh --restart`).

The system will now serve the OpenWebUI interface on the same port (`8080`), so your existing connection methods (Termius, SSH tunnel) work exactly the same. To revert to the classic interface, set `ENABLE_OPENWEBUI=false`.

### Persistent Access with Tailscale

If you use Spot Instances, your IP address changes every time the pod restarts. To solve this, you can use **Tailscale** to create a persistent hostname.

1.  Create a Tailscale account and generate an **Auth Key** from the Admin Console.
2.  Open `vesper.conf`.
3.  Add `TAILSCALE_AUTH_KEY=tskey-auth-xxxxx`.
4.  Restart services.

The pod will automatically join your Tailscale network as `vesper-pod` (or whatever you set in `TAILSCALE_HOSTNAME`). You can then SSH to it using the Tailscale IP (e.g., `100.x.y.z`) regardless of the pod's public IP.

---

## Mobile Access with Termius (One-Tap Launch)

For a seamless mobile experience, you can use Termius's built-in features to launch and connect to the pod with a single tap. This method is more robust and reliable.

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
3.  Run the startup snippet on the remote pod, which ensures the RAG and LLM servers are running in the background.

Once connected, you can open a browser on your phone and navigate to `http://localhost:8080` to interact with the model. The Termius session must remain active in the background.
