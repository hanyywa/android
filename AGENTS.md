# Teman Isyarat — Agent Guide

## Quick Facts

- **What**: Flutter app for real-time Indonesian Sign Language (BISINDO) translation using MediaPipe hand/pose landmarks + custom TFLite classification model.
- **Structure**: Monolithic Flutter project (no feature modules). All Dart source in `lib/`. Android native layer in `android/`.
- **State**: No state management library — uses `StatefulWidget.setState()` everywhere.
- **DI**: None — dependencies created inline (manual `new`).
- **Networking**: None — fully offline, on-device inference.
- **Persistence**: Simple file I/O (`history.txt` via `path_provider`).

## Tool Versions (`.tool-versions`)

| Tool | Version |
|------|---------|
| Flutter | `3.41.9` |
| Kotlin | `2.3.21` |
| Gradle | `9.5.1` |
| Java | `openjdk-26` |
| FlutterGen | `5.14.1` |

## Source Layout

```
lib/
  main.dart                           # App entry, ALL widgets (pages, nav, article, settings)
  pages/
    translate_page.dart               # Camera + sign translation screen (408 lines)
  services/
    sign_language_engine.dart          # Orchestrator: buffer -> interpreter -> processor
    tflite_interpreter.dart            # TFLite model loading + inference
    prediction_processor.dart          # Softmax + temporal smoothing
    landmark_buffer.dart               # 125-frame circular buffer
  utils/
    landmark_assembler.dart            # Pose/hand -> 153-dim feature vector

android/app/src/main/kotlin/com/example/android/
  MainActivity.kt                      # FlutterActivity
  handlandmarker/
    HandLandmarkerPlugin.kt            # Flutter plugin registration
    HandLandmarkerView.kt              # PlatformView: CameraX + overlay
    HandLandmarkerHelper.kt            # MediaPipe Hand/Pose Landmarker wrapper
    HandLandmarkerOverlay.kt           # Canvas skeleton overlay
```

## Data Flow

```
Android CameraX (PlatformView)
  -> HandLandmarkerHelper (MediaPipe hand + pose)
  -> MethodChannel 'temanisyarat/hand_landmarker' (onLandmarks)
  -> translate_page.dart (convertLandmarks)
    -> SignLanguageEngine.onLandmarks()
      -> LandmarkAssembler.assembleFrame()    # 51 landmarks x 3 = 153-dim
      -> LandmarkBuffer.addFrame()             # 125-frame circular buffer
      -> SignLanguageInterpreter.predict()     # TFLite inference [1,125,153] -> [1,20]
      -> PredictionProcessor.process()         # Softmax + temporal smoothing
        -> setState() -> UI update
```

## Key Architecture Details

- **Input shape**: `[1, 125, 153]` — 125 frames, each with 51 landmarks (9 pose + 21 left hand + 21 right hand) × 3 (x,y,z).
- **Output shape**: `[1, 20]` — logits for 20 sign classes.
- **Classes**: `aku, apel, ayah, besok, buku, dia, dua, hari ini, ibu, kamu, kuning, maaf, merah, nama, pisang, salam, satu, teman, terima kasih, tiga`.
- **Temporal smoothing**: 10-frame history, 60% majority threshold.
- **Confidence threshold**: 0.7 (softmax probability).
- **Model file**: `assets/models/model_raw.tflite` (loaded via `tflite_flutter`).
- **Pose indices used**: `[0, 11, 12, 13, 14, 15, 16, 23, 24]` (nose, shoulders, elbows, wrists, hips).
- **Missing landmarks**: encoded as `NaN` in the feature vector.

## Conventions

- **Code style**: `package:flutter_lints/flutter.yaml` (default Flutter lints). No custom rules.
- **Naming**: Classes are PascalCase, files are snake_case. Widgets use `Widget` suffix inconsistently.
- **Keys**: All widgets use `super.key` constructor pattern.
- **Imports**: Relative paths (e.g., `'../services/...'`).
- **Android**: Kotlin, `com.android.application` + `kotlin-android` plugins, compileSdk/ndkVersion from Flutter Gradle plugin, minSdk 24, Java 17 target.
- **No comments** in source code (doc comments, inline comments are absent).
- **No tests** covering actual app logic — the only test (`test/widget_test.dart`) is the unused Flutter counter template.

## Routes

| Path | Trigger | Widget | File |
|------|---------|--------|------|
| `/` | App start | `MainPage` (bottom nav: Home/Belajar/Artikel) | `lib/main.dart` |
| Translate | Home button | `TranslatePage` | `lib/pages/translate_page.dart` |
| Artikel | List item tap | `DetailArtikel` | `lib/main.dart` |
| Settings | Appbar menu | `SettingsPage` | `lib/main.dart` |

## Dependencies (pubspec.yaml)

- `permission_handler: ^12.0.1` — camera permission
- `tflite_flutter: ^0.12.1` — TFLite inference
- `path_provider: ^2.1.5` — file paths
- `flutter_launcher_icons: ^0.14.4` (dev) — icon generation

## Android Dependencies (build.gradle.kts)

- `androidx.camera:camera-*:1.4.2` — CameraX
- `com.google.mediapipe:tasks-vision:0.10.29` — MediaPipe Hand/Pose Landmarker
- `org.tensorflow:tensorflow-lite:2.14.0` — TFLite runtime
- `org.tensorflow:tensorflow-lite-select-tf-ops:2.14.0`

## Known Issues / Gaps

- No CI/CD pipeline.
- Release signing uses debug config.
- AndroidManifest namespace (`com.example.android`) doesn't match app ID (`com.temanisyarat.android`).
- Two `MainActivity.kt` files exist (one in `com.example.android`, one in `com.example.temanisyarat`) — likely a merge artifact.
- Android `settings.gradle.kts` uses Kotlin DSL, some Gradle plugin versions may need updating for compatibility.
- `GestureDetector` in `CustomAppBar` onTap for Settings may conflict with `MenuButton` placement in production.

## How to Run

```bash
flutter run                          # default device
flutter run -d <device-id>          # specific device
flutter build apk                    # Android release build
flutter build ios                    # iOS release build
flutter analyze                      # lint check
flutter test                         # run tests
flutter pub get                      # install deps
```

## Common Tasks

- **Add new sign class**: Update `classLabels` in `prediction_processor.dart`, retrain model, replace `model_raw.tflite`.
- **Add new page/screen**: Add widget to `main.dart` or new file in `lib/pages/`, use `Navigator.push`.
- **Modify landmark selection**: Edit `poseIndices` in `landmark_assembler.dart` and adjust frame dimension.
- **Change buffer size**: Change `maxLength` (125) in `landmark_buffer.dart` and update model input shape accordingly.
- **Tune smoothing**: Change `historySize` (10) and threshold (0.6) in `prediction_processor.dart`.
