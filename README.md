Sure. Here is the **complete copy-paste-ready `README.md` format**. You can copy everything inside the code block directly into your `README.md`.

````md
# HSV2 Lite

HSV2 Lite is a Flutter-based real-time detection and validation application focused on live camera monitoring, MediaPipe inference, and end-to-end latency analysis. The project is designed for real-world testing scenarios involving person detection, camera pipeline validation, and sustained performance evaluation.

## Overview

This repository combines:

- Live RGB and depth camera feeds
- MediaPipe-based object detection
- USB and camera status tracking
- Latency and FPS telemetry
- Sustained test execution and diagnostics
- Validation scripts for physical ground-truth comparison

The application is intended for research and engineering validation workflows, particularly around real-time detection quality and timing analysis.

## Features

- Live RGB and depth camera feed monitoring
- Real-time detection overlays on the camera stream
- MediaPipe inference latency tracking
- FPS, thermal, and battery telemetry
- USB connection and pipeline status tracking
- Stage 2 and Stage 4 visual analysis screens
- Sustained test and diagnostics flow
- CSV/JSON export support for performance results
- Physical validation scripts for E2E latency measurement

## Requirements

### Software

- Flutter SDK
- Dart SDK
- Android Studio / Android SDK
- Python 3.x
- OpenCV (`cv2`) for video analysis scripts
- Git

### Hardware

- Compatible Android device or desktop environment for app testing
- Camera hardware for live detection testing
- Intel RealSense D455 compatible camera for depth and calibration workflows
- USB access for device communication
- A system capable of running live inference and telemetry collection

## Project Structure

```text
hsv2-lite-main/
├── android/                  # Android native project
├── android_realsense_build/  # RealSense Android build assets
├── assets/                   # Application assets
├── lib/                      # Flutter source
│   ├── main.dart
│   ├── models/
│   ├── providers/
│   └── screens/
├── web/                      # Web app assets
├── validation/               # Validation data and test output
├── outputs/                  # Generated logs and artifacts
├── sustained_results/        # Sustained run results
├── Report/                   # Project reports
├── D455/                     # D455-related resources
├── DEPTH/                    # Depth resources
├── GROUND-PLANE/             # Ground-plane resources
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
├── README.md
├── sync_event.py
├── physical_gt_test.py
├── analyze_physical_e2e.py
├── auto_physical_e2e.py
├── auto_physical_gt.py
├── download_realsense.dart
├── download_ncnn.dart
├── extract_source.dart
├── imu_frame_sync.csv
├── metadata.csv
├── yolov8n.pt
└── ...
````

## Technologies Used

* Flutter
* Dart
* MediaPipe
* Camera APIs
* Intel RealSense / D455 support
* OpenCV
* Python-based validation tooling
* CSV/JSON result export

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd hsv2-lite-main
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Run the Application

```bash
flutter run
```

### Android

Build the Android APK:

```bash
flutter build apk
```

The generated APK can normally be found under:

```text
build/app/outputs/flutter-apk/
```

### Web

Run the application in Chrome:

```bash
flutter run -d chrome
```

## Usage

1. Start the application.
2. Check camera and USB connectivity.
3. Start the active camera pipeline.
4. Monitor object detections.
5. Monitor FPS and inference latency.
6. Open the Stage 2 visualization for detection and depth analysis.
7. Open the Stage 4 visualization for VIO-shaped concurrent processing.
8. Run diagnostics and sustained tests when required.
9. Export or inspect the generated validation results.

## Stage 2

Stage 2 focuses on the core detection and depth-processing pipeline.

```text
Camera Input
     ↓
RGB Frame
     ↓
MediaPipe Object Detection
     ↓
Bounding Box
     ↓
Depth Association
     ↓
Distance Estimation
     ↓
Direction Estimation
     ↓
Object + Distance + Direction
```

Example composite output:

```text
Person — 3.2 m — Left
Car    — 8.1 m — Center
Sign   — 5.4 m — Right
```

## Stage 4

Stage 4 extends the detection pipeline with a VIO-shaped concurrent compute load.

```text
Stage 2 Detection
       ↓
Object + 3D Information
       ↓
Stage 3 Outputs
       ↓
VIO-Shaped Load
       ↓
Feature Tracking
       ↓
Local 3D Point Cloud
       ↓
Concurrent Processing
       ↓
