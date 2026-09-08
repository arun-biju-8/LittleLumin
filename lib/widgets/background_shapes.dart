import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_state.dart';

class BackgroundItem {
  final int id;
  final double topRatio;
  final double leftRatio;
  final double size;
  final String type;
  final Color color;
  final double durationSeconds;
  final double delaySeconds;

  BackgroundItem({
    required this.id,
    required this.topRatio,
    required this.leftRatio,
    required this.size,
    required this.type,
    required this.color,
    required this.durationSeconds,
    required this.delaySeconds,
  });
}

class BackgroundShapes extends StatefulWidget {
  final bool animated;
  final ShapeDensity density;

  const BackgroundShapes({
    super.key,
    this.animated = true,
    this.density = ShapeDensity.normal,
  });

  @override
  State<BackgroundShapes> createState() => _BackgroundShapesState();
}

class _BackgroundShapesState extends State<BackgroundShapes>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<BackgroundItem> _items;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animated) {
      _animController.repeat(reverse: true);
    }
    _generateItems();
  }

  @override
  void didUpdateWidget(BackgroundShapes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.density != widget.density) {
      _generateItems();
    }
    if (oldWidget.animated != widget.animated) {
      if (widget.animated) {
        _animController.repeat(reverse: true);
      } else {
        _animController.stop();
      }
    }
  }

  void _generateItems() {
    final count = widget.density == ShapeDensity.sparse
        ? 8
        : widget.density == ShapeDensity.normal
            ? 14
            : 22;

    final types = ['star', 'circle', 'ring', 'sparkle'];
    final colors = [
      const Color(0x73F1C40F), // Warm Yellow
      const Color(0x8CFFFFFF), // White
      const Color(0x4D4A90D9), // Primary Blue
      const Color(0x4D9B59B6), // Soft Purple
    ];

    _items = List.generate(count, (i) {
      final topRatio = (((i * 17 + 8) % 85) + 5) / 100.0;
      final leftRatio = (((i * 23 + 12) % 88) + 6) / 100.0;
      final size = 8.0 + (i % 5) * 6.0;
      final type = types[i % types.length];
      final color = colors[i % colors.length];
      final duration = 3.0 + (i % 4) * 1.5;
      final delay = (i % 5) * 0.4;

      return BackgroundItem(
        id: i,
        topRatio: topRatio,
        leftRatio: leftRatio,
        size: size,
        type: type,
        color: color,
        durationSeconds: duration,
        delaySeconds: delay,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 375.0;
          final height =
              constraints.maxHeight.isFinite ? constraints.maxHeight : 760.0;

          return Stack(
            children: [
              // Ambient Waves Background
              Positioned.fill(
                child: CustomPaint(
                  painter: AmbientWavesPainter(),
                ),
              ),

              // Floating Shapes
              ..._items.map((item) {
                return AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final phase =
                        (_animController.value + item.delaySeconds / 6.0) % 1.0;
                    final floatY = widget.animated
                        ? math.sin(phase * math.pi * 2) * 12.0
                        : 0.0;
                    final floatX = widget.animated
                        ? (item.id % 2 == 0 ? 1 : -1) *
                            math.cos(phase * math.pi * 2) *
                            6.0
                        : 0.0;
                    final floatRot = widget.animated
                        ? (item.id % 2 == 0 ? 1 : -1) *
                            phase *
                            (math.pi / 4)
                        : 0.0;

                    return Positioned(
                      top: item.topRatio * height + floatY,
                      left: item.leftRatio * width + floatX,
                      width: item.size,
                      height: item.size,
                      child: Transform.rotate(
                        angle: floatRot,
                        child: _buildShapeWidget(item),
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShapeWidget(BackgroundItem item) {
    switch (item.type) {
      case 'circle':
        return Container(
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        );
      case 'ring':
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: item.color, width: 2.0),
          ),
        );
      case 'star':
        return CustomPaint(
          painter: StarShapePainter(color: item.color),
        );
      case 'sparkle':
      default:
        return CustomPaint(
          painter: SparkleShapePainter(color: item.color),
        );
    }
  }
}

class AmbientWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
          size.width * 0.25, size.height * 0.15, size.width * 0.5, size.height * 0.35)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.55, size.width, size.height * 0.2)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final paint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path1, paint1);

    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
          size.width * 0.3, size.height * 0.85, size.width * 0.6, size.height * 0.68)
      ..quadraticBezierTo(
          size.width * 0.8, size.height * 0.55, size.width, size.height * 0.8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paint2 = Paint()
      ..color = const Color(0xFF9B59B6).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant AmbientWavesPainter oldDelegate) => false;
}

class StarShapePainter extends CustomPainter {
  final Color color;
  StarShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.4;
    final path = Path();

    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * math.pi / 180;
      final innerAngle = ((i * 72 + 36) - 90) * math.pi / 180;

      final ox = cx + outerRadius * math.cos(outerAngle);
      final oy = cy + outerRadius * math.sin(outerAngle);
      final ix = cx + innerRadius * math.cos(innerAngle);
      final iy = cy + innerRadius * math.sin(innerAngle);

      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant StarShapePainter oldDelegate) => false;
}

class SparkleShapePainter extends CustomPainter {
  final Color color;
  SparkleShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w / 2, h / 2, w, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, h)
      ..quadraticBezierTo(w / 2, h / 2, 0, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant SparkleShapePainter oldDelegate) => false;
}
