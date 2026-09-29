import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class Stage2VisualizationScreen extends StatefulWidget {
  const Stage2VisualizationScreen({super.key});

  @override
  State<Stage2VisualizationScreen> createState() =>
      _Stage2VisualizationScreenState();
}

class _Stage2VisualizationScreenState extends State<Stage2VisualizationScreen> {
  static const MethodChannel _commandChannel =
      MethodChannel('com.hsv2/command');

  Timer? _timer;

  bool _running = false;
  bool _loading = false;

  double _processingMs = 0.0;
  int _validPoints = 0;
  int _voxelCount = 0;
  int _decimation = 2;
  double _voxelSizeM = 0.020;

  List<_Point3D> _points = <_Point3D>[];
  List<_Voxel3D> _voxels = <_Voxel3D>[];

  // Stage 2.6 RGB projection parameters.
  int _rgbWidth = 640;
  int _rgbHeight = 480;
  double _rgbFx = 0.0;
  double _rgbFy = 0.0;
  double _rgbCx = 320.0;
  double _rgbCy = 240.0;

  double _yaw = 0.55;
  double _pitch = -0.35;
  double _zoom = 1.0;

  Offset? _lastPanPosition;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();

    _running = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final appState = Provider.of<AppState>(
        context,
        listen: false,
      );