Composite Output
```

The Stage 4 visualization is intended to demonstrate:

* Feature tracking
* Local 3D point generation
* Concurrent processing
* Object detection
* Depth-based distance estimation
* Direction estimation
* End-to-end output generation

## Performance Monitoring

The application collects performance information including:

* FPS
* Inference latency
* End-to-end latency
* p50 latency
* p95 latency
* p99 latency
* Frame processing behavior
* Thermal information
* Battery information
* USB / camera pipeline status

Performance values should be reported from measured test runs rather than assumed targets.

## Validation Workflow

The project includes Python tools to measure physical and system latency.

### `sync_event.py`

Used to identify synchronization events or frames in recorded video.

```bash
python3 sync_event.py
```

### `physical_gt_test.py`

Used to compare external physical ground-truth recordings with application recordings.

```bash
python3 physical_gt_test.py
```

### `analyze_physical_e2e.py`

Used to analyze physical end-to-end latency and summarize metrics such as:

* p50
* p95
* p99
* minimum latency
* maximum latency
* sample count

```bash
python3 analyze_physical_e2e.py
```

### Automated Validation

The repository also contains:

```text
auto_physical_gt.py
auto_physical_e2e.py
```

These scripts support automated physical validation and E2E latency measurement workflows.

## RealSense D455

HSV2 Lite supports workflows involving the Intel RealSense D455 for RGB, depth, and IMU data.

Typical pipeline:

```text
RealSense D455
      │
      ├── RGB
      │
      ├── Depth
      │
      └── IMU
           ↓
      HSV2 Lite
           ↓
   Detection + Depth
           ↓
   Distance + Direction
```

RealSense-related resources are maintained under:

```text
D455/
DEPTH/
GROUND-PLANE/
android_realsense_build/
```

Hardware-specific configuration may be required depending on the Android device, USB connection, firmware, and RealSense integration.

## IMU Synchronization

The project includes IMU synchronization data and analysis resources.

Example file:

```text
imu_frame_sync.csv
```

The synchronization data can contain relationships between:

* RGB timestamps
* Depth timestamps
* Gyroscope timestamps
* Accelerometer timestamps
* Frame numbers
* Timestamp deltas

These measurements are intended for synchronization analysis and should be interpreted using the corresponding recorded test conditions.

## Sustained Testing

HSV2 Lite supports sustained runtime validation.

A typical sustained test evaluates:

```text
Application Start
      ↓
Camera Pipeline
      ↓
Object Detection
      ↓
Depth Processing
      ↓
Stage 4 Concurrent Load
      ↓
Continuous Runtime
      ↓
FPS / Latency / Thermal Monitoring
      ↓
Result Export
```

During sustained testing, monitor:

* Frame rate stability
* Latency stability
* Dropped frames
* CPU usage
* GPU/NPU usage where available
* Thermal behavior
* Battery behavior
* Memory behavior
* Camera pipeline stability

## Output and Results

Generated results may be stored in:

```text
outputs/
validation/
sustained_results/
Report/
```

Results can include:

* CSV files
* JSON files
* Logs
* Performance summaries
* Latency measurements
* Sustained test results
* Validation artifacts

## Development Notes

The project is under active development and may contain:

* Experimental modules
* Historical build artifacts
* Device-specific configurations
* Backup implementations
* Validation-only scripts
* Temporary debugging resources

Some components may require additional configuration before they can be reproduced on another system.

## Troubleshooting

### Flutter dependency issues

Run:

```bash
flutter clean
flutter pub get
```

Then rebuild:

```bash
flutter build apk
```

### Android build issues

Check:

```bash
flutter doctor
```

and verify:

* Android SDK
* Android SDK platform
* Android build tools
* Java/JDK configuration
* USB debugging

### Device connection

Check connected Android devices:

```bash
adb devices
```

If the device is not detected, verify:

* USB connection
* USB debugging
* ADB authorization
* USB permissions
* Correct cable/hub configuration

### RealSense connection

Verify:

* D455 connection
* USB bandwidth
* Device detection
* Camera permissions
* Compatible RealSense integration
* Required native libraries

## Research and Validation Scope

HSV2 Lite is intended primarily as a research and engineering validation platform.

The project focuses on:

* Real-time object detection
* RGB/depth camera processing
* Object distance estimation
* Direction estimation
* Feature tracking
* VIO-shaped concurrent workloads
* End-to-end latency measurement
* Camera/IMU synchronization
* Sustained runtime validation
* On-device performance analysis

## Important Notes

* Real-time performance depends on the device and camera configuration.
* RealSense/D455 functionality depends on compatible hardware and software configuration.
* Performance numbers should be taken from measured test runs.
* Experimental validation results should not be treated as universal device benchmarks.
* Historical or temporary files may exist in the repository.
* Some features may require device-specific setup.

## License

This repository does not currently show a clear license declaration in the inspected source files.

Please check the project ownership and repository policy before redistribution, modification, or commercial reuse.

## Status

HSV2 Lite is an experimental real-time detection and validation platform focused on:

* MediaPipe-based object detection
* RGB/depth processing
* Distance and direction estimation
* Feature tracking
* VIO-shaped concurrent processing
* Camera/IMU synchronization
* End-to-end latency measurement
* Sustained performance evaluation
* On-device validation

The system is being developed and validated through iterative hardware and software testing.

```
```
