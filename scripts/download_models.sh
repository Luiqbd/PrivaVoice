#!/bin/bash
# Download AI Models Script for PrivaVoice
# This script downloads the Whisper and TinyLlama models

echo "=== PrivaVoice AI Models Downloader ==="

# Create models directory
mkdir -p ../assets/models

# Whisper Models (choose one):
# tiny - 39 MB (fastest, least accurate)
# base - 74 MB
# small - 244 MB
# medium - 769 MB
# large - 1550 MB (most accurate, slowest)

echo "Downloading Whisper model (base - 74MB)..."
# Using GGML format for whisper.cpp
wget -q -O ../assets/models/whisper-base.bin "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" || echo "Failed to download Whisper"

# TinyLlama 1.1B 4-bit quantized (~700MB)
echo "Downloading TinyLlama 1.1B 4-bit quantized model..."
wget -q -O ../assets/models/tinyllama-1.1b-q4.bin "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" || echo "Failed to download TinyLlama"

echo "=== Download Complete ==="
ls -lh ../assets/models/
