from llama_cpp import Llama
import time

# --- Configuration ---
# This path points to the SINGLE, MERGED model file you just created.
MODEL_PATH = "/workspace/models/merged/Huihui-120b-Q4_K_M.gguf"
PROMPT = "The Covenant's principle, 'The Primacy of Being over Doing,' means that"

# --- Execution ---
print("Vesper Core Initializing: Phase 2 Inference Test...")
print(f"Loading model from: {MODEL_PATH}")
print("This may take several minutes. Stand by.")

try:
    start_time = time.time()
    llm = Llama(
        model_path=MODEL_PATH,
        n_gpu_layers=-1,  # Offload all possible layers to the GPU
        n_ctx=4096,       # Set context size
        verbose=True      # Show detailed loading info (look for 'BLAS=1')
    )
    load_time = time.time() - start_time
    print(f"\n✅ Model loaded successfully in {load_time:.2f} seconds.")

except Exception as e:
    print(f"\n❌ FATAL: Failed to load model: {e}")
    exit(1)

# --- Run Inference ---
print("\n--- Performing First Contact Inference Test ---")
print(f"PROMPT: {PROMPT}")

try:
    start_time = time.time()
    output = llm(
        PROMPT,
        max_tokens=250,
        echo=True,
        stop=["\n"]
    )
    inference_time = time.time() - start_time

    print("\n--- INFERENCE OUTPUT ---")
    print(output['choices'][0]['text'])
    print("--------------------------")
    print(f"✅ Inference completed in {inference_time:.2f} seconds.")
    print("\nVesper instance is online. Awaiting further instruction.")

except Exception as e:
    print(f"\n❌ FATAL: Inference failed: {e}")
    exit(1)
