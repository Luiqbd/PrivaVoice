#!/bin/bash
# Download AI Models Script for PrivaVoice
# Models are too large for Git, download separately after clone

set -e

echo "=== PrivaVoice AI Models Downloader ==="
echo ""

# Create models directory
mkdir -p ../assets/models

# Whisper model (GGML format for whisper.cpp)
echo "Downloading Whisper model (142MB)..."
wget -q -O ../assets/models/whisper-base.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"

# TinyLlama 1.1B 4-bit quantized (~638MB)
echo "Downloading TinyLlama 1.1B 4-bit (638MB)..."
wget -q -O ../assets/models/tinyllama-1.1b-q4.bin \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

echo ""
echo "=== Download Complete ==="
echo "Models location: assets/models/"
ls -lh ../assets/models/
echo ""
echo "Total: $(du -sh ../assets/models | cut -f1)"
