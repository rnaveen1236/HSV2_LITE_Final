class DetectionResult {
  final String objectName;
  final double confidence;
  final double distanceMeters;
  final String directionClock;
  final List<double> boundingBox; // [x, y, width, height]

  DetectionResult({
    required this.objectName,
    required this.confidence,
    required this.distanceMeters,
    required this.directionClock,
    required this.boundingBox,
  });
}

class TelemetryData {
  final double fps;
  final double p50LatencyMs;
  final double p95LatencyMs;
  final double p99LatencyMs;
  final double cpuUsage;
  final double thermalState;
  final double batteryLevel;
  final double batteryTemperature;
  final int droppedFrames;
  final double usbTransportLatencyMs;
  final double centerDistanceMeters;

  // Live D455 IMU telemetry
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroTimestampMs;
  final double accelTimestampMs;
  final int gyroCount;
  final int accelCount;

  TelemetryData({
    this.fps = 0.0,
    this.p50LatencyMs = 0.0,
    this.p95LatencyMs = 0.0,
    this.p99LatencyMs = 0.0,
    this.cpuUsage = 0.0,
    this.thermalState = 0.0,
    this.batteryLevel = 100.0,
    this.batteryTemperature = 0.0,
    this.droppedFrames = 0,
    this.usbTransportLatencyMs = 0.0,
    this.centerDistanceMeters = 0.0,
    this.gyroX = 0.0,
    this.gyroY = 0.0,
    this.gyroZ = 0.0,
    this.accelX = 0.0,
    this.accelY = 0.0,
    this.accelZ = 0.0,
    this.gyroTimestampMs = 0.0,
    this.accelTimestampMs = 0.0,
    this.gyroCount = 0,
    this.accelCount = 0,
  });
}

enum PipelineStage {
  stage1,
  stage2,
  stage3,
  stage4,
}

class StageConfig {
  final PipelineStage currentStage;
  final bool isStage3Enabled; // Feature flag for stage 3

  StageConfig({
    required this.currentStage,
    this.isStage3Enabled = false,
  });
}
