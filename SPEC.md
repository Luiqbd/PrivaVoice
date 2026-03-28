# PrivaVoice - Specification Document

## 1. Project Overview

**Project Name:** PrivaVoice  
**Project Type:** Android Mobile Application (Flutter)  
**Core Functionality:** On-Device AI-powered voice transcription and processing with military-grade security, designed for professional use in Legal, Medical, and Corporate sectors.

---

## 2. Technology Stack & Choices

### Framework & Language
- **Framework:** Flutter 3.x
- **Language:** Dart 3.x
- **Minimum Android SDK:** 24 (Android 7.0)
- **Target Android SDK:** 34

### Key Libraries/Dependencies
| Category | Library | Purpose |
|----------|---------|---------|
| AI/ML | whisper.cpp (via dart_ffigen) | Speech-to-text with GPU/NPU acceleration |
| AI/ML | flutter_llama (TinyLlama 1.1B 4-bit) | Local NLP processing |
| Security | local_auth | Biometric authentication |
| Security | flutter_secure_storage | Encrypted key storage |
| Security | encrypt | AES-256 GCM encryption |
| State | flutter_bloc | State management |
| DI | get_it | Dependency injection |
| Database | drift (SQLite) | Local database for transcriptions |
| Audio | record | Audio recording |
| Audio | just_audio | Audio playback |
| Payments | in_app_purchase | Offline payment validation |
| UI | google_fonts | Typography |
| Utils | path_provider | File system access |
| Utils | permission_handler | Runtime permissions |

### State Management
- **Primary:** BLoC (Business Logic Component) pattern
- **Architecture:** Clean Architecture (Data, Domain, Presentation)

### Architecture Pattern
- **Clean Architecture** with 3 layers:
  - **Data Layer:** Repositories, Data Sources, Models
  - **Domain Layer:** Entities, Use Cases, Repository Interfaces
  - **Presentation Layer:** BLoCs, Widgets, Pages

---

## 3. Feature List

### AI & Processing
- [ ] Whisper.cpp integration via Dart FFI with GPU/NPU acceleration
- [ ] Word-level timestamp extraction for karaoke effect
- [ ] SeekTo functionality via word index
- [ ] Speaker diarization (voice separation)
- [ ] TinyLlama 1.1B 4-bit for NLP (summaries, action items)
- [ ] Dynamic model loading/unloading
- [ ] Background Isolate processing for UI performance

### Security (Zero Trust)
- [ ] Remove INTERNET permission (100% offline)
- [ ] AES-256 GCM encryption for audio files and transcriptions
- [ ] Biometric authentication (fingerprint/face) for app lock
- [ ] Secure folder vault with biometric protection
- [ ] Foreground Service with priority notifications
- [ ] Auto-save transactional backup every 30 seconds

### Commercial & Monetization
- [ ] Offline in_app_purchase implementation
- [ ] Local Receipt Validation with encrypted cache
- [ ] 3-window onboarding flow (Legal, Medical, Corporate niches)
- [ ] Glassmorphism design for onboarding
- [ ] Pricing display: R$149,40/month with 50% OFF highlight
- [ ] 7-day free trial CTA button

### UI/UX
- [ ] Dark Mode base (#0A0A0A)
- [ ] Neon accent details (Cyan #00FFFF, Magenta #FF00FF)
- [ ] Haptic Feedback on interactions
- [ ] Whispers models bundled in assets (~500MB)
- [ ] TinyLlama model bundled in assets (~200MB)
- [ ] 60fps UI performance target

---

## 4. UI/UX Design Direction

### Overall Visual Style
- **Primary:** Dark Mode with Cyberpunk/Sci-Fi aesthetic
- **Design Elements:** Glassmorphism for modals/onboarding, Neon glow effects
- **Typography:** Roboto Mono for code/timestamps, Inter for body text

### Color Scheme
| Element | Color |
|---------|-------|
| Background Primary | #0A0A0A |
| Background Secondary | #141414 |
| Surface | #1E1E1E |
| Primary Accent | #00FFFF (Cyan) |
| Secondary Accent | #FF00FF (Magenta) |
| Success | #00FF88 |
| Error | #FF3366 |
| Text Primary | #FFFFFF |
| Text Secondary | #B0B0B0 |

### Layout Approach
- **Navigation:** Bottom navigation bar (4 tabs: Record, Library, Vault, Settings)
- **Recording Screen:** Full-screen with waveform visualization
- **Transcription Screen:** Scrollable with word-level highlighting
- **Onboarding:** Horizontal pager with 3 screens and Glassmorphism cards

### Interaction Design
- Haptic feedback on record start/stop
- Haptic feedback on transcription word tap (seekTo)
- Smooth animations with 60fps target
- Pull-to-refresh in library

---

## 5. Android Configuration

### Permissions Required
```xml
<!-- EXPLICITLY REMOVED: INTERNET permission -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

### Build Configuration
- minSdkVersion: 24
- targetSdkVersion: 34
- NDK: r21b (for FFI compilation)
- CMake: 3.22.1

---

## 6. File Structure (Clean Architecture)

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── errors/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── blocs/
    ├── pages/
    └── widgets/
```