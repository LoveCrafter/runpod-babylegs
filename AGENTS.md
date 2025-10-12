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
