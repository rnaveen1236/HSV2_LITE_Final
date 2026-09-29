import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/app_state.dart';
import 'stage2_visualization_screen.dart';
import 'stage4_visualization_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String _cameraError = "";

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initMockWebCamera();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<AppState>(context, listen: false).initNativeTexture();
        Provider.of<AppState>(context, listen: false).initDepthTexture();
      });
    }
  }

  Future<void> _initMockWebCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cameraError = "No cameras found by the browser.";
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing web camera: $e");
      if (mounted) {
        setState(() {
          _cameraError = "Camera Error: $e\nCheck browser permissions.";
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Feeds (RGB and Depth Side-by-Side)
          Positioned.fill(
            child: kIsWeb && _isCameraInitialized && _cameraController != null
                ? SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width:
                            _cameraController!.value.previewSize?.height ?? 1,
                        height:
                            _cameraController!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                : (!kIsWeb &&
                        state.textureId != null &&
                        state.isCameraConnected)
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Column(
                            children: [
                              // Top Half: RGB Feed
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: 640,
                                        height: 480,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            if (state.textureId != null)
                                              Texture(
                                                textureId: state.textureId!,
                                              ),

                                            // Live MediaPipe bounding boxes.
                                            if (state.liveMediaPipeRunning &&
                                                state.mediaPipeTestDetections
                                                    .isNotEmpty)
                                              CustomPaint(
                                                painter:
                                                    _LiveDetectionBoxPainter(
                                                  state.mediaPipeTestDetections,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Center Crosshair and HUD aligned to RGB Feed
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add,
                                              color: Colors.greenAccent,
                                              size: 48),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Bottom Half: Depth Feed
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: 640,
                                    height: 480,
                                    child: state.depthTextureId != null
                                        ? Texture(
                                            textureId: state.depthTextureId!)
                                        : const SizedBox(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Text(
                            "WAITING FOR NATIVE REALSENSE FEED",
                            style: TextStyle(
                                color: Colors.white54, letterSpacing: 2),
                          ),
                        ),
                      ),
          ),

          // 2. Removed static detections mapped in position (replaced by overlay in CustomPaint)

          // 3. Live D455 IMU Panel
          // 4. Live MediaPipe Output Panel
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 130,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        color: Colors.greenAccent,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE MEDIAPIPE OUTPUT',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (state.liveMediaPipeRunning)
                        const Text(
                          'RUNNING',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (state.mediaPipeTestDetections.isEmpty)
                    const Text(
                      'Waiting for detections...',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: state.mediaPipeTestDetections.length,
                        itemBuilder: (context, index) {
                          final d = state.mediaPipeTestDetections[index];

                          final name = d['class']?.toString() ?? 'unknown';

                          final score =
                              ((d['score'] as num?)?.toDouble() ?? 0.0) * 100.0;

                          final distance =
                              (d['distanceMeters'] as num?)?.toDouble();

                          final direction = d['direction']?.toString();

                          final distanceText = distance != null
                              ? '${distance.toStringAsFixed(2)}m'
                              : '--';

                          final directionText = direction != null &&
                                  direction.isNotEmpty &&
                                  direction != 'null'
                              ? direction
                              : '--';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${score.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  distanceText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  directionText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    'Camera FPS: '
                    '${state.telemetry.fps.toStringAsFixed(1)}'
                    '  |  '
                    'MediaPipe CPU latency: '
                    '${state.mediaPipeLatencyMs.toStringAsFixed(1)} ms',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'MediaPipe CPU E2E  |  '
                    'p50: ${state.e2eP50Ms.toStringAsFixed(1)} ms  |  '
                    'p95: ${state.e2eP95Ms.toStringAsFixed(1)} ms  |  '
                    'p99: ${state.e2eP99Ms.toStringAsFixed(1)} ms',
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Floating Control Panel
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // USB Status
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.usb,
                              color: _getStatusColor(state.usbStatus),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                state.usbStatus,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _getStatusColor(
                                    state.usbStatus,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FPS: ${state.telemetry.fps.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // START / STOP
                  ElevatedButton.icon(
                    onPressed: state.isCameraConnected
                        ? () => context.read<AppState>().togglePipeline()
                        : null,
                    icon: Icon(
                      state.isPipelineRunning ? Icons.stop : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(
                      state.isPipelineRunning ? 'STOP' : 'START',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          state.isPipelineRunning ? Colors.red : Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // FIXED TEST SEQUENCE
                  OutlinedButton.icon(
                    onPressed: state.isCameraConnected &&
                            !state.isFixedRecording
                        ? () => context.read<AppState>().startFixedRecording()
                        : state.isFixedRecording
                            ? () =>
                                context.read<AppState>().stopFixedRecording()
                            : null,
                    icon: Icon(
                      state.isFixedRecording
                          ? Icons.stop_circle_outlined
                          : Icons.fiber_manual_record,
                      size: 18,
                    ),
                    label: Text(
                      state.isFixedRecording ? 'RECORDING...' : 'FIXED TEST',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: state.isFixedRecording
                          ? Colors.redAccent
                          : Colors.orangeAccent,
                      side: BorderSide(
                        color: state.isFixedRecording
                            ? Colors.redAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  OutlinedButton.icon(
                    onPressed: () => _showDiagnostics(context),
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('DIAGNOSTICS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.lightBlueAccent,
                      side: const BorderSide(color: Colors.lightBlueAccent),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // STAGE 2
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Stage2VisualizationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.view_in_ar, size: 18),
                    label: const Text('STAGE 2'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // STAGE 4
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Stage4VisualizationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.track_changes, size: 18),
                    label: const Text('STAGE 4'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      side: const BorderSide(color: Colors.purpleAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDiagnostics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SustainedDiagnosticsSheet(),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'CONNECTED') return Colors.greenAccent;
    if (status == 'REQUESTING PERMISSION') return Colors.orangeAccent;
    if (status == 'DISCONNECTED' || status == 'PERMISSION DENIED')
      return Colors.redAccent;
    return Colors.grey;
  }
}

class _SustainedDiagnosticsSheet extends StatelessWidget {
  const _SustainedDiagnosticsSheet();

  String _fmt(double value) => value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF101820),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.white24),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined,
                      color: Colors.lightBlueAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Diagnostics / Sustained Test',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: state.isSustainedTestRunning
                          ? Colors.green.withOpacity(0.18)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state.sustainedStatus,
                      style: TextStyle(
                        color: state.isSustainedTestRunning
                            ? Colors.greenAccent
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '30-minute continuous performance, thermal and battery test',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _metricCard(
                title: 'Sustained Test',
                icon: Icons.timer_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.sustainedElapsedText} / 30:00',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: state.sustainedProgress,
                      minHeight: 7,
                      backgroundColor: Colors.white12,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(state.sustainedProgress * 100).toStringAsFixed(0)}%  •  '
                      'Remaining ${state.sustainedRemainingText}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: state.isSustainedTestRunning
                                ? null
                                : () => context
                                    .read<AppState>()
                                    .startSustainedTest(),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('START 30-MIN TEST'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: state.isSustainedTestRunning
                                ? () =>
                                    context.read<AppState>().stopSustainedTest()
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('STOP TEST'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      title: 'FPS',
                      icon: Icons.bar_chart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _valueRow('Current', _fmt(state.telemetry.fps)),
                          _valueRow(
                              'Average',
                              state.sustainedFpsSamples == 0
                                  ? '--'
                                  : _fmt(state.sustainedAverageFps)),
                          _valueRow(
                              'Minimum',
                              state.sustainedFpsSamples == 0
                                  ? '--'
                                  : _fmt(state.sustainedMinFps)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricCard(
                      title: 'Latency (ms)',
                      icon: Icons.speed,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _valueRow(
                            'MediaPipe CPU',
                            state.mediaPipeLatencyMs > 0
                                ? '${_fmt(state.mediaPipeLatencyMs)} ms'
                                : '--',
                          ),
                          _valueRow(
                            'E2E p50',
                            state.e2eSampleCount > 0
                                ? '${_fmt(state.e2eP50Ms)} ms'
                                : '--',
                          ),
                          _valueRow(
                            'E2E p95',
                            state.e2eSampleCount > 0
                                ? '${_fmt(state.e2eP95Ms)} ms'
                                : '--',
                          ),
                          _valueRow(
                            'E2E p99',
                            state.e2eSampleCount > 0
                                ? '${_fmt(state.e2eP99Ms)} ms'
                                : '--',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      title: 'Device',
                      icon: Icons.thermostat,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _valueRow('Battery',
                              '${_fmt(state.sustainedBatteryCurrent)}%'),
                          _valueRow(
                              'Drain', '${_fmt(state.sustainedBatteryDrain)}%'),
                          _valueRow(
                              'Temperature',
                              state.isSustainedTestRunning
                                  ? '${_fmt(state.sustainedCurrentTemperature)} °C'
                                  : '--'),
                          _valueRow(
                              'Battery temp',
                              state.telemetry.batteryTemperature > 0
                                  ? '${_fmt(state.telemetry.batteryTemperature)} °C'
                                  : '--'),
                          _valueRow('Max temp',
                              '${_fmt(state.sustainedMaxTemperature)} °C'),
                          _valueRow(
                              'CPU clock',
                              state.cpuClockMhz == null
                                  ? '--'
                                  : '${_fmt(state.cpuClockMhz!)} MHz'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricCard(
                      title: 'Test Status',
                      icon: Icons.fact_check_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _valueRow('Status', state.sustainedStatus),
                          _valueRow('Elapsed', state.sustainedElapsedText),
                          _valueRow('Remaining', state.sustainedRemainingText),
                          _valueRow(
                              'Samples', state.sustainedSamples.toString()),
                          _valueRow(
                              'E2E samples', state.e2eSampleCount.toString()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.lightBlue.withOpacity(0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.lightBlueAccent, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Test condition: keep the phone in a pocket or bag at '
                        'normal ambient conditions. Do not place it flat on a desk. '
                        'Samples are recorded every 5 seconds.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF172330),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: Colors.lightBlueAccent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _valueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDetectionBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;

  _LiveDetectionBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    const sourceWidth = 640.0;
    const sourceHeight = 480.0;

    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (final detection in detections) {
      final left = (detection['left'] as num?)?.toDouble();
      final top = (detection['top'] as num?)?.toDouble();
      final right = (detection['right'] as num?)?.toDouble();
      final bottom = (detection['bottom'] as num?)?.toDouble();

      if (left == null || top == null || right == null || bottom == null) {
        continue;
      }

      final rect = Rect.fromLTRB(
        left * scaleX,
        top * scaleY,
        right * scaleX,
        bottom * scaleY,
      );

      canvas.drawRect(rect, boxPaint);

      final className = detection['class']?.toString() ?? 'object';

      final score = ((detection['score'] as num?)?.toDouble() ?? 0.0) * 100.0;

      final label = '$className ${score.toStringAsFixed(1)}%';

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelTop = rect.top > 26 ? rect.top - 26 : rect.top;

      final backgroundRect = Rect.fromLTWH(
        rect.left,
        labelTop,
        textPainter.width + 10,
        24,
      );

      final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.75);

      canvas.drawRect(
        backgroundRect,
        backgroundPaint,
      );

      textPainter.paint(
        canvas,
        Offset(
          rect.left + 5,
          labelTop + 3,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _LiveDetectionBoxPainter oldDelegate,
  ) {
    return oldDelegate.detections != detections;
  }
}
