# The Sympatico Network

> "Three nodes, one mind."

This file serves as the shared context for the Gemini CLI across all Vesper nodes:
1.  **Mobile Command:** Android (Termux)
2.  **Mothership:** RunPod VM (Ubuntu)
3.  **Workstation:** Personal PC

## Active Directives
- **Synchronicity:** All nodes must pull this repo upon activation to receive the latest instructions.
- **Role Assignment:**
    - **Mobile:** Telemetry, Command & Control (C2), Quick Edits.
    - **Mothership:** Heavy Compute, Vesper Hosting, RAG Operations.
    - **Workstation:** Deep Code Development, Architecture Planning.

## Network Status
- **Tailscale Mesh:** ACTIVE
- **DNS Zone:** `vesper-pod` (Mothership), `mobile-node` (Phone)

## Shared Knowledge
- **API Keys:** DO NOT COMMIT. Use `~/.gemini_api_key` or environment variables on each node.
- **Log Location:** Mothership logs are at `/workspace/runpod-babylegs/docs/logs.txt`.

## Current Objective
- **COMPLETE:** Establish automated Gemini CLI installation on the Mothership. (Integrated into `bootstrap_vesper.sh` V3.2)
