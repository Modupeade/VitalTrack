import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

/// Dashed tick-mark semicircle gauge used on the Activity card.
class TickGaugePainter extends CustomPainter {
  const TickGaugePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const totalTicks = 32;
    const tickLen    = 10.0;
    const tickW      = 2.5;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final cx = size.width / 2;
    final cy = size.height * 0.88;
    final r  = math.min(cx, cy) - tickLen - 6;

    final activePaint = Paint()
      ..color       = Colors.white
      ..strokeWidth = tickW
      ..strokeCap   = StrokeCap.round;
    final inactivePaint = Paint()
      ..color       = const Color(0xFF334455)
      ..strokeWidth = tickW
      ..strokeCap   = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final frac  = i / (totalTicks - 1);
      final angle = startAngle + sweepAngle * frac;
      final cos_  = math.cos(angle);
      final sin_  = math.sin(angle);
      final inner = Offset(cx + (r - tickLen) * cos_, cy + (r - tickLen) * sin_);
      final outer = Offset(cx + r * cos_, cy + r * sin_);
      canvas.drawLine(inner, outer,
          frac <= progress ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(TickGaugePainter old) => old.progress != progress;
}

/// Dotted horizontal line + vertical white cursor bar for the HR / SpO2 chart.
class CursorChartPainter extends CustomPainter {
  const CursorChartPainter({required this.cursorFraction});
  final double cursorFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color       = const Color(0xFF445566)
      ..strokeWidth = 1;

    final lineY = size.height * 0.55;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, lineY), Offset(x + 4, lineY), dotPaint);
      x += 8;
    }

    final cx = size.width * cursorFraction.clamp(0.05, 0.95);
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, lineY - 1),
      Paint()
        ..color       = Colors.white.withOpacity(0.85)
        ..strokeWidth = 3
        ..strokeCap   = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, lineY), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(CursorChartPainter old) =>
      old.cursorFraction != cursorFraction;
}

/// Mini scatter/dot chart for Temp Trend.
class DotChartPainter extends CustomPainter {
  const DotChartPainter({required this.points, required this.color});
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint     = Paint()..color = color;
    final linePaint = Paint()
      ..color       = color.withOpacity(0.4)
      ..strokeWidth = 1;
    final step = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - points[i] * size.height;
      canvas.drawCircle(Offset(x, y), 2.5, paint);
      if (i < points.length - 1) {
        canvas.drawLine(
          Offset(x, y),
          Offset((i + 1) * step, size.height - points[i + 1] * size.height),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DotChartPainter old) => old.points != points;
}

/// Rounded pill sleep-timeline bar with white segment dividers.
class SleepTimelineBar extends StatelessWidget {
  const SleepTimelineBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              color: const Color(0xFF607D8B),
              child: Row(
                children: List.generate(5, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 1.5),
                    color: i.isEven
                        ? const Color(0xFF78909C)
                        : const Color(0xFF90A4AE),
                  ),
                )),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 60),
              ...List.generate(3, (_) => [
                Container(width: 2, height: 22, color: Colors.white),
                const Spacer(),
              ]).expand((e) => e),
              const SizedBox(width: 20),
            ],
          ),
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
