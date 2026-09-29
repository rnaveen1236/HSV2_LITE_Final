import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Stage4VisualizationScreen extends StatefulWidget {
  const Stage4VisualizationScreen({super.key});

  @override
  State<Stage4VisualizationScreen> createState() =>
      _Stage4VisualizationScreenState();
}

class _Stage4VisualizationScreenState extends State<Stage4VisualizationScreen> {
  static const MethodChannel _commandChannel =
      MethodChannel('com.hsv2/command');

  Timer? _timer;
  Timer? _rgbTimer;
  Timer? _roiTimer;

  ui.Image? _rgbImage;
  int _rgbWidth = 0;
  int _rgbHeight = 0;

  Map<String, dynamic> _data = <String, dynamic>{
    'valid': false,
    'processingMs': 0.0,
    'features': 0,
    'tracked': 0,
    'inliers': 0,
    'localPoints': 0,
    'poseValid': false,
    'poseMode': 0,
    'tx': 0.0,
    'ty': 0.0,
    'tz': 0.0,
    'rgbWidth': 0,
    'rgbHeight': 0,
    'features2d': <dynamic>[],
    'local3d': <dynamic>[],
  };

  @override
  void initState() {
    super.initState();

    _setStage4();

    _timer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _pollVisualization(),
    );

