# PrivaVoice Native Libraries Build Script

$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "PrivaVoice Native Libraries Builder"
Write-Host "========================================="

# Find NDK
$NDKHome = $null
$possiblePaths = @(
    "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\ndk\25.1.8937393",
    "$env:ANDROID_HOME\ndk\25.1.8937393"
)

foreach ($p in $possiblePaths) {
    if (Test-Path "$p\build\cmake\android.toolchain.cmake") {
        $NDKHome = $p
        break
    }
}

if (-not $NDKHome) {
    Write-Host "ERROR: NDK not found!"
    exit 1
}

Write-Host "Using NDK: $NDKHome"

$ProjectDir = "C:\Users\user\PrivaVoice"
$CPP_DIR = "$ProjectDir\android\app\src\main\cpp"
$BUILD_DIR = "$ProjectDir\build_native"

New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null
Set-Location $BUILD_DIR

# Clone whisper.cpp
if (-not (Test-Path "whisper.cpp")) {
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git
}

# Build Whisper for ARM64
Write-Host "Building Whisper ARM64..."
Set-Location "$BUILD_DIR\whisper.cpp"
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF
cmake --build . -- -j4

# Find the .so file
$whisperSo = Get-ChildItem -Recurse -Filter "libwhisper*.so" | Select-Object -First 1
if ($whisperSo) {
    Copy-Item $whisperSo.FullName "$CPP_DIR\libwhisper-arm64-v8a.so"
    Write-Host "Done: libwhisper-arm64-v8a.so"
} else {
    Write-Host "ERROR: libwhisper.so not found!"
}

# Build Whisper for x86_64
Set-Location ".."
Remove-Item -Recurse -Force build
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF
cmake --build . -- -j4

$whisperSo = Get-ChildItem -Recurse -Filter "libwhisper*.so" | Select-Object -First 1
if ($whisperSo) {
    Copy-Item $whisperSo.FullName "$CPP_DIR\libwhisper-x86_64.so"
    Write-Host "Done: libwhisper-x86_64.so"
}

# Delete old llama.cpp and re-clone fresh
if (Test-Path "llama.cpp") {
    Remove-Item -Recurse -Force "llama.cpp"
}

Write-Host "Cloning fresh llama.cpp..."
git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# Build GGML library for ARM64
Write-Host "Building GGML for ARM64..."
Set-Location "$BUILD_DIR\llama.cpp"
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_CLI=OFF -DLLAMA_BUILD_CONTEST=OFF -DLLAMA_BUILD_CV=OFF -DLLAMA_BUILD_LOOKUP=OFF -DLLAMA_BUILD_TRAIN=OFF
cmake --build . -- -j4

$llamaSo = Get-ChildItem -Recurse -Filter "libllama*.so" | Select-Object -First 1
if ($llamaSo) {
    Copy-Item $llamaSo.FullName "$CPP_DIR\libllama-arm64-v8a.so"
    Write-Host "Done: libllama-arm64-v8a.so"
}

# Build GGML for x86_64
Set-Location ".."
Remove-Item -Recurse -Force build
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_CLI=OFF -DLLAMA_BUILD_CONTEST=OFF -DLLAMA_BUILD_CV=OFF -DLLAMA_BUILD_LOOKUP=OFF -DLLAMA_BUILD_TRAIN=OFF
cmake --build . -- -j4

$llamaSo = Get-ChildItem -Recurse -Filter "libllama*.so" | Select-Object -First 1
if ($llamaSo) {
    Copy-Item $llamaSo.FullName "$CPP_DIR\libllama-x86_64.so"
    Write-Host "Done: libllama-x86_64.so"
}

Write-Host ""
Write-Host "Done! Native libraries built."
Get-ChildItem "$CPP_DIR" -Filter "*.so"
