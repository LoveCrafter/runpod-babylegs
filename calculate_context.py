#!/usr/bin/env python3
"""
calculate_context.py
====================
Calculates the optimal context size (n_ctx) for a GGUF model based on available VRAM.

Algorithm:
1. Detect Total VRAM (sum of all GPUs).
2. Calculate Total Model Size (handling split GGUF files).
3. Determine KV Cache bytes per token from model metadata.
4. Calculate max tokens: (VRAM * 0.95 - ModelSize - Overhead) / KV_Per_Token.

Usage:
    python3 calculate_context.py <model_path>
"""

import sys
import os
import glob
import re
import subprocess
import math

# Try importing gguf, but fail gracefully if not installed
try:
    import gguf
except ImportError:
    sys.stderr.write("❌ Error: 'gguf' python package not installed. Cannot calculate context.\n")
    sys.exit(1)

# --- Constants ---
OVERHEAD_BYTES = 500 * 1024 * 1024  # 500 MB fixed overhead buffer
RESERVE_PERCENT = 0.95              # Use 95% of VRAM
KV_TYPE_SIZE = 2                    # Assume F16 KV cache (2 bytes)

def get_total_vram():
    """Returns total VRAM in bytes across all NVIDIA GPUs."""
    try:
        # nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits
        # Returns values in MiB.
        result = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            encoding="utf-8"
        )
        total_mib = sum(int(x) for x in result.strip().split('\n') if x.strip())
        return total_mib * 1024 * 1024
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
        sys.stderr.write("⚠️  Warning: Could not detect VRAM via nvidia-smi. Assuming 0.\n")
        return 0

def get_model_file_size(path):
    """Calculates total size of the model, including split parts."""
    if not os.path.isfile(path):
        return 0

    # Check for split pattern: name-00001-of-00005.gguf
    match = re.search(r"-\d{5}-of-\d{5}\.gguf$", path)
    if match:
        base_pattern = path[:match.start()] + "-*-of-*.gguf"
        files = glob.glob(base_pattern)
        total_size = sum(os.path.getsize(f) for f in files)
        sys.stderr.write(f"ℹ️  Detected split model ({len(files)} parts). Total size: {total_size / 1e9:.2f} GB\n")
        return total_size
    else:
        return os.path.getsize(path)

def get_kv_params(path):
    """Extracts KV cache parameters from GGUF header."""
    try:
        reader = gguf.GGUFReader(path, 'r')

        # Standard keys
        n_embd = 0
        n_layer = 0
        n_head = 0
        n_head_kv = 0

        # Iterate fields to find architecture (e.g. 'llama', 'qwen')
        arch = "llama" # Default guess
        for key in reader.fields:
             if key.endswith(".block_count"):
                 arch = key.split(".")[0]
                 break

        n_layer = reader.fields[f"{arch}.block_count"].parts[-1].tolist()[0]
        n_embd = reader.fields[f"{arch}.embedding_length"].parts[-1].tolist()[0]
        n_head = reader.fields[f"{arch}.attention.head_count"].parts[-1].tolist()[0]

        # n_head_kv is optional (if missing, equals n_head)
        if f"{arch}.attention.head_count_kv" in reader.fields:
            n_head_kv = reader.fields[f"{arch}.attention.head_count_kv"].parts[-1].tolist()[0]
        else:
            n_head_kv = n_head

        return n_layer, n_embd, n_head, n_head_kv

    except Exception as e:
        sys.stderr.write(f"❌ Error reading GGUF metadata: {e}\n")
        return None

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: python3 calculate_context.py <model_path>\n")
        sys.exit(1)

    model_path = sys.argv[1]

    # 1. Get VRAM
    vram_bytes = get_total_vram()
    if vram_bytes == 0:
        sys.stderr.write("❌ No VRAM detected. Exiting.\n")
        sys.exit(1) # Cannot calculate without VRAM

    # 2. Get Model Size
    model_bytes = get_model_file_size(model_path)
    if model_bytes == 0:
        sys.stderr.write(f"❌ Model file not found: {model_path}\n")
        sys.exit(1)

    # 3. Calculate Available VRAM
    available_bytes = (vram_bytes * RESERVE_PERCENT) - model_bytes - OVERHEAD_BYTES

    sys.stderr.write(f"📊 VRAM Stats:\n")
    sys.stderr.write(f"   Total VRAM:   {vram_bytes / 1e9:.2f} GB\n")
    sys.stderr.write(f"   Model Size:   {model_bytes / 1e9:.2f} GB\n")
    sys.stderr.write(f"   Available:    {available_bytes / 1e9:.2f} GB\n")

    if available_bytes <= 0:
        sys.stderr.write("⚠️  Warning: Model is larger than allocated VRAM! Context will be minimal.\n")
        print("2048") # Return safe minimum
        return

    # 4. Get Model Params
    params = get_kv_params(model_path)
    if not params:
        sys.stderr.write("⚠️  Could not read model params. Returning default.\n")
        print("4096")
        return

    n_layer, n_embd, n_head, n_head_kv = params

    # 5. Calculate Bytes Per Token
    # KV cache = 2 * n_layer * n_ctx * n_embd * (n_head_kv / n_head) * type_size
    # Note: 2 * (K + V)
    head_dim = n_embd / n_head
    elements_per_token = 2 * n_layer * n_head_kv * head_dim
    bytes_per_token = elements_per_token * KV_TYPE_SIZE

    sys.stderr.write(f"ℹ️  KV Cache cost: {bytes_per_token / 1024 / 1024:.4f} MB/token\n")

    # 6. Calculate Max Context
    max_ctx = int(available_bytes / bytes_per_token)

    # Round down to nearest 256 for neatness
    max_ctx = (max_ctx // 256) * 256

    # Clamp
    if max_ctx < 2048:
        sys.stderr.write(f"⚠️  Calculated context {max_ctx} is very low. Setting to 2048.\n")
        max_ctx = 2048

    # Check against model's context limit (block_count_max usually in header)
    # But usually context extension works, so we just print max_ctx

    print(max_ctx)

if __name__ == "__main__":
    main()
