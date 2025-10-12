#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
build_memory.py
================
One-shot pipeline that turns a ChatGPT export zip into a searchable, lifelong
memory layer for a local LLM. This script uses the 2025 recommended stack.

This script will:
1. Build the memory store if it doesn't exist.
2. Always start the API server to provide memory lookups.
"""

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
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import orjson

# ----------------------------------------------------------------------
# USER-CONFIGURABLE CONSTANTS
# ----------------------------------------------------------------------
# --- File Paths ---
ZIP_PATH         = os.getenv("ZIP_PATH", "chatgpt_export.zip")
UNZIP_DIR        = os.getenv("UNZIP_DIR", "chatgpt_export")
LANCEDB_PATH     = os.getenv("LANCEDB_PATH", "memory.lancedb")

# --- Chunking & Embedding ---
CHUNK_TOKENS     = int(os.getenv("CHUNK_TOKENS", "5500"))
# Upgraded embedding model for best performance in 2025
EMBED_MODEL_NAME = "BAAI/bge-large-en-v1.5"
EMBED_DEVICE     = "cuda" if torch.cuda.is_available() else "cpu"

# --- API Configuration ---
API_HOST         = "0.0.0.0"
API_PORT         = int(os.getenv("API_PORT", "5000"))
TOP_K_DEFAULT    = int(os.getenv("TOP_K", "5"))
# IMPORTANT: Change this to a long, random string for security!
API_SECRET       = os.getenv("API_SECRET", "CHANGE_ME")
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# 1. DATA PARSING AND CHUNKING
# ----------------------------------------------------------------------
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
    conv_path = pathlib.Path(conv_dir) / "conversations"
    for p in tqdm(list(conv_path.rglob("*.json"))):
        with p.open("rb") as f:
            data = orjson.loads(f.read())
            for msg_id, msg_details in data.get("mapping", {}).items():
                if msg_details.get("message"):
                    msg = msg_details["message"]
                    role = msg.get("author", {}).get("role", "user")
                    ts = float(msg.get("create_time", 0.0))
                    parts = msg.get("content", {}).get("parts", [])
                    content = "\n".join(p for p in parts if isinstance(p, str)).strip()
                    if content:
                        msgs.append({"role": role, "timestamp": ts, "content": content})
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

# ----------------------------------------------------------------------
# 2. EMBEDDING AND DATABASE CREATION
# ----------------------------------------------------------------------
def build_memory_db(state):
    if os.path.exists(LANCEDB_PATH):
        print("[i] Memory database already exists. Skipping build.")
        return

    print("--- Starting One-Time Memory Build ---")
    if not os.path.isfile(ZIP_PATH):
        sys.exit(f"[✗] ZIP file not found at {ZIP_PATH}. Please upload it.")

    unzip_export(ZIP_PATH, UNZIP_DIR)
    messages = build_message_stream(UNZIP_DIR)
    chunks = split_into_chunks(messages, state.embedder.tokenizer)

    print(f"[+] Using pre-loaded embedding model '{EMBED_MODEL_NAME}' on device '{state.embedder.device}'.")

    print("[+] Computing embeddings (this can take several minutes)...")
    vectors = state.embedder.encode(chunks, batch_size=32, show_progress_bar=True, normalize_embeddings=True)

    print(f"[+] Creating LanceDB table at {LANCEDB_PATH}...")
    data = [{"vector": v.tolist(), "text": t} for v, t in zip(vectors, chunks)]
    state.db.create_table("memory", data=data)

    print("[✔] Memory build complete.")

# ----------------------------------------------------------------------
# 3. API SERVER (FastAPI)
# ----------------------------------------------------------------------
app = FastAPI()

class AppState:
    def __init__(self):
        print(f"[+] Loading embedding model '{EMBED_MODEL_NAME}' to device '{EMBED_DEVICE}'...")
        self.embedder = SentenceTransformer(EMBED_MODEL_NAME, device=EMBED_DEVICE)
        print("[+] Connecting to LanceDB...")
        self.db = lancedb.connect(LANCEDB_PATH)
        if "memory" not in self.db.table_names():
             print("[i] 'memory' table not found. It will be created on the first run.")
             self.table = None
        else:
             self.table = self.db.open_table("memory")

state = AppState()

class LookupResponse(BaseModel):
    query: str
    results: list[dict]

def verify_token(token: str):
    if API_SECRET == "CHANGE_ME":
        raise HTTPException(status_code=500, detail="API_SECRET is not set. Please configure it.")
    if not secrets.compare_digest(token, API_SECRET):
        raise HTTPException(status_code=403, detail="Invalid API token.")

@app.get("/lookup", response_model=LookupResponse)
def lookup(query: str, k: int = TOP_K_DEFAULT, token: str = Header(..., description="API secret token")):
    verify_token(token)

    if not query:
        raise HTTPException(status_code=400, detail="Query parameter cannot be empty.")

    if state.table is None:
        raise HTTPException(status_code=503, detail="Memory database not built yet. Please run the build process.")

    k = max(1, min(k, 20)) # Sanity cap

    query_vector = state.embedder.encode(query, normalize_embeddings=True)

    search_results = state.table.search(query_vector).limit(k).to_list()

    return {"query": query, "results": search_results}

@app.get("/")
def health_check():
    num_chunks = len(state.table) if state.table is not None else 0
    return {"status": "ok", "memory_chunks": num_chunks}

# ----------------------------------------------------------------------
# 4. MAIN EXECUTION BLOCK
# ----------------------------------------------------------------------
if __name__ == "__main__":
    build_memory_db(state)

    if state.table is None and "memory" in state.db.table_names():
        print("[i] Attaching to newly created 'memory' table.")
        state.table = state.db.open_table("memory")

    print(f"[+] Starting memory server at http://{API_HOST}:{API_PORT}")
    if API_SECRET == "CHANGE_ME":
        print("\n[!!!] WARNING: API_SECRET is set to the default 'CHANGE_ME'.")
        print("[!!!] Please set a secure secret in the script or as an environment variable for protection.\n")

    uvicorn.run(app, host=API_HOST, port=API_PORT)
