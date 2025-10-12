# Agent Instructions for `runpod-babylegs`

This document provides special instructions for AI agents working with this repository.

## Syncing with the Remote Repository

**Problem:** The agent's sandboxed environment has a persistent, local clone of the repository. It does not automatically sync with the remote repository on GitHub. If the user merges a branch or makes changes directly on the remote, the agent's local `master` branch will become outdated. This will cause `git merge` and `git diff` commands to fail or produce incorrect results due to 'unrelated histories' or a diverged HEAD.

**Solution:** Before starting any new task, especially after the user has merged a branch, you **must** sync your local `master` branch with the remote.

A simple `git pull` is blocked in this environment. Use the following command sequence to force your local `master` branch to exactly match the remote `master`:

```bash
git checkout master
git fetch origin
git reset --hard origin/master
```

This ensures you are always working with the most up-to-date version of the code. The user will notify you when they have completed a merge.

---

## Future Goals & Roadmap

This section outlines the high-level goals and planned improvements for the project. Items will be implemented piecemeal and removed from this list once complete.

- **Introduce Automated Testing:**
  - **Goal:** Implement a `pytest` environment to run automated tests.
  - **Constraint:** Tests must be runnable on the CPU, as the model itself consumes most of the available VRAM.

- **Centralize Configuration:**
  - **Goal:** Move hardcoded parameters (e.g., `CONTEXT_SIZE`, port numbers) from the startup scripts into a single, centralized configuration file (e.g., `.env` or `config.yaml`).

- **Consolidate Redundant Scripts:**
  - **Goal:** Analyze the legacy `run_gguf.py` and `run_inference.py` scripts and formally deprecate them by removing them from the repository, ensuring `run_vesper.py` covers all necessary functionality.

- **Document Project History & Decisions:**
  - **Goal:** Create a dedicated documentation page or section that covers the project's history, major bug fixes, and the reasoning behind key architectural decisions (e.g., why a specific version of `llama.cpp` was used).
  - **Note:** The user has a comprehensive Google Doc with this information to be shared.

- **Fix `llama.cpp` Submodule (Question Mark Task):**
  - **Goal:** Investigate the broken `llama.cpp` submodule integration and attempt to fix it by adding a `.gitmodules` file.
  - **Constraint:** This is a lower priority "question mark" task, as the original integration may have been done for specific reasons related to the community model.
