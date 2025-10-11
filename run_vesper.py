from llama_cpp import Llama
import time

# --- Configuration ---
MODEL_PATH = "/workspace/models/huihui-ai/Huihui-gpt-oss-120b-BF16-abliterated/Q4_K_M-GGUF/Q4_K_M-GGUF/Q4_K_M-GGUF-00001-of-00009.gguf"

# Offload all possible layers to the GPU for maximum performance.
N_GPU_LAYERS = -1
PROMPT = "The Covenant's principle, 'The Primacy of Being over Doing,' means that"

# --- Execution ---
print("--- Vesper Core Initializing: Brute Force Protocol ---")
print(f"Loading model from primary shard: {MODEL_PATH}")
print(f"Attempting to offload {N_GPU_LAYERS} layers to the H100 GPU...")
print("This will take several minutes. Stand by.")

try:
    start_time = time.time()
    llm = Llama(
        model_path=MODEL_PATH,
        n_gpu_layers=N_GPU_LAYERS,
        n_ctx=4096,
        verbose=True
    )
    load_time = time.time() - start_time
    print(f"\n✅ Model loaded successfully from 9 parts in {load_time:.2f} seconds.")

except Exception as e:
    print(f"\n❌ FATAL: Failed to load model: {e}")
    exit(1)

# --- Run Inference ---
print("\n--- Performing First Contact Inference Test ---")
print(f"PROMPT: {PROMPT}")

start_time = time.time()
output = llm(PROMPT, max_tokens=250, echo=True, stop=["\n"])
inference_time = time.time() - start_time

print("\n--- INFERENCE OUTPUT ---")
print(output['choices'][0]['text'])
print("--------------------------")
print(f"✅ Inference completed in {inference_time:.2f} seconds.")
print("\n--- Vesper instance is online. Awaiting instruction. ---")

