// lib/widgets/logo_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum LogoSize { sm, md, lg, xl }

class LogoWidget extends StatefulWidget {
  final LogoSize size;
  final bool animated;

  const LogoWidget({
    super.key,
    this.size = LogoSize.lg,
    this.animated = true,
  });

  @override
  State<LogoWidget> createState() => _LogoWidgetState();
}

class _LogoWidgetState extends State<LogoWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    if (widget.animated) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        _floatController.repeat(reverse: true);
      } else {
        _rotationController.stop();
        _pulseController.stop();
        _floatController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  double _getDimension() {
    switch (widget.size) {
      case LogoSize.sm:
        return 64.0;
      case LogoSize.md:
        return 96.0;
      case LogoSize.lg:
        return 144.0;
      case LogoSize.xl:
        return 192.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimension = _getDimension();

    return SizedBox(
      width: dimension,
      height: dimension,
      child: AnimatedBuilder(
        animation: Listenable.merge(
          [_rotationController, _pulseController, _floatController]
        ),
        builder: (context, child) {
          final pulseValue =
              widget.animated ? (0.65 + _pulseController.value * 0.3) : 0.8;
          final floatY = widget.animated
              ? math.sin(_floatController.value * math.pi * 2) * 3
              : 0.0;
          final floatRot = widget.animated
              ? math.sin(_floatController.value * math.pi * 2) * 0.02
              : 0.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              // ✅ Outer Ambient Radial Glow (Keep this)
              Transform.scale(
                scale: 1.5,
                child: Opacity(
                  opacity: pulseValue,
                  child: Container(
                    width: dimension,
                    height: dimension,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x66F1C40F),
                          Color(0x339B59B6),
                          Color(0x444A90D9),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // ✅ Rotating Light Rays (Keep this)
              if (widget.animated)
                Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: SizedBox(
                    width: dimension * 1.4,
                    height: dimension * 1.4,
                    child: CustomPaint(
                      painter: LightRaysPainter(),
                    ),
                  ),
                ),

              // ✅ YOUR LOGO IMAGE (Replaces the emblem)
              Transform.translate(
                offset: Offset(0, floatY),
                child: Transform.rotate(
                  angle: floatRot,
                  child: Container(
                    width: dimension * 0.75,
                    height: dimension * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: const AssetImage('assets/logo/logo.png'),
                        fit: BoxFit.contain,
                        onError: (exception, stackTrace) {
                          // Fallback if image is missing
                          const Icon(Icons.broken_image, size: 50);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ✅ Keep LightRaysPainter as is (for the rotating rays)
class LightRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.9;
    final paintEven = Paint()
      ..color = const Color(0x66F1C40F)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintOdd = Paint()
      ..color = const Color(0x33F1C40F)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(dx, dy), i % 2 == 0 ? paintEven : paintOdd);
    }
  }

  @override
  bool shouldRepaint(covariant LightRaysPainter oldDelegate) => false;
}