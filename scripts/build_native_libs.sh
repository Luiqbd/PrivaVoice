#!/bin/bash
# ============================================================
# PrivaVoice Native Libraries Build Script
# This script downloads and builds whisper.cpp and llama.cpp
# for Android (NDK)
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}PrivaVoice Native Libraries Builder${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check if NDK is installed
if [ -z "$ANDROID_NDK_HOME" ]; then
    if [ -d "$ANDROID_HOME/ndk/25.1.8937393" ]; then
        export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.1.8937393"
    elif [ -d "$ANDROID_SDK_ROOT/ndk/25.1.8937393" ]; then
        export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/25.1.8937393"
    else
        echo -e "${RED}Error: Android NDK not found!${NC}"
        echo "Please install NDK 25.1.8937393 via Android Studio SDK Manager"
        exit 1
    fi
fi

echo -e "${GREEN}Using NDK: $ANDROID_NDK_HOME${NC}"

# Create temp directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CPP_DIR="$PROJECT_DIR/android/app/src/main/cpp"
BUILD_DIR="$PROJECT_DIR/build_native"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo -e "${YELLOW}Cloning whisper.cpp...${NC}"
if [ ! -d "whisper.cpp" ]; then
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git
fi

echo -e "${YELLOW}Cloning llama.cpp (for ggml)...${NC}"
if [ ! -d "llama.cpp" ]; then
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git
fi

# Copy ggml from llama.cpp to whisper.cpp
cp -r llama.cpp/ggml whisper.cpp/

cd "$BUILD_DIR/whisper.cpp"

echo -e "${YELLOW}Building for Android (ARM64)...${NC}"

# Build whisper shared library for ARM64
mkdir -p build-android
cd build-android

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DBUILD_SHARED_LIBS=ON \
    -DWHISPER_BUILD_STATIC=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF

make -j$(nproc)

# Copy output to project
mkdir -p "$CPP_DIR"
cp libwhisper.so "$CPP_DIR/libwhisper-arm64-v8a.so"

echo -e "${GREEN}✓ libwhisper-arm64-v8a.so built!${NC}"

# Build for x86_64 (for emulators)
echo -e "${YELLOW}Building for Android (x86_64)...${NC}"
rm -rf *
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=x86_64 \
    -DANDROID_PLATFORM=android-24 \
    -DBUILD_SHARED_LIBS=ON \
    -DWHISPER_BUILD_STATIC=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF

make -j$(nproc)
cp libwhisper.so "$CPP_DIR/libwhisper-x86_64.so"

echo -e "${GREEN}✓ libwhisper-x86_64.so built!${NC}"

# Now build llama.cpp for TinyLlama
cd "$BUILD_DIR/llama.cpp"

echo -e "${YELLOW}Building llama.cpp for Android (ARM64)...${NC}"

mkdir -p build-android
cd build-android

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_BUILD_STATIC=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF

make -j$(nproc)

cp libllama.so "$CPP_DIR/libllama-arm64-v8a.so"
echo -e "${GREEN}✓ libllama-arm64-v8a.so built!${NC}"

# x86_64
rm -rf *
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=x86_64 \
    -DANDROID_PLATFORM=android-24 \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_BUILD_STATIC=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF

make -j$(nproc)
cp libllama.so "$CPP_DIR/libllama-x86_64.so"

echo -e "${GREEN}✓ libllama-x86_64.so built!${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Native libraries built successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Files created in: $CPP_DIR"
ls -la "$CPP_DIR"/*.so
echo ""
echo "Now run: flutter build apk --debug"
