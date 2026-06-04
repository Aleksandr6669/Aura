import 'dart:ui';
import 'package:flutter/material.dart';

class ScopeChart extends StatelessWidget {
  final List<double> historyX;
  final List<double> historyY;
  final List<double> historyZ;
  final List<double> historyMag;

  const ScopeChart({
    super.key,
    required this.historyX,
    required this.historyY,
    required this.historyZ,
    required this.historyMag,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScopePainter(
        historyX: historyX,
        historyY: historyY,
        historyZ: historyZ,
        historyMag: historyMag,
      ),
      child: Container(),
    );
  }
}

class _ScopePainter extends CustomPainter {
  final List<double> historyX;
  final List<double> historyY;
  final List<double> historyZ;
  final List<double> historyMag;

  _ScopePainter({
    required this.historyX,
    required this.historyY,
    required this.historyZ,
    required this.historyMag,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw background grid
    final gridPaint = Paint()
      ..color = const Color(0xFF181A26)
      ..strokeWidth = 1.0;

    // 1. Calculate dynamic max scale based on peak history values
    double maxVal = 10.0;
    for (var val in historyX) {
      if (val.abs() > maxVal) maxVal = val.abs();
    }
    for (var val in historyY) {
      if (val.abs() > maxVal) maxVal = val.abs();
    }
    for (var val in historyZ) {
      if (val.abs() > maxVal) maxVal = val.abs();
    }
    for (var val in historyMag) {
      if (val.abs() > maxVal) maxVal = val.abs();
    }

    // Set dynamic maxScale directly to maxVal with a minimum floor of 100.0 (no headroom multiplier)
    double maxScale = maxVal;
    if (maxScale < 100.0) maxScale = 100.0;

    // Draw vertical grid lines
    const int verticalDividers = 10;
    for (int i = 0; i <= verticalDividers; i++) {
      final double x = (w / verticalDividers) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // Draw dynamic horizontal grid lines based on current maxScale
    final double step = (maxScale / 4).roundToDouble();
    final levels = [-4 * step, -3 * step, -2 * step, -step, 0.0, step, 2 * step, 3 * step, 4 * step];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var lvl in levels) {
      // Map level value to y-axis coordinates (0 is center)
      final double y = h / 2 - (lvl / maxScale) * (h / 2 * 0.9);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);

      // Level text labels
      textPainter.text = TextSpan(
        text: lvl.toInt().toString(),
        style: const TextStyle(
          color: Color(0xFF6C6E85),
          fontFamily: 'Fira Code',
          fontSize: 8.5,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(15, y - 10));
    }

    if (historyX.isEmpty) return;

    // Line drawing helper
    void drawTrace(List<double> history, Color color, {bool dotted = false, double thickness = 2.0}) {
      final tracePaint = Paint()
        ..color = color
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final Path path = Path();
      for (int i = 0; i < history.length; i++) {
        final double x = (i / (history.length - 1)) * w;
        final double y = h / 2 - (history[i] / maxScale) * (h / 2 * 0.9);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      if (dotted) {
        // Draw custom dotted path for Magnitude
        final dashWidth = 5.0;
        final dashSpace = 3.0;
        double distance = 0.0;
        final Path dashPath = Path();

        for (final PathMetric pathMetric in path.computeMetrics()) {
          while (distance < pathMetric.length) {
            dashPath.addPath(
              pathMetric.extractPath(distance, distance + dashWidth),
              Offset.zero,
            );
            distance += dashWidth + dashSpace;
          }
        }
        canvas.drawPath(dashPath, tracePaint);
      } else {
        canvas.drawPath(path, tracePaint);
      }
    }

    // Draw X, Y, Z, and Mag
    drawTrace(historyX, const Color(0xFFF38BA8)); // Catppuccin Red
    drawTrace(historyY, const Color(0xFFA6E3A1)); // Catppuccin Green
    drawTrace(historyZ, const Color(0xFF89B4FA)); // Catppuccin Blue
    drawTrace(historyMag, const Color(0xFFFAB387), dotted: true, thickness: 1.5); // Catppuccin Peach
  }

  @override
  bool shouldRepaint(covariant _ScopePainter oldDelegate) {
    return true;
  }
}
