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
from fastapi import FastAPI, HTTPException, Header
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
EMBED_DEVICE     = os.getenv("RAG_DEVICE", "cuda" if torch.cuda.is_available() else "cpu")

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

    # Strategy 1: Look for single 'conversations.json' (Standard Export)
    # We check conv_dir/conversations.json
    single_file = pathlib.Path(conv_dir) / "conversations.json"

    # If not found there, check if it's inside a subdirectory (common if zip contained a folder)
    if not single_file.exists():
         # Simple check one level deep
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

        # Ensure we have a list of conversations
        conversations = []
        if isinstance(data, list):
            conversations = data
        elif isinstance(data, dict) and "mapping" in data:
            # Single conversation dict
            conversations = [data]

        for conv in tqdm(conversations, desc="Processing conversations"):
            mapping = conv.get("mapping", {})
            for msg_id, msg_details in mapping.items():
                if msg_details.get("message"):
                    msg = msg_details["message"]
                    role = msg.get("author", {}).get("role", "user")

                    # Robust timestamp handling
                    create_time = msg.get("create_time")
                    try:
                        ts = float(create_time) if create_time is not None else 0.0
                    except (ValueError, TypeError):
                        ts = 0.0

                    parts = msg.get("content", {}).get("parts", [])
                    # Robust content handling
                    content_list = []
                    for p in parts:
                        if isinstance(p, str):
                            content_list.append(p)
                        elif p is not None:
                            content_list.append(str(p))

                    content = "\n".join(content_list).strip()

                    if content:
                        msgs.append({"role": role, "timestamp": ts, "content": content})

    else:
        # Strategy 2: Look for 'conversations' directory with multiple JSONs (Legacy/Custom)
        conv_path = pathlib.Path(conv_dir) / "conversations"
        if conv_path.is_dir():
            print(f"[+] Scanning directory: {conv_path}")
            for p in tqdm(list(conv_path.rglob("*.json"))):
                with p.open("rb") as f:
                    try:
                        data = orjson.loads(f.read())
                    except:
                        continue

                    # Assuming each file is a conversation dict
                    mapping = data.get("mapping", {})
                    for msg_id, msg_details in mapping.items():
                        if msg_details.get("message"):
                            msg = msg_details["message"]
                            role = msg.get("author", {}).get("role", "user")

                            create_time = msg.get("create_time")
                            try:
                                ts = float(create_time) if create_time is not None else 0.0
                            except:
                                ts = 0.0

                            parts = msg.get("content", {}).get("parts", [])
                            content = "\n".join(str(p) for p in parts if p is not None).strip()

                            if content:
                                msgs.append({"role": role, "timestamp": ts, "content": content})
        else:
            print(f"[!] No conversations found in {conv_dir}.")
            print(f"    Checked: {single_file} and {conv_path}")

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
    # The lancedb.connect call in AppState implicitly creates the directory.
    # To prevent skipping the build on a first run, we must check for the table's existence.
    if "memory" in state.db.table_names():
        tbl = state.db.open_table("memory")
        if len(tbl) > 0:
            print("[i] Memory table exists and is populated. Skipping build.")
            return
        else:
            print("[!] Memory table exists but is empty. Rebuilding...")
            state.db.drop_table("memory")

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

class MemoryMessage(BaseModel):
    role: str
    content: str
    timestamp: float | None = None

class AddMemoryRequest(BaseModel):
    messages: list[MemoryMessage]

@app.post("/add")
def add_memory(request: AddMemoryRequest, token: str = Header(..., description="API secret token")):
    verify_token(token)

    if not request.messages:
         raise HTTPException(status_code=400, detail="No messages provided.")

    if state.table is None:
        raise HTTPException(status_code=503, detail="Memory database not ready.")

    # 1. Prepare messages
    msgs = []
    for m in request.messages:
        ts = m.timestamp if m.timestamp is not None else datetime.now(timezone.utc).timestamp()
        msgs.append({"role": m.role, "timestamp": ts, "content": m.content})

    # 2. Chunk
    # We reuse the existing chunking logic which formats them nicely
    chunks = split_into_chunks(msgs, state.embedder.tokenizer)

    if not chunks:
        return {"status": "ok", "added": 0, "message": "No chunks created (content too short?)"}

    # 3. Embed
    print(f"[+] Embedding {len(chunks)} new chunks...")
    vectors = state.embedder.encode(chunks, batch_size=32, show_progress_bar=False, normalize_embeddings=True)

    # 4. Insert
    print(f"[+] Inserting into LanceDB...")
    data = [{"vector": v.tolist(), "text": t} for v, t in zip(vectors, chunks)]
    state.table.add(data)

    return {"status": "ok", "added": len(data)}

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
