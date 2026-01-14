#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import zipfile
import pathlib
import secrets
from datetime import datetime, timezone
from tqdm import tqdm
import torch
import lancedb
from sentence_transformers import SentenceTransformer
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
import uvicorn
import orjson

# --- CONFIGURATION ---
ZIP_PATH         = os.getenv("ZIP_PATH", "chatgpt_export.zip")
UNZIP_DIR        = os.getenv("UNZIP_DIR", "chatgpt_export")
LANCEDB_PATH     = os.getenv("LANCEDB_PATH", "memory.lancedb")
CHUNK_TOKENS     = int(os.getenv("CHUNK_TOKENS", "5500"))
# Use env var for model name, default to BGE Large
EMBED_MODEL_NAME = os.getenv("EMBED_MODEL_NAME", "BAAI/bge-large-en-v1.5")
EMBED_DEVICE     = os.getenv("RAG_DEVICE", "cuda" if torch.cuda.is_available() else "cpu")
API_HOST         = "0.0.0.0"
API_PORT         = int(os.getenv("API_PORT", "5000"))
TOP_K_DEFAULT    = int(os.getenv("TOP_K", "5"))
API_SECRET       = os.getenv("API_SECRET", "CHANGE_ME")
RAG_ENABLED      = os.getenv("ENABLE_RAG", "true").lower() == "true"

# --- 1. DATA PARSING ---
def unzip_export(zip_path: str, out_dir: str):
    if os.path.isdir(out_dir):
        print(f"[i] Directory {out_dir} already exists – skipping unzip.")
        return
    print(f"[+] Unzipping {zip_path} -> {out_dir}")
    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(out_dir)

def build_message_stream(conv_dir: str):
    print("[+] Parsing conversation files...")
    msgs = []

    # Smart Find: Check root, then subdirs
    single_file = pathlib.Path(conv_dir) / "conversations.json"
    if not single_file.exists():
         subdirs = [x for x in pathlib.Path(conv_dir).iterdir() if x.is_dir()]
         for sub in subdirs:
             candidate = sub / "conversations.json"
             if candidate.exists():
                 single_file = candidate
                 break

    if single_file.exists():
        print(f"[+] Found conversations file at {single_file}")
        with single_file.open("rb") as f:
            try:
                data = orjson.loads(f.read())
            except orjson.JSONDecodeError:
                print(f"[!] Failed to decode JSON from {single_file}")
                return []

        conversations = data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])

        for conv in tqdm(conversations, desc="Processing conversations"):
            mapping = conv.get("mapping", {})
            for msg_details in mapping.values():
                msg = msg_details.get("message")
                if msg:
                    role = msg.get("author", {}).get("role", "user")
                    # Safe timestamp
                    try: ts = float(msg.get("create_time", 0.0) or 0.0)
                    except: ts = 0.0

                    parts = msg.get("content", {}).get("parts", [])
                    content = "\n".join([str(p) for p in parts if p]).strip()

                    if content:
                        msgs.append({"role": role, "timestamp": ts, "content": content})
    else:
        print(f"[!] No conversations.json found in {conv_dir}")

    msgs.sort(key=lambda x: x["timestamp"])
    print(f"[i] Found and sorted {len(msgs)} total messages.")
    return msgs

def split_into_chunks(messages, tokenizer):
    print(f"[+] Splitting messages into ~{CHUNK_TOKENS}-token chunks...")
    chunks = []
    current_chunk_text = []
    current_chunk_tokens = 0
    for msg in messages:
        token_len = len(tokenizer.encode(msg["content"]))
        if current_chunk_tokens + token_len > CHUNK_TOKENS and current_chunk_text:
            chunks.append("\n".join(current_chunk_text))
            current_chunk_text, current_chunk_tokens = [], 0

        iso_ts = datetime.fromtimestamp(msg["timestamp"], tz=timezone.utc).isoformat()
        current_chunk_text.append(f"[{msg['role'].upper()}] ({iso_ts}): {msg['content']}")
        current_chunk_tokens += token_len

    if current_chunk_text:
        chunks.append("\n".join(current_chunk_text))
    print(f"[i] Created {len(chunks)} chunks.")
    return chunks

