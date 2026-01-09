#!/bin/bash

# Define variables
LLM_HOST="0.0.0.0"
LLM_PORT=8080
RAG_PORT=5000
MODEL_PATH="/workspace/runpod-babylegs/llama.cpp/models/model.gguf"

# 1. Start the Memory/RAG Server (Background)
echo "🧠 Starting RAG Server (Memory Builder)..."
# We pipe logs to file so we don't clutter the screen, but we can check them if needed
./vesper_env/bin/python3 build_memory.py > /workspace/rag_server.log 2>&1 &
RAG_PID=$!

# 2. Start the LLM Server (Background or Foreground based on flag)
echo "🤖 Starting Llama.cpp Server..."
# (Assuming standard llama-server command here - simplified for the patch)
./llama.cpp/llama-server \
    -m "$MODEL_PATH" \
    --host "$LLM_HOST" \
    --port "$LLM_PORT" \
    --ctx-size 32768 \
    --n-gpu-layers 99 \
    --parallel 4 \
    > /workspace/llm_server.log 2>&1 &
LLM_PID=$!

# 3. The "Patience" Loop
echo "⏳ Waiting for Memory to Build (This usually takes 5-10 minutes)..."
echo "   (You can follow progress in another terminal with: tail -f /workspace/rag_server.log)"

for i in {1..60}; do
    # Check if the process is still running
    if ! kill -0 $RAG_PID 2>/dev/null; then
        echo "❌ RAG Server process died! Check logs:"
        tail -n 10 /workspace/rag_server.log
        exit 1
    fi

    # Check if the API is responding
    if curl -s "http://127.0.0.1:$RAG_PORT/" > /dev/null; then
        echo "✅ Memory System Online!"
        break
    fi

    echo "   ... building memory (Attempt $i/60). Stand by."
    sleep 10
done

# Keep script running if foreground flag is used (simplified logic)
wait $LLM_PID
