import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A circular instrument-cluster gauge (swept arc with a numeric center).
class Gauge extends StatelessWidget {
  final String label;
  final double value; // 0..100
  final Color color;
  final IconData? icon;

  const Gauge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _GaugePainter(value: clamped / 100, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: color),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '${clamped.round()}%',
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value; // 0..1
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi * 0.75; // 135°
    const sweepTotal = math.pi * 1.5; // 270° arc
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surfaceHigh;

    final needle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, startAngle, sweepTotal, false, track);
    if (value > 0) {
      canvas.drawArc(rect, startAngle, sweepTotal * value.clamp(0.0, 1.0), false, needle);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}