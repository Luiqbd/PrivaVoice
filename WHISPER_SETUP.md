# Whisper AAR Setup (Required for build)

## The Problem
The whisper-android.aar (56MB) is too large for git, so it's excluded via .gitignore.

## Solution: Download manually

### Option 1: Direct Download
```powershell
# Create the folder
New-Item -ItemType Directory -Force -Path android\app\libs

# Download the AAR (56MB)
Invoke-WebRequest -Uri "https://github.com/HadesNull123/Whisper-Android-Lib/releases/download/release/whisper-lib-release.aar" -OutFile "android\app\libs\whisper-android.aar"
```

### Option 2: Browser
1. Go to: https://github.com/HadesNull123/Whisper-Android-Lib/releases
2. Download `whisper-lib-release.aar`
3. Save as: `android/app/libs/whisper-android.aar`

## Build
```powershell
flutter build apk --release
```

## What's Included
- libtensorflowlite.so (TFLite runtime)
- whisper-tiny.tflite (model)
- Java/Kotlin classes for audio recording & transcription