    // RGB preview is intentionally lower-rate so it does not disturb
    // the Stage 4 FAST/LK processing path.
    _rgbTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _pollRgbFrame(),
    );

    // Keep MediaPipe object ROIs refreshed while Stage 4 is running.
    _roiTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _pollObjectRoi(),
    );
  }

  Future<void> _setStage4() async {
    try {
      await _commandChannel.invokeMethod(
        'setStage',
        <String, dynamic>{
          'stage': 4,
        },
      );
    } catch (e) {
      debugPrint('Stage 4 setStage error: $e');
    }
  }

  Future<void> _pollObjectRoi() async {
    try {
      await _commandChannel.invokeMethod(
        'testLiveMediaPipe',
      );
    } catch (e) {
      debugPrint('Stage 4 MediaPipe ROI error: $e');
    }
  }

  Future<void> _pollVisualization() async {
    try {
      final dynamic raw = await _commandChannel.invokeMethod(
        'getStage4Visualization',
      );

      if (raw == null) {
        return;
      }

      final Map<String, dynamic> decoded =
          jsonDecode(raw.toString()) as Map<String, dynamic>;

      if (!mounted) {
        return;
      }

      setState(() {
        _data = decoded;
      });
    } catch (e) {
      debugPrint('Stage 4 visualization error: $e');
    }
  }

  Future<void> _pollRgbFrame() async {
    try {
      final dynamic raw = await _commandChannel.invokeMethod(
        'getStage4RgbFrame',
      );

      if (raw == null || !mounted) {
        return;
      }

      final Uint8List bytes = Uint8List.fromList(
        List<int>.from(raw as List),
      );

      const int width = 640;
      const int height = 480;

      if (bytes.length != width * height * 4) {
        return;
      }

      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(bytes);

      final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
        rowBytes: width * 4,
      );

      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      buffer.dispose();
      descriptor.dispose();
      codec.dispose();

      if (!mounted) {
        image.dispose();
        return;
      }

      final ui.Image? oldImage = _rgbImage;

      setState(() {
        _rgbImage = image;
        _rgbWidth = width;
        _rgbHeight = height;
      });

      oldImage?.dispose();
    } catch (e) {
      debugPrint('Stage 4 RGB preview error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rgbTimer?.cancel();
    _roiTimer?.cancel();

    _rgbImage?.dispose();

    _commandChannel.invokeMethod(
      'setStage',
      <String, dynamic>{
        'stage': 1,
      },
    );

    super.dispose();
  }

  int _int(String key) {
    return (_data[key] as num?)?.toInt() ?? 0;
  }

  double _double(String key) {
    return (_data[key] as num?)?.toDouble() ?? 0.0;
  }

  bool _bool(String key) {
    return _data[key] == true;
  }

  String _poseMode() {
    switch (_int('poseMode')) {
      case 1:
        return 'ESSENTIAL';
      case 2:
        return 'HOMOGRAPHY';
      default:
        return 'NONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _bool('valid');

    return Scaffold(
      backgroundColor: const Color(0xFF0B1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111A23),
        foregroundColor: Colors.white,
        title: const Text(
          'Stage 4 Visualization',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _statusCard(
                      'STATUS',
                      valid ? 'LIVE' : 'WAITING',
                      valid ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statusCard(
                      'POSE',
                      _bool('poseValid') ? 'VALID' : 'NONE',
                      _bool('poseValid') ? Colors.greenAccent : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statusCard(
                      'MODE',
                      _poseMode(),
                      Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionTitle('FEATURE TRACKING'),
              const SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFF111A23),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF293746),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _FeatureTrackingView(
                    width: _rgbWidth > 0 ? _rgbWidth : _int('rgbWidth'),
                    height: _rgbHeight > 0 ? _rgbHeight : _int('rgbHeight'),
                    points: _data['features2d'] as List? ?? const [],
                    image: _rgbImage,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('VIO-SHAPED LOCAL 3D POINT CLOUD'),
              const SizedBox(height: 8),
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF111A23),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF293746),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _LocalPointCloudView(
                    points: _data['local3d'] as List? ?? const [],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('TRACKING METRICS'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.65,
                children: [
                  _metricCard(
                    'FEATURES',
                    '${_int('features')}',
                  ),
                  _metricCard(
                    'TRACKED',
                    '${_int('tracked')}',
                  ),
                  _metricCard(
                    'INLIERS',
                    '${_int('inliers')}',
                  ),
                  _metricCard(
                    'LOCAL 3D',
                    '${_int('localPoints')}',
                  ),
                  _metricCard(
                    'PROCESSING',
                    '${_double('processingMs').toStringAsFixed(2)} ms',
                  ),
                  _metricCard(
                    'TX',
                    '${_double('tx').toStringAsFixed(3)} m',
                  ),
                  _metricCard(
                    'TY',
                    '${_double('ty').toStringAsFixed(3)} m',
                  ),
                  _metricCard(
                    'TZ',
                    '${_double('tz').toStringAsFixed(3)} m',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A23),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Dynamic Stage 4: FAST feature extraction → LK tracking → '
                  'essential/homography pose → depth-backed local 3D.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _statusCard(
    String label,
    String value,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111A23),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF293746),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111A23),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF293746),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTrackingView extends StatelessWidget {
  const _FeatureTrackingView({
    required this.width,
    required this.height,
    required this.points,
    required this.image,
  });

  final int width;
  final int height;
  final List points;
  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FeatureTrackingPainter(
        imageWidth: width,
        imageHeight: height,
        points: points,
        image: image,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FeatureTrackingPainter extends CustomPainter {
  const _FeatureTrackingPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.points,
    required this.image,
  });

  final int imageWidth;
  final int imageHeight;
  final List points;
  final ui.Image? image;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint background = Paint()..color = const Color(0xFF0A0F14);

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    if (image == null || imageWidth <= 0 || imageHeight <= 0) {
      _drawLabel(
        canvas,
        size,
        'Waiting for live D455 RGB frame...',
      );
      return;
    }

    final double sx = size.width / imageWidth;
    final double sy = size.height / imageHeight;
    final double scale = math.min(sx, sy);

    final double drawWidth = imageWidth * scale;
    final double drawHeight = imageHeight * scale;

    final double ox = (size.width - drawWidth) / 2.0;

    final double oy = (size.height - drawHeight) / 2.0;

    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      imageWidth.toDouble(),
      imageHeight.toDouble(),
    );

    final Rect dstRect = Rect.fromLTWH(
      ox,
      oy,
      drawWidth,
      drawHeight,
    );

    final Paint imagePaint = Paint()..filterQuality = FilterQuality.low;

    canvas.drawImageRect(
      image!,
      srcRect,
      dstRect,
      imagePaint,
    );

    // Real FAST/LK tracked feature points.
    final Paint pointGlow = Paint()
      ..color = const Color(0x663BFF83)
      ..style = PaintingStyle.fill;

    final Paint pointPaint = Paint()
      ..color = const Color(0xFF35F47C)
      ..style = PaintingStyle.fill;

    for (final dynamic item in points) {
      if (item is! List || item.length < 2) {
        continue;
      }

      final double x = (item[0] as num).toDouble();

      final double y = (item[1] as num).toDouble();

      final Offset p = Offset(
        ox + x * scale,
        oy + y * scale,
      );

      canvas.drawCircle(
        p,
        4.0,
        pointGlow,
      );

      canvas.drawCircle(
        p,
        2.1,
        pointPaint,
      );
    }

    final Paint borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      dstRect,
      borderPaint,
    );

    // Bottom information strip.
    final Paint stripPaint = Paint()
      ..color = const Color(0xB0000000)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height - 38,
        size.width,
        38,
      ),
      stripPaint,
    );

    _drawLabel(
      canvas,
      size,
      '${points.length} tracked feature points',
    );
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    String text,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(
        12,
        size.height - painter.height - 10,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _FeatureTrackingPainter oldDelegate,
  ) {
    return oldDelegate.image != image ||
        oldDelegate.points != points ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}

class _LocalPointCloudView extends StatelessWidget {
  const _LocalPointCloudView({
    required this.points,
  });

  final List points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LocalPointCloudPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _LocalPointCloudPainter extends CustomPainter {
  const _LocalPointCloudPainter(this.points);

  final List points;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint background = Paint()..color = const Color(0xFF080D12);

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(20, cy),
      Offset(size.width - 20, cy),
      axisPaint,
    );

    canvas.drawLine(
      Offset(cx, 20),
      Offset(cx, size.height - 20),
      axisPaint,
    );

    final Paint pointPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    const double scale = 90.0;

    for (final dynamic item in points) {
      if (item is! List || item.length < 3) {
        continue;
      }

      final double x = (item[0] as num).toDouble();
      final double y = (item[1] as num).toDouble();
      final double z = (item[2] as num).toDouble();

      if (!x.isFinite || !y.isFinite || !z.isFinite) {
        continue;
      }

      if (z <= 0.01) {
        continue;
      }

      final double px = cx + (x / z) * scale;

      final double py = cy - (y / z) * scale;

      if (px < 0 || px > size.width || py < 0 || py > size.height) {
        continue;
      }

      canvas.drawCircle(
        Offset(px, py),
        2.0,
        pointPaint,
      );
    }

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '${points.length} local 3D points',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      const Offset(12, 12),
    );
  }

  @override
  bool shouldRepaint(
    covariant _LocalPointCloudPainter oldDelegate,
  ) {
    return oldDelegate.points != points;
  }
}
