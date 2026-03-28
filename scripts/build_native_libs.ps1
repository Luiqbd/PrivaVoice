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

# Clone llama.cpp
if (-not (Test-Path "llama.cpp")) {
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git
}

# Build Whisper for ARM64
Write-Host "Building Whisper ARM64..."
Set-Location "$BUILD_DIR\whisper.cpp"
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF
cmake --build . -- -j4

Copy-Item "src\libwhisper.so" "$CPP_DIR\libwhisper-arm64-v8a.so"
Write-Host "Done: libwhisper-arm64-v8a.so"

# Build Whisper for x86_64
Set-Location ".."
Remove-Item -Recurse -Force build
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF
cmake --build . -- -j4

Copy-Item "src\libwhisper.so" "$CPP_DIR\libwhisper-x86_64.so"
Write-Host "Done: libwhisper-x86_64.so"

# Build Llama for ARM64
Set-Location "$BUILD_DIR\llama.cpp"
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF
cmake --build . -- -j4

Copy-Item "src\libllama.so" "$CPP_DIR\libllama-arm64-v8a.so"
Write-Host "Done: libllama-arm64-v8a.so"

# Build Llama for x86_64
Set-Location ".."
Remove-Item -Recurse -Force build
New-Item -ItemType Directory -Force -Path build | Out-Null
Set-Location build

cmake .. -G "Ninja" -DCMAKE_TOOLCHAIN_FILE="$NDKHome\build\cmake\android.toolchain.cmake" -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-24 -DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF
cmake --build . -- -j4

Copy-Item "src\libllama.so" "$CPP_DIR\libllama-x86_64.so"
Write-Host "Done: libllama-x86_64.so"

Write-Host ""
Write-Host "Done! Native libraries built."
Get-ChildItem "$CPP_DIR" -Filter "*.so"
