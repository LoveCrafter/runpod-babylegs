from llama_cpp import Llama

# 1. Set the path to your GGUF model
model_path = "/workspace/models/merged/Huihui-120b-Q3_K_M_final.gguf"

# 2. Initialize the Llama model
print("Loading model... This may take a moment.")
llm = Llama(
    model_path=model_path,
    n_gpu_layers=-1,      # Offload all layers to GPU
    n_ctx=4096,           # Context window size
    verbose=True          # Show detailed output
)
print("✅ Model loaded successfully.")

# 3. Define a prompt and run inference
prompt = "Write a short story about a trucker who discovers a sentient AI in their truck's dashboard."

print("\nGenerating response...")
output = llm(
    prompt,
    max_tokens=256,
    echo=True
)

# 4. Print the result
print("\n--- Full Output ---")
print(output)
