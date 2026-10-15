# Local LLaMA for Android 🚀

Run Large Language Models (LLMs) completely offline, locally, and private on Android devices using native C++ [llama.cpp](https://github.com/ggerganov/llama.cpp) inference and modern Jetpack Compose.

---

## 📖 Table of Contents

- [Overview & Architecture](#-overview--architecture)
- [Project Evolution: Phase 1 vs Phase 2](#-project-evolution-phase-1-vs-phase-2)
  - [Phase 1: CLI Benchmark & Native Proof-of-Concept](#phase-1-cli-benchmark--native-proof-of-concept)
  - [Phase 2: Full Native Android GUI Application](#phase-2-full-native-android-gui-application)
- [Hardware & Software Compatibility Matrix](#-hardware--software-compatibility-matrix)
- [Engineering Fixes & Adaptations (Samsung S10+ Support)](#-engineering-fixes--adaptations-samsung-s10-support)
- [Quick Start Guide](#-quick-start-guide)
- [How It Works Under the Hood](#-how-it-works-under-the-hood)
- [Supported Models & Formats](#-supported-models--formats)
- [Troubleshooting & FAQs](#-troubleshooting--faqs)

---

## 🧠 Overview & Architecture

This repository enables **100% on-device AI chat** without internet access, third-party APIs, or external server dependencies.

```
┌────────────────────────────────────────────────────────┐
│                   Android Device                       │
│                                                        │
│   ┌────────────────────────────────────────────────┐   │
│   │        Jetpack Compose UI (Kotlin)             │   │
│   │         Chat Interface & Model Picker          │   │
│   └───────────────────────┬────────────────────────┘   │
│                           │ JNI (Java Native Interface)│
│   ┌───────────────────────▼────────────────────────┐   │
│   │       libai-chat.so (C++ JNI Bridge)           │   │
│   └───────────────────────┬────────────────────────┘   │
│                           │ Native C++ Calls           │
│   ┌───────────────────────▼────────────────────────┐   │
│   │             llama.cpp + ggml core              │   │
│   │       (OpenMP Multithreading + ARM NEON)       │   │
│   └───────────────────────┬────────────────────────┘   │
│                           │ mmap Zero-Copy             │
│   ┌───────────────────────▼────────────────────────┐   │
│   │        GGUF Model File (e.g. Qwen2.5 1.5B)     │   │
│   │        /sdcard/Download/*.gguf (~1.12 GB)      │   │
│   └────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

---

## 🔄 Project Evolution: Phase 1 vs Phase 2

### Phase 1: CLI Benchmark & Native Proof-of-Concept
- **Goal:** Validate that ARMv8-A CPU cores can run quantized LLMs with acceptable tokens-per-second before building complex UI.
- **Implementation:**
  - Cross-compiled `llama.cpp` using Android NDK standalone toolchain (`clang++`).
  - Produced `llama-cli` ELF binary and dependent shared libraries (`libllama.so`, `libggml.so`).
  - Automated deployment using [`deploy_and_test.ps1`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/deploy_and_test.ps1).
  - Pushed binaries and model directly to `/data/local/tmp/llama`.
  - Executed inference over ADB shell:
    ```bash
    export LD_LIBRARY_PATH=/data/local/tmp/llama
    /data/local/tmp/llama/llama-cli -m /data/local/tmp/llama/qwen2.5-1.5b-instruct-q4_k_m.gguf -c 2048 -n 128 -t 4 -p "Explain how a CPU executes a program."
    ```
- **Outcome:** Successfully verified real-time inference speed (~15–25 tokens/s) on mobile ARM processors.

---

### Phase 2: Full Native Android GUI Application
- **Goal:** Turn the command-line tool into a standalone, consumer-friendly Android application with a chat UI.
- **Implementation:**
  - Integrated `llama.android` project structure consisting of two modules:
    - `:lib`: Native C++ library (`CMakeLists.txt` + `ai_chat.cpp` JNI wrapper around `llama.cpp`).
    - `:app`: Android application layer written in Kotlin with Jetpack Compose & Material 3.
  - Built full one-click automation via [`run_android_app.ps1`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/run_android_app.ps1):
    1. Verifies USB-connected device via ADB.
    2. Installs required Android SDK platforms automatically.
    3. Builds the optimized debug APK via Gradle + CMake + Ninja.
    4. Streams and installs the APK to the device.
    5. Pushes the GGUF model to `/sdcard/Download/` (with duplicate detection).
    6. Automatically launches the chat activity.

---

## 💻 Hardware & Software Compatibility Matrix

### 📱 Target Device (Android) Requirements

| Component | Minimum Specification | Recommended Specification |
|---|---|---|
| **CPU Architecture** | `arm64-v8a` (64-bit ARM) | `arm64-v8a` / ARMv8.2-A+ with DotProd/FP16 |
| **System RAM** | 4 GB | 6 GB – 8 GB+ |
| **Free Storage** | ~2.5 GB (1.12 GB model + APK & context cache) | 5 GB+ (allows 3B–7B models) |
| **Android OS** | Android 9.0 (API 28) | Android 12+ (API 31–36) |
| **Verified Devices** | **Samsung Galaxy S10+ (`SM-G975F`, Android 12 / API 31)** | Pixel 6/7/8/9, Galaxy S21/S22/S23/S24 |

> [!NOTE]
> 32-bit devices (`armeabi-v7a`) and x86 32-bit are **not supported**. The project is strictly optimized for 64-bit ARM (`arm64-v8a`).

---

### 🖥️ Host Development System Requirements

| Tool | Version / Requirement |
|---|---|
| **Operating System** | Windows 10/11, macOS, or Linux |
| **Android SDK Platform** | Android 14/15/16 SDK (`android-36` installed via `sdkmanager`) |
| **Android NDK** | `27.0.12077973` (or NDK r25+) |
| **CMake & Ninja** | CMake 3.22.1+ and Ninja (included with Android SDK) |
| **Java Development Kit** | JDK 17 (Java 17) |
| **Python** | Python 3.8+ (for model downloader script) |

---

## 🛠️ Engineering Fixes & Adaptations (Samsung S10+ Support)

During Phase 2, adapting modern AndroidX dependencies to older hardware (like the Samsung Galaxy S10+ running Android 12 / API 31) required several technical resolutions:

### 1. `INSTALL_FAILED_OLDER_SDK` Fix
- **Problem:** Modern template default had `minSdk = 33`, preventing installation on Android 12 (`Failure [INSTALL_FAILED_OLDER_SDK: Requires newer sdk version #33 (current version is #31)]`).
- **Fix:** Lowered `minSdk` to `28` in both [`app/build.gradle.kts`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/llama.cpp/examples/llama.android/app/build.gradle.kts) and [`lib/build.gradle.kts`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/llama.cpp/examples/llama.android/lib/build.gradle.kts) while keeping `compileSdk = 36` to satisfy modern AndroidX dependencies.

### 2. Native C++ Clang Compilation Failure (`__android_log_is_loggable`)
- **Problem:** When targeting older NDK levels (`minSdk < 30`), Clang 18 threw a fatal compiler error:
  ```text
  logging.h:26:12: error: '__android_log_is_loggable' is unavailable: introduced in Android 30
  ```
- **Fix:** In [`lib/src/main/cpp/logging.h`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/llama.cpp/examples/llama.android/lib/src/main/cpp/logging.h), guarded the log level check with `#if __ANDROID_API__ >= 30` with fallback for API 28/29:
  ```cpp
  static inline int ai_should_log(int prio) {
  #if __ANDROID_API__ >= 30
      return __android_log_is_loggable(prio, LOG_TAG, LOG_MIN_LEVEL);
  #else
      return prio >= LOG_MIN_LEVEL;
  #endif
  }
  ```

### 3. Kotlin Compiler DSL Migration
- **Problem:** Gradle 8+ deprecated `kotlinOptions.jvmTarget = "17"`, throwing build errors.
- **Fix:** Migrated to the modern `compilerOptions` DSL in [`app/build.gradle.kts`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/llama.cpp/examples/llama.android/app/build.gradle.kts):
  ```kotlin
  kotlin {
      compilerOptions {
          jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
      }
  }
  ```

### 4. PowerShell Compatibility for Windows
- **Problem:** Windows PowerShell 5.1 default UTF-8 encoding without BOM caused non-ASCII characters (box-drawing dashes) to corrupt AST parsing blocks.
- **Fix:** Cleaned [`run_android_app.ps1`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/run_android_app.ps1) to pure ASCII for universal compatibility across PowerShell 5.1 and PowerShell 7.

---

## 🚀 Quick Start Guide

### Step 1: Clone and Prepare Model
1. Ensure your Android device is connected via USB with **USB Debugging enabled** (`Developer Options -> USB Debugging`).
2. Download the recommended model (Qwen 2.5 1.5B Instruct, 4-bit quantized, ~1.12 GB):
   ```powershell
   python download_model.py
   ```

### Step 2: One-Click Build & Launch
Run the automated pipeline:
```powershell
.\run_android_app.ps1
```

The script will automatically:
1. Verify device connection via ADB.
2. Ensure Android SDK Platform 36 is present.
3. Compile native C++ libraries and APK.
4. Install the APK on your device.
5. Transfer the model file to `/sdcard/Download/`.
6. Launch the app.

### Step 3: Start Chatting
1. On your phone screen, tap the **Load Model** / **Select Model** button.
2. In the file picker, navigate to **Downloads** (or `Galaxy S10+` -> `Download`).
3. Select `qwen2.5-1.5b-instruct-q4_k_m.gguf`.
4. The model will load into memory, and you can chat offline!

---

## 🔬 How It Works Under the Hood

1. **Model Loading:** The GGUF format allows memory-mapped I/O (`mmap`), meaning the model weights are mapped directly from internal storage into virtual memory without copying the entire 1.12 GB into JVM heap space.
2. **Quantization (Q4_K_M):** 4-bit medium quantization compresses 16-bit floating point weights down to ~4.5 bits per parameter with minimal loss in reasoning quality, keeping memory consumption low enough for mobile RAM.
3. **Threading:** Inference uses OpenMP with 4 execution threads matching the performance/big CPU cores of the device to maximize throughput while preventing thermal throttling.
4. **Token Generation:** The C++ core streams generated tokens one-by-one via JNI callbacks into Jetpack Compose state, creating real-time streaming text in the UI.

---

## 📦 Supported Models & Formats

Any model in standard **GGUF** format compatible with `llama.cpp` can be loaded. Depending on your phone's RAM:

| Model | Size | Recommended RAM | Notes |
|---|---|---|---|
| **Qwen 2.5 0.5B** | ~400 MB | 3 GB+ | Ultra-fast, lightweight |
| **Qwen 2.5 1.5B (Default)** | ~1.12 GB | 4 GB – 6 GB | Outstanding balance of speed & intelligence |
| **Llama 3.2 1B** | ~800 MB | 4 GB+ | Fast, conversational |
| **Llama 3.2 3B** | ~2.0 GB | 6 GB+ | High quality reasoning |
| **Phi-3.5 Mini (3.8B)** | ~2.2 GB | 6 GB – 8 GB | Great coding and logic |

To use a different model, place its `.gguf` file into the `models/` directory, update `modelSrc` in [`run_android_app.ps1`](file:///c:/Users/sreej/Desktop/Projects/local-llama-android/run_android_app.ps1) (or copy via `adb push`), and select it in the app.

---

## ❓ Troubleshooting & FAQs

### Q: Where is the model file on my phone?
**A:** It is stored at:
```text
/sdcard/Download/qwen2.5-1.5b-instruct-q4_k_m.gguf
```
Inside the app file picker, navigate to the **Downloads** directory to select it.

### Q: How do I verify my phone is recognized by ADB?
Run:
```powershell
adb devices -l
```
If your device shows `unauthorized`, unlock your phone screen and tap **"Always allow from this computer"** on the USB prompt.

### Q: The app closes when loading larger models. Why?
If a model requires more memory than your phone's available RAM, the Android system LMK (Low Memory Killer) will terminate the process. For devices with 4–6 GB RAM, stick to **1B–1.5B Q4_K_M** models.