      if (appState.textureId == null) {
        appState.initNativeTexture();
      }
    });

    _commandChannel.invokeMethod(
      'setStage',
      <String, dynamic>{'stage': 2},
    );

    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _loadStage2Data(),
    );

    _loadStage2Data();
  }

  @override
  void dispose() {
    _timer?.cancel();

    _commandChannel.invokeMethod(
      'setStage',
      <String, dynamic>{'stage': 1},
    );

    super.dispose();
  }

  Future<void> _loadStage2Data() async {
    if (!_running || _loading) {
      return;
    }

    _loading = true;

    try {
      final raw = await _commandChannel.invokeMethod<dynamic>(
        'getStage2Visualization',
      );

      if (raw == null) {
        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(raw.toString()) as Map<String, dynamic>;

      if (!mounted) {
        return;
      }

      final pointsRaw = data['points'];
      final voxelsRaw = data['voxels'];

      final List<_Point3D> points = <_Point3D>[];
      if (pointsRaw is List) {
        for (final item in pointsRaw) {
          if (item is List && item.length >= 3) {
            final x = (item[0] as num?)?.toDouble();
            final y = (item[1] as num?)?.toDouble();
            final z = (item[2] as num?)?.toDouble();

            if (x != null && y != null && z != null) {
              points.add(_Point3D(x, y, z));
            }
          }
        }
      }

      final List<_Voxel3D> voxels = <_Voxel3D>[];
      if (voxelsRaw is List) {
        for (final item in voxelsRaw) {
          if (item is List && item.length >= 3) {
            final x = (item[0] as num?)?.toInt();
            final y = (item[1] as num?)?.toInt();
            final z = (item[2] as num?)?.toInt();

            if (x != null && y != null && z != null) {
              voxels.add(_Voxel3D(x, y, z));
            }
          }
        }
      }

      setState(() {
        _processingMs = (data['processingMs'] as num?)?.toDouble() ?? 0.0;

        _validPoints = (data['validPoints'] as num?)?.toInt() ?? 0;

        _voxelCount = (data['voxelCount'] as num?)?.toInt() ?? 0;

        _decimation = (data['decimation'] as num?)?.toInt() ?? 2;

        _voxelSizeM = (data['voxelSizeM'] as num?)?.toDouble() ?? 0.020;

        _rgbWidth = (data['rgbWidth'] as num?)?.toInt() ?? 640;

        _rgbHeight = (data['rgbHeight'] as num?)?.toInt() ?? 480;

        _rgbFx = (data['rgbFx'] as num?)?.toDouble() ?? 0.0;

        _rgbFy = (data['rgbFy'] as num?)?.toDouble() ?? 0.0;

        _rgbCx = (data['rgbCx'] as num?)?.toDouble() ?? 320.0;

        _rgbCy = (data['rgbCy'] as num?)?.toDouble() ?? 240.0;

        _points = points;
        _voxels = voxels;
      });
    } catch (e) {
      debugPrint('Stage 2 visualization error: $e');
    } finally {
      _loading = false;
    }
  }

  void _resetView() {
    setState(() {
      _yaw = 0.55;
      _pitch = -0.35;
      _zoom = 1.0;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.focalPoint;
    _lastScale = 1.0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      final scaleDelta = details.scale / _lastScale;

      setState(() {
        _zoom = (_zoom * scaleDelta).clamp(0.45, 3.5);
      });

      _lastScale = details.scale;
      return;
    }

    if (_lastPanPosition == null) {
      _lastPanPosition = details.focalPoint;
      return;
    }

    final delta = details.focalPoint - _lastPanPosition!;

    setState(() {
      _yaw += delta.dx * 0.010;
      _pitch += delta.dy * 0.010;

      _pitch = _pitch.clamp(-1.45, 1.45);
    });

    _lastPanPosition = details.focalPoint;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastPanPosition = null;
    _lastScale = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _points.isNotEmpty || _voxels.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A202B),
        foregroundColor: Colors.white,
        title: const Text(
          'Stage 2 Visualization',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset 3D View',
            onPressed: _resetView,
            icon: const Icon(Icons.threesixty),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMetrics(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildSectionTitle(
                    'RGB + 3D / VOXEL OVERLAY',
                    Icons.camera_alt_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildRgbOverlay(),
                  const SizedBox(height: 18),
                  _buildSectionTitle(
                    '3D POINT CLOUD',
                    Icons.scatter_plot_outlined,
                  ),
                  const SizedBox(height: 8),
                  _build3DPanel(
                    child: _PointCloud3DView(
                      points: _points,
                      yaw: _yaw,
                      pitch: _pitch,
                      zoom: _zoom,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSectionTitle(
                    '3D SINGLE-FRAME VOXEL GRID',
                    Icons.grid_3x3,
                  ),
                  const SizedBox(height: 8),
                  _build3DPanel(
                    child: _Voxel3DView(
                      voxels: _voxels,
                      voxelSize: _voxelSizeM,
                      yaw: _yaw,
                      pitch: _pitch,
                      zoom: _zoom,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildControls(hasData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRgbOverlay() {
    final textureId = context.watch<AppState>().textureId;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF05080D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF28313D),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: textureId == null
            ? const Center(
                child: Text(
                  'WAITING FOR RGB TEXTURE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Texture(
                    textureId: textureId,
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _RgbStage2OverlayPainter(
                        points: _points,
                        voxels: _voxels,
                        rgbWidth: _rgbWidth,
                        rgbHeight: _rgbHeight,
                        fx: _rgbFx,
                        fy: _rgbFy,
                        cx: _rgbCx,
                        cy: _rgbCy,
                        voxelSize: _voxelSizeM,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE RGB + 3D/Voxel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMetrics() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: const Color(0xFF101720),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              'POINTS',
              _validPoints.toString(),
            ),
          ),
          Expanded(
            child: _metric(
              'VOXELS',
              _voxelCount.toString(),
            ),
          ),
          Expanded(
            child: _metric(
              'PROCESSING',
              '${_processingMs.toStringAsFixed(1)} ms',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.lightBlueAccent,
          size: 18,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _build3DPanel({required Widget child}) {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        color: const Color(0xFF05080D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF28313D),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        child: child,
      ),
    );
  }

  Widget _buildControls(bool hasData) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121A23),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF26323F),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                color: Colors.lightBlueAccent,
                size: 18,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'DRAG TO ROTATE  •  PINCH TO ZOOM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetView,
                child: const Text('RESET'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _decimationSelector(),
              const SizedBox(width: 28),
              _configItem(
                'Voxel',
                '${(_voxelSizeM * 1000).toStringAsFixed(0)} mm',
              ),
              const Spacer(),
              Text(
                hasData ? 'LIVE' : 'WAITING',
                style: TextStyle(
                  color: hasData ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decimationSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Decimation',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2530),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF344454),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _decimation == 4 ? 4 : 2,
              dropdownColor: const Color(0xFF1A2530),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.white70,
                size: 18,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              items: const [
                DropdownMenuItem<int>(
                  value: 2,
                  child: Text('2×'),
                ),
                DropdownMenuItem<int>(
                  value: 4,
                  child: Text('4×'),
                ),
              ],
              onChanged: (value) async {
                if (value == null || value == _decimation) {
                  return;
                }

                print('STAGE2 UI: setting decimation to ${value}x');

                await _commandChannel.invokeMethod(
                  'setStage2Decimation',
                  <String, dynamic>{
                    'decimation': value,
                  },
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _decimation = value;
                });

                print('STAGE2 UI: decimation updated to ${value}x');
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _configItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _RgbStage2OverlayPainter extends CustomPainter {
  final List<_Point3D> points;
  final List<_Voxel3D> voxels;

  final int rgbWidth;
  final int rgbHeight;

  final double fx;
  final double fy;
  final double cx;
  final double cy;

  final double voxelSize;

  const _RgbStage2OverlayPainter({
    required this.points,
    required this.voxels,
    required this.rgbWidth,
    required this.rgbHeight,
    required this.fx,
    required this.fy,
    required this.cx,
    required this.cy,
    required this.voxelSize,
  });

  Offset? _project(
    double x,
    double y,
    double z,
    Size size,
  ) {
    if (!z.isFinite ||
        z <= 0.10 ||
        fx <= 0.0 ||
        fy <= 0.0 ||
        rgbWidth <= 0 ||
        rgbHeight <= 0) {
      return null;
    }

    final u = fx * x / z + cx;
    final v = fy * y / z + cy;

    if (!u.isFinite ||
        !v.isFinite ||
        u < 0.0 ||
        u >= rgbWidth ||
        v < 0.0 ||
        v >= rgbHeight) {
      return null;
    }

    return Offset(
      u * size.width / rgbWidth,
      v * size.height / rgbHeight,
    );
  }

  double _pointRadius(double z) {
    if (z <= 0.5) return 2.2;
    if (z >= 5.0) return 1.0;

    return (2.2 - (z - 0.5) * 0.30).clamp(1.0, 2.2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ------------------------------------------------------------
    // Stage 2.6
    // Full live 3D point projection onto the RGB frame.
    //
    // Native Stage 2 now sends every valid deprojected point.
    // Render the complete live point set without additional
    // Flutter-side thinning.
    // ------------------------------------------------------------

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = Colors.cyanAccent.withOpacity(0.72);

    for (final point in points) {

      final projected = _project(
        point.x,
        point.y,
        point.z,
        size,
      );

      if (projected == null) {
        continue;
      }

      canvas.drawCircle(
        projected,
        _pointRadius(point.z),
        pointPaint,
      );
    }

    // ------------------------------------------------------------
    // Stage 2.6
    // Sparse voxel occupancy overlay.
    //
    // Do not draw a projected rectangle for every voxel. At 20 mm
    // voxel size this produces heavy overlap on the RGB image.
    // Instead, render a small occupancy marker at the voxel centre.
    // ------------------------------------------------------------

    final voxelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..color = Colors.amberAccent.withOpacity(0.78);

    final voxelFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = Colors.amberAccent.withOpacity(0.20);

    // Render approximately 1/4 of the bounded voxel sample.
    for (int i = 0; i < voxels.length; i += 4) {
      final voxel = voxels[i];

      final x = (voxel.x + 0.5) * voxelSize;
      final y = (voxel.y + 0.5) * voxelSize;
      final z = (voxel.z + 0.5) * voxelSize;

      final projected = _project(
        x,
        y,
        z,
        size,
      );

      if (projected == null) {
        continue;
      }

      // Small fixed marker keeps the RGB scene readable.
      const double marker = 2.5;

      final rect = Rect.fromCenter(
        center: projected,
        width: marker * 2,
        height: marker * 2,
      );

      canvas.drawRect(
        rect,
        voxelFillPaint,
      );

      canvas.drawRect(
        rect,
        voxelPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _RgbStage2OverlayPainter oldDelegate,
  ) {
    return oldDelegate.points != points ||
        oldDelegate.voxels != voxels ||
        oldDelegate.rgbWidth != rgbWidth ||
        oldDelegate.rgbHeight != rgbHeight ||
        oldDelegate.fx != fx ||
        oldDelegate.fy != fy ||
        oldDelegate.cx != cx ||
        oldDelegate.cy != cy ||
        oldDelegate.voxelSize != voxelSize;
  }
}

class _Point3D {
  final double x;
  final double y;
  final double z;

  const _Point3D(this.x, this.y, this.z);
}

class _Voxel3D {
  final int x;
  final int y;
  final int z;

  const _Voxel3D(this.x, this.y, this.z);
}

class _ProjectedPoint {
  final Offset offset;
  final double depth;

  const _ProjectedPoint(this.offset, this.depth);
}

class _Camera3D {
  final double yaw;
  final double pitch;
  final double zoom;
  final Size size;

  const _Camera3D({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.size,
  });

  _ProjectedPoint? project(
    double x,
    double y,
    double z,
  ) {
    // Camera-space transform.
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);

    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    // Rotate around world Y.
    final rx = x * cy - z * sy;
    final rz = x * sy + z * cy;

    // Rotate around world X.
    final ry = y * cp - rz * sp;
    final depth = y * sp + rz * cp;

    // Move the camera backwards so the complete cloud is visible.
    final cameraDistance = 2.8;

    final perspectiveDenominator = cameraDistance + depth;

    if (perspectiveDenominator <= 0.15) {
      return null;
    }

    final focal = math.min(size.width, size.height) * 0.72 * zoom;

    final sx = size.width / 2 + rx * focal / perspectiveDenominator;

    final syScreen = size.height / 2 - ry * focal / perspectiveDenominator;

    return _ProjectedPoint(
      Offset(sx, syScreen),
      depth,
    );
  }
}

class _PointCloud3DView extends StatelessWidget {
  final List<_Point3D> points;
  final double yaw;
  final double pitch;
  final double zoom;

  const _PointCloud3DView({
    required this.points,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PointCloud3DPainter(
        points: points,
        yaw: yaw,
        pitch: pitch,
        zoom: zoom,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PointCloud3DPainter extends CustomPainter {
  final List<_Point3D> points;
  final double yaw;
  final double pitch;
  final double zoom;

  const _PointCloud3DPainter({
    required this.points,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    if (points.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final bounds = _calculateBounds(points);

    final camera = _ReferenceCamera3D(
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      size: size,
      bounds: bounds,
    );

    _drawGrid(canvas, camera);
    _drawAxes(canvas, camera);

    final projected = <_ReferenceProjectedPoint>[];

    for (final point in points) {
      final p = camera.project(
        point.x,
        point.y,
        point.z,
      );

      if (p != null &&
          p.offset.dx >= -30 &&
          p.offset.dx <= size.width + 30 &&
          p.offset.dy >= -30 &&
          p.offset.dy <= size.height + 30) {
        projected.add(p);
      }
    }

    // Far-to-near ordering gives the cloud a stronger 3D appearance.
    projected.sort(
      (a, b) => b.depth.compareTo(a.depth),
    );

    for (final point in projected) {
      final normalizedDepth = ((point.depth + 1.0) / 2.0).clamp(0.0, 1.0);

      final radius = (1.2 + normalizedDepth * 2.0).clamp(1.2, 3.2);

      final pointPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          const Color(0xFF48D7FF),
          const Color(0xFFB9F4FF),
          normalizedDepth,
        )!;

      canvas.drawCircle(
        point.offset,
        radius,
        pointPaint,
      );
    }

    _drawOriginMarker(canvas, camera);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF050A10);

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    final glowPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x182B6F88),
          Color(0x00050A10),
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(
            size.width / 2,
            size.height / 2,
          ),
          width: size.width * 0.9,
          height: size.height * 0.9,
        ),
      );

    canvas.drawRect(
      Offset.zero & size,
      glowPaint,
    );
  }

  _ReferenceBounds _calculateBounds(
    List<_Point3D> source,
  ) {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;

    for (final p in source) {
      if (!p.x.isFinite || !p.y.isFinite || !p.z.isFinite) {
        continue;
      }

      minX = minX < p.x ? minX : p.x;
      maxX = maxX > p.x ? maxX : p.x;
      minY = minY < p.y ? minY : p.y;
      maxY = maxY > p.y ? maxY : p.y;
      minZ = minZ < p.z ? minZ : p.z;
      maxZ = maxZ > p.z ? maxZ : p.z;
    }

    if (!minX.isFinite) {
      return const _ReferenceBounds(
        minX: -1,
        maxX: 1,
        minY: -1,
        maxY: 1,
        minZ: 0,
        maxZ: 2,
      );
    }

    return _ReferenceBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      minZ: minZ,
      maxZ: maxZ,
    );
  }

  void _drawGrid(
    Canvas canvas,
    _ReferenceCamera3D camera,
  ) {
    final paint = Paint()
      ..color = const Color(0x283A5968)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const gridExtent = 1.0;
    const divisions = 8;

    for (int i = -divisions; i <= divisions; i++) {
      final t = i / divisions;

      final a = camera.projectNormalized(
        t * gridExtent,
        0,
        -gridExtent,
      );

      final b = camera.projectNormalized(
        t * gridExtent,
        0,
        gridExtent,
      );

      if (a != null && b != null) {
        canvas.drawLine(
          a.offset,
          b.offset,
          paint,
        );
      }

      final c = camera.projectNormalized(
        -gridExtent,
        0,
        t * gridExtent,
      );

      final d = camera.projectNormalized(
        gridExtent,
        0,
        t * gridExtent,
      );

      if (c != null && d != null) {
        canvas.drawLine(
          c.offset,
          d.offset,
          paint,
        );
      }
    }
  }

  void _drawAxes(
    Canvas canvas,
    _ReferenceCamera3D camera,
  ) {
    _drawAxis(
      canvas,
      camera,
      const _ReferenceVector(1, 0, 0),
      const Color(0xFFFF5A67),
      'X',
    );

    _drawAxis(
      canvas,
      camera,
      const _ReferenceVector(0, 1, 0),
      const Color(0xFF66F28A),
      'Y',
    );

    _drawAxis(
      canvas,
      camera,
      const _ReferenceVector(0, 0, 1),
      const Color(0xFF55A8FF),
      'Z',
    );
  }

  void _drawAxis(
    Canvas canvas,
    _ReferenceCamera3D camera,
    _ReferenceVector direction,
    Color color,
    String label,
  ) {
    final origin = camera.projectNormalized(0, 0, 0);

    final end = camera.projectNormalized(
      direction.x,
      direction.y,
      direction.z,
    );

    if (origin == null || end == null) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      origin.offset,
      end.offset,
      paint,
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    labelPainter.paint(
      canvas,
      end.offset + const Offset(5, -7),
    );
  }

  void _drawOriginMarker(
    Canvas canvas,
    _ReferenceCamera3D camera,
  ) {
    final origin = camera.projectNormalized(0, 0, 0);

    if (origin == null) {
      return;
    }

    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      origin.offset,
      3.0,
      paint,
    );
  }

  void _drawEmptyState(
    Canvas canvas,
    Size size,
  ) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Waiting for live D455 3D points...',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _PointCloud3DPainter oldDelegate,
  ) {
    return oldDelegate.points != points ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom;
  }
}

class _ReferenceBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double minZ;
  final double maxZ;

  const _ReferenceBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
  });
}

class _ReferenceVector {
  final double x;
  final double y;
  final double z;

  const _ReferenceVector(
    this.x,
    this.y,
    this.z,
  );
}

class _ReferenceProjectedPoint {
  final Offset offset;
  final double depth;

  const _ReferenceProjectedPoint(
    this.offset,
    this.depth,
  );
}

class _ReferenceCamera3D {
  final double yaw;
  final double pitch;
  final double zoom;
  final Size size;
  final _ReferenceBounds bounds;

  const _ReferenceCamera3D({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.size,
    required this.bounds,
  });

  _ReferenceProjectedPoint? project(
    double x,
    double y,
    double z,
  ) {
    final centerX = (bounds.minX + bounds.maxX) / 2.0;
    final centerY = (bounds.minY + bounds.maxY) / 2.0;
    final centerZ = (bounds.minZ + bounds.maxZ) / 2.0;

    final extentX = (bounds.maxX - bounds.minX).abs();
    final extentY = (bounds.maxY - bounds.minY).abs();
    final extentZ = (bounds.maxZ - bounds.minZ).abs();

    final extent = [
      extentX,
      extentY,
      extentZ,
      0.001,
    ].reduce(
      (a, b) => a > b ? a : b,
    );

    return projectNormalized(
      (x - centerX) / extent,
      (y - centerY) / extent,
      (z - centerZ) / extent,
    );
  }

  _ReferenceProjectedPoint? projectNormalized(
    double x,
    double y,
    double z,
  ) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    final x1 = x * cy - z * sy;
    final z1 = x * sy + z * cy;

    final y1 = y * cp - z1 * sp;
    final z2 = y * sp + z1 * cp;

    const cameraDistance = 3.2;
    final perspective = cameraDistance / (cameraDistance + z2);

    if (!perspective.isFinite || perspective <= 0) {
      return null;
    }

    final scale = math.min(size.width, size.height) * 0.38 * zoom;

    final sx = size.width / 2 + x1 * scale * perspective;

    final syScreen = size.height / 2 - y1 * scale * perspective;

    return _ReferenceProjectedPoint(
      Offset(sx, syScreen),
      z2,
    );
  }
}

class _Voxel3DView extends StatelessWidget {
  final List<_Voxel3D> voxels;
  final double voxelSize;
  final double yaw;
  final double pitch;
  final double zoom;

  const _Voxel3DView({
    required this.voxels,
    required this.voxelSize,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Voxel3DPainter(
        voxels: voxels,
        voxelSize: voxelSize,
        yaw: yaw,
        pitch: pitch,
        zoom: zoom,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Voxel3DPainter extends CustomPainter {
  final List<_Voxel3D> voxels;
  final double voxelSize;
  final double yaw;
  final double pitch;
  final double zoom;

  const _Voxel3DPainter({
    required this.voxels,
    required this.voxelSize,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    if (voxels.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final bounds = _calculateBounds(voxels);

    final camera = _VoxelReferenceCamera3D(
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      size: size,
      bounds: bounds,
    );

    _drawGrid(canvas, camera);
    _drawAxes(canvas, camera);

    final projectedCubes = <_VoxelProjectedCube>[];

    /*
     * Render-only visualization:
     *
     * Native Stage 2 still produces the complete occupied voxel set.
     * Here we render only the visible surface voxels so individual
     * 3D cells remain readable instead of becoming one solid blob.
     */
    const maxRenderedVoxels = 7000;

    final occupied = <String>{};

    for (final voxel in voxels) {
      occupied.add(
        '${voxel.x}:${voxel.y}:${voxel.z}',
      );
    }

    bool isSurfaceVoxel(_Voxel3D voxel) {
      const neighbors = <List<int>>[
        [-1, 0, 0],
        [1, 0, 0],
        [0, -1, 0],
        [0, 1, 0],
        [0, 0, -1],
        [0, 0, 1],
      ];

      for (final n in neighbors) {
        final key = '${voxel.x + n[0]}:'
            '${voxel.y + n[1]}:'
            '${voxel.z + n[2]}';

        if (!occupied.contains(key)) {
          return true;
        }
      }

      return false;
    }

    final surfaceVoxels = <_Voxel3D>[];

    for (final voxel in voxels) {
      if (isSurfaceVoxel(voxel)) {
        surfaceVoxels.add(voxel);
      }
    }

    final renderStride = surfaceVoxels.length <= maxRenderedVoxels
        ? 1
        : (surfaceVoxels.length / maxRenderedVoxels).ceil();

    const half = 0.65;

    for (int index = 0; index < surfaceVoxels.length; index += renderStride) {
      final voxel = surfaceVoxels[index];

      final cx = voxel.x.toDouble();
      final cy = voxel.y.toDouble();
      final cz = voxel.z.toDouble();

      final corners = <_VoxelProjectedPoint?>[
        camera.project(cx - half, cy - half, cz - half),
        camera.project(cx + half, cy - half, cz - half),
        camera.project(cx + half, cy + half, cz - half),
        camera.project(cx - half, cy + half, cz - half),
        camera.project(cx - half, cy - half, cz + half),
        camera.project(cx + half, cy - half, cz + half),
        camera.project(cx + half, cy + half, cz + half),
        camera.project(cx - half, cy + half, cz + half),
      ];

      if (corners.any((corner) => corner == null)) {
        continue;
      }

      final validCorners = corners.cast<_VoxelProjectedPoint>();

      final depth = validCorners.map((point) => point.depth).reduce(
                (a, b) => a + b,
              ) /
          validCorners.length;

      projectedCubes.add(
        _VoxelProjectedCube(
          corners: validCorners,
          depth: depth,
        ),
      );
    }

    /*
     * Painter's algorithm:
     * draw farther voxels first so nearer blocks naturally
     * appear in front.
     */
    projectedCubes.sort(
      (a, b) => b.depth.compareTo(a.depth),
    );

    for (final cube in projectedCubes) {
      _drawCube(
        canvas,
        cube,
      );
    }

    _drawOriginMarker(canvas, camera);
  }

  void _drawBackground(
    Canvas canvas,
    Size size,
  ) {
    final bg = Paint()
      ..color = const Color(0xFF050A10)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Offset.zero & size,
      bg,
    );

    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x142B6F88),
          Color(0x00050A10),
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(
            size.width / 2,
            size.height / 2,
          ),
          width: size.width * 0.95,
          height: size.height * 0.95,
        ),
      );

    canvas.drawRect(
      Offset.zero & size,
      glow,
    );
  }

  _VoxelReferenceBounds _calculateBounds(
    List<_Voxel3D> source,
  ) {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;

    for (final voxel in source) {
      if (!voxel.x.isFinite || !voxel.y.isFinite || !voxel.z.isFinite) {
        continue;
      }

      minX = minX < voxel.x ? minX : voxel.x.toDouble();
      maxX = maxX > voxel.x ? maxX : voxel.x.toDouble();

      minY = minY < voxel.y ? minY : voxel.y.toDouble();
      maxY = maxY > voxel.y ? maxY : voxel.y.toDouble();

      minZ = minZ < voxel.z ? minZ : voxel.z.toDouble();
      maxZ = maxZ > voxel.z ? maxZ : voxel.z.toDouble();
    }

    if (!minX.isFinite) {
      return const _VoxelReferenceBounds(
        minX: -1,
        maxX: 1,
        minY: -1,
        maxY: 1,
        minZ: -1,
        maxZ: 1,
      );
    }

    return _VoxelReferenceBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      minZ: minZ,
      maxZ: maxZ,
    );
  }

  void _drawGrid(
    Canvas canvas,
    _VoxelReferenceCamera3D camera,
  ) {
    final paint = Paint()
      ..color = const Color(0x263A5968)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const extent = 1.0;
    const divisions = 8;

    for (int i = -divisions; i <= divisions; i++) {
      final t = i / divisions;

      final a = camera.projectNormalized(
        t,
        0,
        -extent,
      );

      final b = camera.projectNormalized(
        t,
        0,
        extent,
      );

      if (a != null && b != null) {
        canvas.drawLine(
          a.offset,
          b.offset,
          paint,
        );
      }

      final c = camera.projectNormalized(
        -extent,
        0,
        t,
      );

      final d = camera.projectNormalized(
        extent,
        0,
        t,
      );

      if (c != null && d != null) {
        canvas.drawLine(
          c.offset,
          d.offset,
          paint,
        );
      }
    }
  }

  void _drawCube(
    Canvas canvas,
    _VoxelProjectedCube cube,
  ) {
    final p = cube.corners;

    /*
     * Face ordering:
     *
     * 0-1-2-3 = lower/front face
     * 4-5-6-7 = upper/back face
     *
     * The different tones create the 3D block appearance.
     */

    final frontPaint = Paint()
      ..color = const Color(0xFFFF9D32).withOpacity(0.30)
      ..style = PaintingStyle.fill;

    final topPaint = Paint()
      ..color = const Color(0xFFFFD166).withOpacity(0.36)
      ..style = PaintingStyle.fill;

    final sidePaint = Paint()
      ..color = const Color(0xFFFFB13B).withOpacity(0.32)
      ..style = PaintingStyle.fill;

    final leftPaint = Paint()
      ..color = const Color(0xFFFF8A24).withOpacity(0.28)
      ..style = PaintingStyle.fill;

    final edgePaint = Paint()
      ..color = const Color(0xFFFFD166).withOpacity(0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final face0 = Path()
      ..moveTo(p[0].offset.dx, p[0].offset.dy)
      ..lineTo(p[1].offset.dx, p[1].offset.dy)
      ..lineTo(p[2].offset.dx, p[2].offset.dy)
      ..lineTo(p[3].offset.dx, p[3].offset.dy)
      ..close();

    final face1 = Path()
      ..moveTo(p[4].offset.dx, p[4].offset.dy)
      ..lineTo(p[5].offset.dx, p[5].offset.dy)
      ..lineTo(p[6].offset.dx, p[6].offset.dy)
      ..lineTo(p[7].offset.dx, p[7].offset.dy)
      ..close();

    final rightFace = Path()
      ..moveTo(p[1].offset.dx, p[1].offset.dy)
      ..lineTo(p[5].offset.dx, p[5].offset.dy)
      ..lineTo(p[6].offset.dx, p[6].offset.dy)
      ..lineTo(p[2].offset.dx, p[2].offset.dy)
      ..close();

    final leftFace = Path()
      ..moveTo(p[0].offset.dx, p[0].offset.dy)
      ..lineTo(p[4].offset.dx, p[4].offset.dy)
      ..lineTo(p[7].offset.dx, p[7].offset.dy)
      ..lineTo(p[3].offset.dx, p[3].offset.dy)
      ..close();

    final topFace = Path()
      ..moveTo(p[3].offset.dx, p[3].offset.dy)
      ..lineTo(p[2].offset.dx, p[2].offset.dy)
      ..lineTo(p[6].offset.dx, p[6].offset.dy)
      ..lineTo(p[7].offset.dx, p[7].offset.dy)
      ..close();

    canvas.drawPath(
      face0,
      frontPaint,
    );

    canvas.drawPath(
      rightFace,
      sidePaint,
    );

    canvas.drawPath(
      leftFace,
      leftPaint,
    );

    canvas.drawPath(
      topFace,
      topPaint,
    );

    /*
     * Draw the rear face lightly so that individual occupied
     * voxels remain visually separable.
     */
    canvas.drawPath(
      face1,
      topPaint..color = const Color(0xFFFFC15A).withOpacity(0.25),
    );

    const edges = <List<int>>[
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 4],
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ];

    for (final edge in edges) {
      canvas.drawLine(
        p[edge[0]].offset,
        p[edge[1]].offset,
        edgePaint,
      );
    }
  }

  void _drawAxes(
    Canvas canvas,
    _VoxelReferenceCamera3D camera,
  ) {
    _drawAxis(
      canvas,
      camera,
      const _VoxelVector(1, 0, 0),
      const Color(0xFFFF5A67),
      'X',
    );

    _drawAxis(
      canvas,
      camera,
      const _VoxelVector(0, 1, 0),
      const Color(0xFF66F28A),
      'Y',
    );

    _drawAxis(
      canvas,
      camera,
      const _VoxelVector(0, 0, 1),
      const Color(0xFF55A8FF),
      'Z',
    );
  }

  void _drawAxis(
    Canvas canvas,
    _VoxelReferenceCamera3D camera,
    _VoxelVector direction,
    Color color,
    String label,
  ) {
    final origin = camera.projectNormalized(
      0,
      0,
      0,
    );

    final end = camera.projectNormalized(
      direction.x,
      direction.y,
      direction.z,
    );

    if (origin == null || end == null) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      origin.offset,
      end.offset,
      paint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      end.offset + const Offset(5, -7),
    );
  }

  void _drawOriginMarker(
    Canvas canvas,
    _VoxelReferenceCamera3D camera,
  ) {
    final origin = camera.projectNormalized(
      0,
      0,
      0,
    );

    if (origin == null) {
      return;
    }

    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      origin.offset,
      3.0,
      paint,
    );
  }

  void _drawEmptyState(
    Canvas canvas,
    Size size,
  ) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Waiting for live D455 voxels...',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _Voxel3DPainter oldDelegate,
  ) {
    return oldDelegate.voxels != voxels ||
        oldDelegate.voxelSize != voxelSize ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom;
  }
}

class _VoxelReferenceBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double minZ;
  final double maxZ;

  const _VoxelReferenceBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
  });
}

class _VoxelVector {
  final double x;
  final double y;
  final double z;

  const _VoxelVector(
    this.x,
    this.y,
    this.z,
  );
}

class _VoxelProjectedPoint {
  final Offset offset;
  final double depth;

  const _VoxelProjectedPoint(
    this.offset,
    this.depth,
  );
}

class _VoxelProjectedCube {
  final List<_VoxelProjectedPoint> corners;
  final double depth;

  const _VoxelProjectedCube({
    required this.corners,
    required this.depth,
  });
}

class _VoxelReferenceCamera3D {
  final double yaw;
  final double pitch;
  final double zoom;
  final Size size;
  final _VoxelReferenceBounds bounds;

  const _VoxelReferenceCamera3D({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.size,
    required this.bounds,
  });

  _VoxelProjectedPoint? project(
    double x,
    double y,
    double z,
  ) {
    final centerX = (bounds.minX + bounds.maxX) / 2.0;
    final centerY = (bounds.minY + bounds.maxY) / 2.0;
    final centerZ = (bounds.minZ + bounds.maxZ) / 2.0;

    final extentX = (bounds.maxX - bounds.minX).abs();
    final extentY = (bounds.maxY - bounds.minY).abs();
    final extentZ = (bounds.maxZ - bounds.minZ).abs();

    final extent = math
        .max(
          1.0,
          math.max(
            extentX,
            math.max(
              extentY,
              extentZ,
            ),
          ),
        )
        .toDouble();

    return projectNormalized(
      (x - centerX) / extent,
      (y - centerY) / extent,
      (z - centerZ) / extent,
    );
  }

  _VoxelProjectedPoint? projectNormalized(
    double x,
    double y,
    double z,
  ) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    final x1 = x * cy - z * sy;
    final z1 = x * sy + z * cy;

    final y1 = y * cp - z1 * sp;
    final z2 = y * sp + z1 * cp;

    const cameraDistance = 3.2;

    final denominator = cameraDistance + z2;

    if (!denominator.isFinite || denominator <= 0.25) {
      return null;
    }

    final perspective = cameraDistance / denominator;

    final scale = math.min(size.width, size.height) * 0.42 * zoom;

    final sx = size.width / 2 + x1 * scale * perspective;

    final syScreen = size.height / 2 - y1 * scale * perspective;

    if (!sx.isFinite || !syScreen.isFinite) {
      return null;
    }

    return _VoxelProjectedPoint(
      Offset(
        sx,
        syScreen,
      ),
      z2,
    );
  }
}

class _ProjectedCube {
  final List<_ProjectedPoint> corners;
  final double depth;

  const _ProjectedCube({
    required this.corners,
    required this.depth,
  });
}
