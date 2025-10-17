import argparse
import time
import os
import torch
import lancedb
from sentence_transformers import SentenceTransformer
from llama_cpp import Llama

def get_rag_context(query: str, db_path: str, embed_model: str, device: str) -> str:
    """Connects to LanceDB, performs a vector search, and returns formatted context."""
    print("🧠 Performing RAG lookup...")
    try:
        db = lancedb.connect(db_path)
        table = db.open_table("memory")

        print(f"   - Loading sentence transformer '{embed_model}' to '{device}'...")
        embedder = SentenceTransformer(embed_model, device=device)

        print(f"   - Creating embedding for query...")
        query_vector = embedder.encode(query, normalize_embeddings=True)

        print(f"   - Searching for relevant memories...")
        results = table.search(query_vector).limit(5).to_list()

        if not results:
            print("   - No relevant memories found.")
            return ""

        context = "\n\n---\n\n".join([item['text'] for item in results])
        print(f"   - Found {len(results)} relevant memories.")
        return context

    except Exception as e:
        print(f"\n❌ RAG ERROR: Could not retrieve context: {e}")
        return ""

def main():
    parser = argparse.ArgumentParser(
        description="Run inference with a GGUF model, optionally augmented with RAG."
    )
    # --- LLM and Model Arguments ---
    parser.add_argument("-m", "--model-path", type=str, default=os.getenv("VESPER_MODEL_PATH", "/workspace/models/default_model.gguf"), help="Path to the GGUF model file.")
    parser.add_argument("-ngl", "--n-gpu-layers", type=int, default=-1, help="Number of layers to offload to the GPU.")
    parser.add_argument("-c", "--n-ctx", type=int, default=4096, help="The context size.")
    parser.add_argument("-t", "--max-tokens", type=int, default=2048, help="Max tokens to generate.")

    # --- RAG Arguments ---
    parser.add_argument("--no-rag", action="store_true", help="Disable RAG memory lookup.")
    parser.add_argument("--rag-db-path", type=str, default="memory.lancedb", help="Path to the LanceDB memory store.")
    parser.add_argument("--rag-model", type=str, default="BAAI/bge-large-en-v1.5", help="Sentence transformer model for RAG.")

    # --- Prompt/Query Argument ---
    parser.add_argument("prompt", type=str, help="The prompt/query for the model.")

    args = parser.parse_args()

    # --- RAG Context Retrieval ---
    final_prompt = args.prompt
    if not args.no_rag:
        rag_device = "cuda" if torch.cuda.is_available() else "cpu"
        rag_context = get_rag_context(args.prompt, args.rag_db_path, args.rag_model, rag_device)
        if rag_context:
            final_prompt = (
                "--- Relevant Memory Context ---\n"
                f"{rag_context}\n"
                "--- End of Context ---\n\n"
                f"User Query: {args.prompt}\n\n"
                "Response:"
            )

    # --- Model Loading ---
    print("\n--- Vesper Core Initializing ---")
    print(f"Loading model from: {args.model_path}")
    try:
        llm = Llama(model_path=args.model_path, n_gpu_layers=args.n_gpu_layers, n_ctx=args.n_ctx, verbose=False)
        print("✅ Model loaded successfully.")
    except Exception as e:
        print(f"\n❌ FATAL: Failed to load model: {e}")
        exit(1)

    # --- Inference ---
    print("\n--- Performing Inference ---")
    print(f"PROMPT: {final_prompt}")
    try:
        output = llm(final_prompt, max_tokens=args.max_tokens, echo=False, stop=["\nUser Query:"])
        print("\n--- INFERENCE OUTPUT ---")
        print(output['choices'][0]['text'].strip())
        print("--------------------------")
    except Exception as e:
        print(f"\n❌ FATAL: Inference failed: {e}")
        exit(1)

if __name__ == "__main__":
    main()