# --- 2. BUILD LOGIC ---
def build_memory_db(state):
    # SMART CHECK: If table exists but is empty, NUKE IT.
    if "memory" in state.db.table_names():
        tbl = state.db.open_table("memory")
        if len(tbl) > 0:
            print("[i] Memory table exists and is populated. Skipping build.")
            return
        else:
            print("[!] Memory table exists but is empty/corrupt. Rebuilding...")
            state.db.drop_table("memory")

    print("--- Starting One-Time Memory Build ---")
    if not os.path.isfile(ZIP_PATH):
        # CHANGE: Do not crash if zip is missing. Just warn and continue.
        # This allows the server to start even if no data is present (common in cloud deployments).
        print(f"[!] ZIP file not found at {ZIP_PATH}. Skipping build step.")
        print(f"[!] Please upload {ZIP_PATH} to populate memory.")
        return

    unzip_export(ZIP_PATH, UNZIP_DIR)
    messages = build_message_stream(UNZIP_DIR)
    if not messages:
        print("[!] No messages found. Creating empty table to prevent crash.")
        # Create dummy data to initialize schema if absolutely nothing found
        chunks = ["[SYSTEM] No history found."]
    else:
        chunks = split_into_chunks(messages, state.embedder.tokenizer)

    print(f"[+] Computing embeddings for {len(chunks)} chunks...")
    vectors = state.embedder.encode(chunks, batch_size=32, show_progress_bar=True, normalize_embeddings=True)

    print(f"[+] Creating LanceDB table at {LANCEDB_PATH}...")
    data = [{"vector": v.tolist(), "text": t} for v, t in zip(vectors, chunks)]
    state.db.create_table("memory", data=data)
    print("[✔] Memory build complete.")

# --- 3. API SERVER ---
app = FastAPI()

class AppState:
    def __init__(self):
        self.rag_enabled = RAG_ENABLED
        if not self.rag_enabled:
            self.embedder = None
            self.db = None
            self.table = None
            print("[!] RAG is disabled via ENABLE_RAG=false. Memory server will be read-only and return 503.")
            return
        print(f"[+] Loading embedding model '{EMBED_MODEL_NAME}'...")
        # Note: This loads the model into RAM. Ensure enough memory is available.
        self.embedder = SentenceTransformer(EMBED_MODEL_NAME, device=EMBED_DEVICE)
        print("[+] Connecting to LanceDB...")
        self.db = lancedb.connect(LANCEDB_PATH)
        if "memory" not in self.db.table_names():
             self.table = None
        else:
             self.table = self.db.open_table("memory")

state = AppState()

@app.get("/lookup")
def lookup(query: str, k: int = TOP_K_DEFAULT, token: str = Header(..., description="API secret token")):
    if not state.rag_enabled:
        raise HTTPException(status_code=503, detail="RAG is disabled.")
    if API_SECRET != "CHANGE_ME" and not secrets.compare_digest(token, API_SECRET):
        raise HTTPException(status_code=403, detail="Invalid API token.")
    if state.table is None:
        # Try to reload table if it was built after startup
        if "memory" in state.db.table_names():
            state.table = state.db.open_table("memory")
        else:
            raise HTTPException(status_code=503, detail="Memory DB not built.")

    query_vector = state.embedder.encode(query, normalize_embeddings=True)
    results = state.table.search(query_vector).limit(k).to_list()
    return {"query": query, "results": results}

@app.get("/")
def health_check():
    return {"status": "ok", "rag_enabled": state.rag_enabled, "chunks": len(state.table) if state.table else 0}

if __name__ == "__main__":
    if state.rag_enabled:
        build_memory_db(state)
        if state.table is None and "memory" in state.db.table_names():
            state.table = state.db.open_table("memory")
    if state.rag_enabled and API_SECRET == "CHANGE_ME":
        print("\n[!!!] WARNING: API_SECRET is set to the default 'CHANGE_ME'.")
        print("[!!!] Please set a secure secret as an environment variable for protection.\n")
    uvicorn.run(app, host=API_HOST, port=API_PORT)
