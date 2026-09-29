import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  static const List<String> cocoClasses = [
    'Person',
    'Bicycle',
    'Car',
    'Motorcycle',
    'Airplane',
    'Bus',
    'Train',
    'Truck',
    'Boat',
    'Traffic Light',
    'Fire Hydrant',
    'Stop Sign',
    'Parking Meter',
    'Bench',
    'Bird',
    'Cat',
    'Dog',
    'Horse',
    'Sheep',
    'Cow',
    'Elephant',
    'Bear',
    'Zebra',
    'Giraffe',
    'Backpack',
    'Umbrella',
    'Handbag',
    'Tie',
    'Suitcase',
    'Frisbee',
    'Skis',
    'Snowboard',
    'Sports Ball',
    'Kite',
    'Baseball Bat',
    'Baseball Glove',
    'Skateboard',
    'Surfboard',
    'Tennis Racket',
    'Bottle',
    'Wine Glass',
    'Cup',
    'Fork',
    'Knife',
    'Spoon',
    'Bowl',
    'Banana',
    'Apple',
    'Sandwich',
    'Orange',
    'Broccoli',
    'Carrot',
    'Hot Dog',
    'Pizza',
    'Donut',
    'Cake',
    'Chair',
    'Couch',
    'Potted Plant',
    'Bed',
    'Dining Table',
    'Toilet',
    'TV',
    'Laptop',
    'Mouse',
    'Remote',
    'Keyboard',
    'Cell Phone',
    'Microwave',
    'Oven',
    'Toaster',
    'Sink',
    'Refrigerator',
    'Book',
    'Clock',
    'Vase',
    'Scissors',
    'Teddy Bear',
    'Hair Drier',
    'Toothbrush'
  ];

  static const MethodChannel _commandChannel =
      MethodChannel('com.hsv2/command');
  static const EventChannel _telemetryChannel =
      EventChannel('com.hsv2/telemetry');
  static const EventChannel _usbStatusChannel =
      EventChannel('com.hsv2/usb_status');

  int? _textureId;
  int? get textureId => _textureId;

  int? _depthTextureId;
  int? get depthTextureId => _depthTextureId;

  // Telemetry
  TelemetryData _telemetry = TelemetryData();
  TelemetryData get telemetry => _telemetry;

  // Pipeline Status
  bool _isPipelineRunning = false;
  bool get isPipelineRunning => _isPipelineRunning;

  // Camera Connection Status
  String _usbStatus = kIsWeb ? "CONNECTED" : "DISCONNECTED";
  String get usbStatus => _usbStatus;
  bool get isCameraConnected => _usbStatus == "CONNECTED";

  // Stage Config
  StageConfig _stageConfig = StageConfig(currentStage: PipelineStage.stage4);
  StageConfig get stageConfig => _stageConfig;

  // Detections
  List<DetectionResult> _detections = [];
  List<Map<String, dynamic>> _mediaPipeTestDetections = [];
  List<Map<String, dynamic>> get mediaPipeTestDetections =>
      _mediaPipeTestDetections;

  bool _isMediaPipeTesting = false;
  bool get isMediaPipeTesting => _isMediaPipeTesting;

  bool _liveMediaPipeRunning = false;
  bool get liveMediaPipeRunning => _liveMediaPipeRunning;

  double _mediaPipeLatencyMs = 0.0;
  double get mediaPipeLatencyMs => _mediaPipeLatencyMs;

  // E2E latency measurement for the live MediaPipe path.
  static const int _maxE2eLatencySamples = 10000;
  final List<double> _e2eLatencySamples = [];

  double _e2eP50Ms = 0.0;
  double _e2eP95Ms = 0.0;
  double _e2eP99Ms = 0.0;

  double get e2eP50Ms => _e2eP50Ms;
  double get e2eP95Ms => _e2eP95Ms;
  double get e2eP99Ms => _e2eP99Ms;
  int get e2eSampleCount => _e2eLatencySamples.length;

  // =========================================================================
  // SUSTAINED TEST / DIAGNOSTICS
  // =========================================================================

  Duration _sustainedTestDuration = const Duration(minutes: 30);

  static const Duration _sustainedSampleInterval = Duration(seconds: 5);

  Timer? _sustainedTestTimer;

  final List<Map<String, dynamic>> _sustainedSampleHistory = [];

  List<Map<String, dynamic>> get sustainedSampleHistory =>
      List.unmodifiable(_sustainedSampleHistory);

  Timer? _sustainedSampleTimer;
  DateTime? _sustainedTestStartedAt;
  double? _sustainedStartBattery;

  double _sustainedMinFps = double.infinity;
  double _sustainedFpsSum = 0.0;
  int _sustainedFpsSamples = 0;
  double _sustainedMaxTemperature = 0.0;
  int _sustainedSamples = 0;

  double? _cpuClockMhz;
  double? _gpuClockMhz;

  Map<String, double> _cpuThermalZones = {};

  File? _sustainedCsvFile;
  File? _sustainedJsonFile;

  bool _sustainedSaveInProgress = false;
  bool _sustainedSavePending = false;

  Map<String, double> get cpuThermalZones => Map.unmodifiable(_cpuThermalZones);

  String? get sustainedCsvPath => _sustainedCsvFile?.path;
  String? get sustainedJsonPath => _sustainedJsonFile?.path;

  bool get isSustainedTestRunning => _sustainedTestTimer != null;

  int get sustainedSamples => _sustainedSamples;

  Duration get sustainedElapsed {
    if (_sustainedTestStartedAt == null || !isSustainedTestRunning) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(_sustainedTestStartedAt!);

    return elapsed > _sustainedTestDuration ? _sustainedTestDuration : elapsed;
  }

  Duration get sustainedRemaining {
    final remaining = _sustainedTestDuration - sustainedElapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get sustainedProgress =>
      (sustainedElapsed.inMilliseconds / _sustainedTestDuration.inMilliseconds)
          .clamp(0.0, 1.0);

  int get sustainedFpsSamples => _sustainedFpsSamples;

  double get sustainedAverageFps =>
      _sustainedFpsSamples == 0 ? 0.0 : _sustainedFpsSum / _sustainedFpsSamples;

  double get sustainedMinFps =>
      _sustainedFpsSamples == 0 ? 0.0 : _sustainedMinFps;

  double get sustainedMaxTemperature => _sustainedMaxTemperature;

  double get sustainedCurrentFps =>
      isSustainedTestRunning ? telemetry.fps : 0.0;

  double get sustainedCurrentTemperature =>
      isSustainedTestRunning ? telemetry.thermalState : 0.0;

  double get sustainedBatteryStart =>
      _sustainedStartBattery ?? telemetry.batteryLevel;

  double get sustainedBatteryCurrent => telemetry.batteryLevel;

  double get sustainedBatteryDrain =>
      (sustainedBatteryStart - sustainedBatteryCurrent).clamp(0.0, 100.0);

  double? get cpuClockMhz => _cpuClockMhz;
  double? get gpuClockMhz => _gpuClockMhz;

  String get sustainedStatus => isSustainedTestRunning ? 'RUNNING' : 'READY';

  Future<void> startSustainedTest({
    Duration duration = const Duration(minutes: 30),
  }) async {
    if (isSustainedTestRunning) return;

    _sustainedTestDuration = duration;

    _sustainedTestStartedAt = DateTime.now();
    _sustainedStartBattery = telemetry.batteryLevel;

    _sustainedMinFps = double.infinity;
    _sustainedFpsSum = 0.0;
    _sustainedFpsSamples = 0;
    _sustainedMaxTemperature = telemetry.thermalState;
    _sustainedSamples = 0;

    // Start a completely new test dataset.
    _sustainedSampleHistory.clear();

    // Create the CSV and JSON files in Android external app storage.
    final directory = await getExternalStorageDirectory();

    if (directory == null) {
      debugPrint(
        'SUSTAINED TEST ERROR: external storage directory unavailable',
      );
      return;
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    _sustainedCsvFile = File(
      '${directory.path}/hsv2_sustained_test_$timestamp.csv',
    );

    _sustainedJsonFile = File(
      '${directory.path}/hsv2_sustained_test_$timestamp.json',
    );

    _sustainedTestTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (sustainedElapsed >= _sustainedTestDuration) {
          stopSustainedTest();
          return;
        }

        notifyListeners();
      },
    );

    // Record the first sample immediately.
    _recordSustainedSample();

    // Continue recording every 5 seconds.
    _sustainedSampleTimer = Timer.periodic(
      _sustainedSampleInterval,
      (_) => _recordSustainedSample(),
    );

    notifyListeners();

    debugPrint(
      'SUSTAINED TEST STARTED: '
      'duration=${duration.inSeconds}s '
      'CSV=${_sustainedCsvFile!.path} '
      'JSON=${_sustainedJsonFile!.path}',
    );
  }

  void _recordSustainedSample() {
    if (!isSustainedTestRunning) return;

    final fps = telemetry.fps;
    final temperature = telemetry.thermalState;

    if (fps > 0) {
      _sustainedFpsSum += fps;
      _sustainedFpsSamples++;

      if (fps < _sustainedMinFps) {
        _sustainedMinFps = fps;
      }
    }

    if (temperature > _sustainedMaxTemperature) {
      _sustainedMaxTemperature = temperature;
    }

    _sustainedSamples++;

    _sustainedSampleHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'elapsedSeconds': sustainedElapsed.inSeconds,
      'fps': fps,
      'mediapipeCpuLatencyMs': mediaPipeLatencyMs,
      'e2eP50Ms': e2eP50Ms,
      'e2eP95Ms': e2eP95Ms,
      'e2eP99Ms': e2eP99Ms,
      'battery': telemetry.batteryLevel,
      'batteryTemperature': telemetry.batteryTemperature,
      'temperature': temperature,
      'maxTemperature': _sustainedMaxTemperature,
      'cpuClockMhz': _cpuClockMhz,
      'cpuThermalZones': Map<String, double>.from(
        _cpuThermalZones,
      ),
      'droppedFrames': telemetry.droppedFrames,
    });

    debugPrint(
      'SUSTAINED SAMPLE: '
      'elapsed=${sustainedElapsed.inSeconds}s '
      'fps=${fps.toStringAsFixed(1)} '
      'MediaPipeCPU='
      '${mediaPipeLatencyMs.toStringAsFixed(1)} '
      'p50=${e2eP50Ms.toStringAsFixed(1)} '
      'p95=${e2eP95Ms.toStringAsFixed(1)} '
      'p99=${e2eP99Ms.toStringAsFixed(1)} '
      'thermal=${temperature.toStringAsFixed(1)} '
      'battery='
      '${telemetry.batteryLevel.toStringAsFixed(1)}',
    );

    // Automatically persist the live sample.
    _saveSustainedTestData();

    notifyListeners();
  }

  Future<void> _saveSustainedTestData() async {
    if (_sustainedCsvFile == null || _sustainedJsonFile == null) {
      return;
    }

    if (_sustainedSaveInProgress) {
      _sustainedSavePending = true;
      return;
    }

    _sustainedSaveInProgress = true;

    try {
      await _writeSustainedCsv();
      await _writeSustainedJson();

      debugPrint(
        'SUSTAINED DATA AUTO-SAVED: '
        'samples=${_sustainedSampleHistory.length}',
      );
    } catch (e) {
      debugPrint(
        'SUSTAINED DATA SAVE ERROR: $e',
      );
    } finally {
      _sustainedSaveInProgress = false;

      if (_sustainedSavePending) {
        _sustainedSavePending = false;
        await _saveSustainedTestData();
      }
    }
  }

  Future<void> _writeSustainedCsv() async {
    final file = _sustainedCsvFile;
    if (file == null) return;

    final buffer = StringBuffer();

    final thermalZoneNames = <String>{};

    for (final sample in _sustainedSampleHistory) {
      final zones = sample['cpuThermalZones'];

      if (zones is Map) {
        thermalZoneNames.addAll(
          zones.keys.map(
            (key) => key.toString(),
          ),
        );
      }
    }

    final sortedThermalZoneNames = thermalZoneNames.toList()..sort();

    buffer.writeln([
      'timestamp',
      'elapsedSeconds',
      'fps',
      'mediapipe_cpu_latency_ms',
      'e2e_p50_ms',
      'e2e_p95_ms',
      'e2e_p99_ms',
      'battery_percent',
      'battery_temperature_c',
      'cpu_temperature_max_c',
      'cpu_clock_mhz',
      ...sortedThermalZoneNames,
      'droppedFrames',
    ].join(','));

    for (final sample in _sustainedSampleHistory) {
      final zones = sample['cpuThermalZones'] is Map
          ? Map<String, dynamic>.from(
              sample['cpuThermalZones'] as Map,
            )
          : <String, dynamic>{};

      buffer.writeln([
        sample['timestamp'] ?? '',
        sample['elapsedSeconds'] ?? '',
        sample['fps'] ?? '',
        sample['mediapipeCpuLatencyMs'] ?? '',
        sample['e2eP50Ms'] ?? '',
        sample['e2eP95Ms'] ?? '',
        sample['e2eP99Ms'] ?? '',
        sample['battery'] ?? '',
        sample['batteryTemperature'] ?? '',
        sample['temperature'] ?? '',
        sample['cpuClockMhz'] ?? '',
        ...sortedThermalZoneNames.map(
          (zone) => zones[zone] ?? '',
        ),
        sample['droppedFrames'] ?? '',
      ].join(','));
    }

    await file.writeAsString(
      buffer.toString(),
    );
  }

  Future<void> _writeSustainedJson() async {
    final file = _sustainedJsonFile;
    if (file == null) return;

    final output = {
      'test': {
        'name': 'HSV2 Lite Sustained Test',
        'camera': 'Intel RealSense D455',
        'durationSeconds': _sustainedTestDuration.inSeconds,
        'sampleIntervalSeconds': _sustainedSampleInterval.inSeconds,
        'sampleCount': _sustainedSampleHistory.length,
        'startTime': _sustainedTestStartedAt?.toIso8601String(),
        'status': isSustainedTestRunning ? 'RUNNING' : 'STOPPED',
      },
      'summary': {
        'averageFps': sustainedAverageFps,
        'minimumFps': sustainedMinFps,
        'maximumCpuTemperature': sustainedMaxTemperature,
        'batteryStart': _sustainedStartBattery,
        'batteryCurrent': telemetry.batteryLevel,
        'batteryDrain': sustainedBatteryDrain,
        'sampleCount': _sustainedSampleHistory.length,
      },
      'samples': _sustainedSampleHistory,
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(output),
    );
  }

  // Kept for compatibility with any existing UI code.
  // The test data is already automatically saved.
  Future<String?> exportSustainedTestCsv() async {
    if (_sustainedSampleHistory.isEmpty) {
      debugPrint(
        'SUSTAINED CSV: no samples available',
      );
      return null;
    }

    await _saveSustainedTestData();

    return _sustainedCsvFile?.path;
  }

  Future<void> stopSustainedTest() async {
    final completedSamples = _sustainedSamples;

    final completedAvgFps = sustainedAverageFps;

    final completedMinFps = sustainedMinFps;

    final completedMaxThermal = sustainedMaxTemperature;

    final completedBatteryDrain = sustainedBatteryDrain;

    // Final save BEFORE clearing the running-test state.
    await _saveSustainedTestData();

    _sustainedTestTimer?.cancel();
    _sustainedSampleTimer?.cancel();

    _sustainedTestTimer = null;
    _sustainedSampleTimer = null;
    _sustainedTestStartedAt = null;
    _sustainedStartBattery = null;

    // Reset live UI summary.
    // Keep history and files for the completed run.
    _sustainedMinFps = double.infinity;

    _sustainedFpsSum = 0.0;
    _sustainedFpsSamples = 0;
    _sustainedMaxTemperature = 0.0;
    _sustainedSamples = 0;

    notifyListeners();

    debugPrint(
      'SUSTAINED TEST STOPPED: '
      'completedSamples=$completedSamples '
      'avgFps='
      '${completedAvgFps.toStringAsFixed(2)} '
      'minFps='
      '${completedMinFps.toStringAsFixed(2)} '
      'maxThermal='
      '${completedMaxThermal.toStringAsFixed(1)} '
      'batteryDrain='
      '${completedBatteryDrain.toStringAsFixed(1)}% '
      'history='
      '${_sustainedSampleHistory.length} '
      'CSV=${_sustainedCsvFile?.path} '
      'JSON=${_sustainedJsonFile?.path}',
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get sustainedElapsedText => _formatDuration(sustainedElapsed);
  String get sustainedRemainingText => _formatDuration(sustainedRemaining);

  double _calculateE2ePercentile(
    List<double> values,
    double percentile,
  ) {
    if (values.isEmpty) {
      return 0.0;
    }

    final sorted = List<double>.from(values)..sort();

    final index =
        (sorted.length * percentile).floor().clamp(0, sorted.length - 1);

    return sorted[index];
  }

  void _recordE2eLatency(double latencyMs) {
    _e2eLatencySamples.add(latencyMs);

    if (_e2eLatencySamples.length > _maxE2eLatencySamples) {
      _e2eLatencySamples.removeAt(0);
    }

    _e2eP50Ms = _calculateE2ePercentile(
      _e2eLatencySamples,
      0.50,
    );

    _e2eP95Ms = _calculateE2ePercentile(
      _e2eLatencySamples,
      0.95,
    );

    _e2eP99Ms = _calculateE2ePercentile(
      _e2eLatencySamples,
      0.99,
    );
  }

  List<DetectionResult> get detections => _detections;

  // Mock Timer for Web
  Timer? _mockWebTimer;

  AppState() {
    if (!kIsWeb) {
      _startListeningToUsbStatus();

      Future.microtask(() {
        setStageConfig(
          StageConfig(currentStage: PipelineStage.stage4),
        );
      });
    }
  }

  Future<void> initNativeTexture() async {
    if (_textureId != null) return;
    try {
      final int id = await _commandChannel.invokeMethod('createTexture');
      _textureId = id;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to create native texture: $e');
    }
  }

  Future<void> initDepthTexture() async {
    if (_depthTextureId != null) return;
    try {
      final int id = await _commandChannel.invokeMethod('createDepthTexture');
      _depthTextureId = id;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to create native depth texture: $e');
    }
  }

  void _startListeningToUsbStatus() {
    _usbStatusChannel.receiveBroadcastStream().listen((dynamic event) {
      _usbStatus = event.toString();
      notifyListeners();
    }, onError: (dynamic error) {
      debugPrint("USB Status error: $error");
    });
  }

  void setStageConfig(StageConfig config) async {
    _stageConfig = config;
    if (kIsWeb) {
      notifyListeners();
      return;
    }

    try {
      await _commandChannel
          .invokeMethod('setStage', {'stage': config.currentStage.index + 1});
    } on PlatformException catch (e) {
      debugPrint("Failed to set stage: '${e.message}'.");
    }
    notifyListeners();
  }

  // =========================================================================
  // FIXED TEST SEQUENCE RECORDING
  // =========================================================================

  bool _isFixedRecording = false;

  bool get isFixedRecording => _isFixedRecording;

  Future<void> startFixedRecording() async {
    if (kIsWeb) {
      debugPrint("Fixed recording is not available on web.");
      return;
    }

    if (_isFixedRecording) {
      debugPrint("Fixed test sequence recording is already active.");
      return;
    }

    try {
      await _commandChannel.invokeMethod('startFixedRecording');

      _isFixedRecording = true;
      notifyListeners();

      debugPrint("Fixed test sequence recording started.");

      // Native recorder runs for 60 seconds automatically.
      await Future.delayed(const Duration(seconds: 62));

      _isFixedRecording = false;
      notifyListeners();

      debugPrint("Fixed recording duration completed. Starting auto-export.");

      final success = await _commandChannel.invokeMethod<bool>(
        'exportFixedRecording',
      );

      if (success == true) {
        debugPrint("AUTO RECORD + SAVE + EXPORT completed successfully.");
      } else {
        debugPrint("AUTO EXPORT failed.");
      }
    } on PlatformException catch (e) {
      _isFixedRecording = false;
      notifyListeners();

      debugPrint(
        "Fixed recording failed: '${e.message}'.",
      );
    } catch (e) {
      _isFixedRecording = false;
      notifyListeners();

      debugPrint(
        "Fixed recording/export error: $e",
      );
    }
  }

  Future<void> exportFixedRecording() async {
    try {
      final success = await _commandChannel.invokeMethod<bool>(
        'exportFixedRecording',
      );

      if (success == true) {
        debugPrint('Fixed recording exported successfully');
      } else {
        debugPrint('Fixed recording export failed');
      }
    } catch (e) {
      debugPrint('Fixed recording export error: $e');
    }
  }

  Future<void> runReplayBenchmark() async {
    try {
      final result = await _commandChannel.invokeMethod(
        'runReplayBenchmark',
      );

      debugPrint('Replay benchmark result: $result');
    } catch (e) {
      debugPrint('Replay benchmark error: $e');
    }
  }

  Future<void> stopFixedRecording() async {
    if (kIsWeb) {
      debugPrint("Fixed recording is not available on web.");
      return;
    }

    try {
      await _commandChannel.invokeMethod('stopFixedRecording');

      _isFixedRecording = false;
      notifyListeners();

      debugPrint(
        "Fixed test sequence recording stopped.",
      );
    } on PlatformException catch (e) {
      debugPrint(
        "Failed to stop fixed recording: '${e.message}'.",
      );
    }
  }

  Future<void> togglePipeline() async {
    if (_isPipelineRunning) {
      // Stop MediaPipe first.
      _liveMediaPipeRunning = false;

      if (kIsWeb) {
        _stopWebMock();
      } else {
        try {
          await _commandChannel.invokeMethod('stopPipeline');
        } on PlatformException catch (e) {
          debugPrint("Failed to stop pipeline: '${e.message}'.");
        }
      }

      _isPipelineRunning = false;
    } else {
      if (kIsWeb) {
        _isPipelineRunning = true;
        _startWebMock();
      } else {
        try {
          await _commandChannel.invokeMethod('startPipeline');

          _isPipelineRunning = true;
          _startListeningToTelemetry();

          // Start live MediaPipe automatically with START.
          _startLiveMediaPipeLoop();
        } on PlatformException catch (e) {
          debugPrint("Failed to start pipeline: '${e.message}'.");
          _isPipelineRunning = false;
          _liveMediaPipeRunning = false;
        }
      }
    }

    notifyListeners();
  }

  Future<void> _startLiveMediaPipeLoop() async {
    if (_liveMediaPipeRunning) return;

    _liveMediaPipeRunning = true;
    _isMediaPipeTesting = false;
    _mediaPipeTestDetections = [];

    // Start a fresh E2E measurement window for each live run.
    _e2eLatencySamples.clear();
    _e2eP50Ms = 0.0;
    _e2eP95Ms = 0.0;
    _e2eP99Ms = 0.0;

    notifyListeners();

    debugPrint('Live MediaPipe loop STARTED');

    while (_liveMediaPipeRunning && _isPipelineRunning) {
      final stopwatch = Stopwatch()..start();

      try {
        final dynamic raw =
            await _commandChannel.invokeMethod('testLiveMediaPipe');

        if (!_liveMediaPipeRunning || !_isPipelineRunning) {
          break;
        }

        _mediaPipeLatencyMs = 0.0;

        if (raw is Map) {
          final dynamic rawDetections = raw['detections'];
          final dynamic rawLatency = raw['latencyMs'];

          if (rawDetections is List) {
            _mediaPipeTestDetections = rawDetections
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }

          if (rawLatency is num) {
            _mediaPipeLatencyMs = rawLatency.toDouble();
          }
        }

        final elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;

        // Record the complete Flutter -> Android -> MediaPipe -> Flutter
        // round-trip latency for percentile measurement.
        _recordE2eLatency(elapsedMs);

        debugPrint(
          'Live MediaPipe: '
          'detections=${_mediaPipeTestDetections.length}, '
          'MediaPipe CPU latency='
          '${_mediaPipeLatencyMs.toStringAsFixed(1)} ms, '
          'E2E=${elapsedMs.toStringAsFixed(1)} ms, '
          'E2E p50=${_e2eP50Ms.toStringAsFixed(1)} ms, '
          'p95=${_e2eP95Ms.toStringAsFixed(1)} ms, '
          'p99=${_e2eP99Ms.toStringAsFixed(1)} ms, '
          'samples=${_e2eLatencySamples.length}',
        );

        for (final detection in _mediaPipeTestDetections) {
          debugPrint('Live detection: $detection');
        }

        notifyListeners();
      } on PlatformException catch (e) {
        debugPrint(
          'Live MediaPipe failed: ${e.code}: ${e.message}',
        );
      } catch (e) {
        debugPrint('Live MediaPipe failed: $e');
      }

      // Small gap so the detector does not hammer the MethodChannel.
      if (_liveMediaPipeRunning && _isPipelineRunning) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    _liveMediaPipeRunning = false;
    _isMediaPipeTesting = false;

    debugPrint('Live MediaPipe loop STOPPED');

    notifyListeners();
  }

  Future<void> runLiveMediaPipe() async {
    _isMediaPipeTesting = true;
    _mediaPipeTestDetections = [];
    notifyListeners();

    try {
      final dynamic raw =
          await _commandChannel.invokeMethod('testLiveMediaPipe');

      if (raw is List) {
        _mediaPipeTestDetections = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      debugPrint(
        'Live MediaPipe detections: '
        '${_mediaPipeTestDetections.length}',
      );

      for (final detection in _mediaPipeTestDetections) {
        debugPrint('Live detection: $detection');
      }
    } on PlatformException catch (e) {
      debugPrint(
        'Live MediaPipe test failed: ${e.code}: ${e.message}',
      );
    } catch (e) {
      debugPrint('Live MediaPipe test failed: $e');
    } finally {
      _isMediaPipeTesting = false;
      notifyListeners();
    }
  }

  Future<void> runMediaPipeTest() async {
    _isMediaPipeTesting = true;
    _mediaPipeTestDetections = [];
    notifyListeners();

    try {
      final dynamic raw =
          await _commandChannel.invokeMethod('testMediaPipeDetector');

      if (raw is List) {
        _mediaPipeTestDetections = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      debugPrint(
        'MediaPipe test detections: '
        '${_mediaPipeTestDetections.length}',
      );
    } on PlatformException catch (e) {
      debugPrint(
        'MediaPipe test failed: ${e.code}: ${e.message}',
      );
    } catch (e) {
      debugPrint('MediaPipe test failed: $e');
    } finally {
      _isMediaPipeTesting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sustainedTestTimer?.cancel();
    _sustainedSampleTimer?.cancel();
    _mockWebTimer?.cancel();
    super.dispose();
  }

  void _startWebMock() {
    _mockWebTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isPipelineRunning) return;
      _telemetry = TelemetryData(
        fps: 15.0 + (DateTime.now().millisecondsSinceEpoch % 5) / 10,
        p50LatencyMs: 30.0,
        p95LatencyMs: 45.0,
        p99LatencyMs: 60.0,
        cpuUsage: 25.0,
        thermalState: 35.0,
        batteryLevel: 98.0,
        droppedFrames: 0,
        usbTransportLatencyMs: 2.0,
        centerDistanceMeters: 1.25,
      );

      // Removed static mock detection per user request
      _detections = [];
      notifyListeners();
    });
  }

  void _stopWebMock() {
    _mockWebTimer?.cancel();
    _mockWebTimer = null;
    _detections = [];
  }

  void _startListeningToTelemetry() {
    _telemetryChannel.receiveBroadcastStream().listen((dynamic event) {
      if (!_isPipelineRunning) return;
      try {
        final Map<String, dynamic> data = jsonDecode(event as String);
        _telemetry = TelemetryData(
          fps: (data['fps'] as num?)?.toDouble() ?? 0.0,
          p50LatencyMs: (data['p50'] as num?)?.toDouble() ?? 0.0,
          p95LatencyMs: (data['p95'] as num?)?.toDouble() ?? 0.0,
          p99LatencyMs: (data['p99'] as num?)?.toDouble() ?? 0.0,
          cpuUsage: (data['cpu'] as num?)?.toDouble() ?? 0.0,
          thermalState: (data['thermal'] as num?)?.toDouble() ?? 0.0,
          batteryLevel: (data['battery'] as num?)?.toDouble() ?? 100.0,
          batteryTemperature:
              (data['batteryTemperature'] as num?)?.toDouble() ?? 0.0,
          centerDistanceMeters:
              (data['centerDistance'] as num?)?.toDouble() ?? 0.0,
          droppedFrames: (data['droppedFrames'] as num?)?.toInt() ?? 0,

          // Live D455 IMU telemetry
          gyroX: ((data['imu'] as Map?)?['gyro'] as List?)?.isNotEmpty == true
              ? (((data['imu'] as Map)['gyro'] as List)[0] as num).toDouble()
              : 0.0,
          gyroY: (((data['imu'] as Map?)?['gyro'] as List?)?.length ?? 0) >= 2
              ? (((data['imu'] as Map)['gyro'] as List)[1] as num).toDouble()
              : 0.0,
          gyroZ: (((data['imu'] as Map?)?['gyro'] as List?)?.length ?? 0) >= 3
              ? (((data['imu'] as Map)['gyro'] as List)[2] as num).toDouble()
              : 0.0,

          accelX: ((data['imu'] as Map?)?['accel'] as List?)?.isNotEmpty == true
              ? (((data['imu'] as Map)['accel'] as List)[0] as num).toDouble()
              : 0.0,
          accelY: (((data['imu'] as Map?)?['accel'] as List?)?.length ?? 0) >= 2
              ? (((data['imu'] as Map)['accel'] as List)[1] as num).toDouble()
              : 0.0,
          accelZ: (((data['imu'] as Map?)?['accel'] as List?)?.length ?? 0) >= 3
              ? (((data['imu'] as Map)['accel'] as List)[2] as num).toDouble()
              : 0.0,

          gyroTimestampMs:
              ((data['imu'] as Map?)?['gyroTimestampMs'] as num?)?.toDouble() ??
                  0.0,
          accelTimestampMs: ((data['imu'] as Map?)?['accelTimestampMs'] as num?)
                  ?.toDouble() ??
              0.0,

          gyroCount:
              ((data['imu'] as Map?)?['gyroCount'] as num?)?.toInt() ?? 0,
          accelCount:
              ((data['imu'] as Map?)?['accelCount'] as num?)?.toInt() ?? 0,
        );

        // CPU thermal zones from the Android/Linux thermal framework.
        final rawThermalZones = data['cpuThermalZones'];
        if (rawThermalZones is Map) {
          _cpuThermalZones = rawThermalZones.map(
            (key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            ),
          );
        }

        // Optional device clock telemetry. Native telemetry can populate these
        // keys when available; otherwise the Diagnostics UI shows "--".
        _cpuClockMhz = (data['cpuClockMhz'] as num?)?.toDouble() ??
            (data['cpuClock'] as num?)?.toDouble();
        _gpuClockMhz = (data['gpuClockMhz'] as num?)?.toDouble() ??
            (data['gpuClock'] as num?)?.toDouble();

        if (data.containsKey('detections')) {
          final List<dynamic> detList = data['detections'];
          _detections = detList.map((d) {
            final bboxList = (d['bbox'] as List<dynamic>?)
                    ?.map((e) => (e as num).toDouble())
                    .toList() ??
                [0.0, 0.0, 0.0, 0.0];
            final int classId = d['class'] as int? ?? -1;
            final String className =
                (classId >= 0 && classId < cocoClasses.length)
                    ? cocoClasses[classId]
                    : 'Object $classId';

            return DetectionResult(
              objectName: className,
              confidence: (d['confidence'] as num?)?.toDouble() ?? 0.0,
              distanceMeters: (d['distanceMeters'] as num?)?.toDouble() ?? 0.0,
              directionClock: '',
              boundingBox: bboxList,
            );
          }).toList();
        } else {
          _detections = [];
        }
        notifyListeners();
      } catch (e) {
        debugPrint("Error parsing telemetry: $e");
      }
    }, onError: (dynamic error) {
      debugPrint("Telemetry error: $error");
    });
  }
}
