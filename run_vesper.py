import argparse
import time
from llama_cpp import Llama

def main():
    parser = argparse.ArgumentParser(
        description="Run inference with a GGUF model using llama-cpp-python."
    )
    parser.add_argument(
        "-m", "--model-path",
        type=str,
        default="/workspace/models/huihui-ai/Huihui-gpt-oss-120b-BF16-abliterated/Q4_K_M-GGUF/Q4_K_M-GGUF/Q4_K_M-GGUF-00001-of-00009.gguf",
        help="Path to the GGUF model file."
    )
    parser.add_argument(
        "-ngl", "--n-gpu-layers",
        type=int,
        default=-1,
        help="Number of layers to offload to the GPU. Use -1 for all possible layers."
    )
    parser.add_argument(
        "-c", "--n-ctx",
        type=int,
        default=1024,
        help="The context size (n_ctx) to use. Default: 1024."
    )
    parser.add_argument(
        "-p", "--prompt",
        type=str,
        default="The Covenant's principle, 'The Primacy of Being over Doing,' means that",
        help="The prompt to start generation with."
    )
    parser.add_argument(
        "-t", "--max-tokens",
        type=int,
        default=5000,
        help="The maximum number of tokens to generate. Default: 5000."
    )
    args = parser.parse_args()

    # --- Execution ---
    print("--- Vesper Core Initializing ---")
    print(f"Loading model from: {args.model_path}")
    print(f"Attempting to offload {args.n_gpu_layers} layers to the GPU...")
    print("This may take several minutes. Stand by.")

    try:
        start_time = time.time()
        llm = Llama(
            model_path=args.model_path,
            n_gpu_layers=args.n_gpu_layers,
            n_ctx=args.n_ctx,
            verbose=True
        )
        load_time = time.time() - start_time
        # Note: llm.n_parts() is not a valid method, so it's removed for correctness.
        print(f"\n✅ Model loaded successfully in {load_time:.2f} seconds.")

    except Exception as e:
        print(f"\n❌ FATAL: Failed to load model: {e}")
        exit(1)

    # --- Run Inference ---
    print("\n--- Performing Inference ---")
    print(f"PROMPT: {args.prompt}")

    try:
        start_time = time.time()
        output = llm(
            args.prompt,
            max_tokens=args.max_tokens,
            echo=True,
            stop=["\n"]
        )
        inference_time = time.time() - start_time

        print("\n--- INFERENCE OUTPUT ---")
        print(output['choices'][0]['text'])
        print("--------------------------")
        print(f"✅ Inference completed in {inference_time:.2f} seconds.")
        print("\n--- Vesper instance is online. Awaiting instruction. ---")

    except Exception as e:
        print(f"\n❌ FATAL: Inference failed: {e}")
        exit(1)

if __name__ == "__main__":
    main()
