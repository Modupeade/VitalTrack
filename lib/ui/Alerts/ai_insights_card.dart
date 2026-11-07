import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/services/ai_health_service.dart';
import 'package:vitals_10/ui/Alerts/ai_health_insights_screen.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';
import 'package:vitals_10/utils/constants.dart';

class AiInsightsCard extends StatefulWidget {
  final DateTimeRange dateRange;

  const AiInsightsCard({super.key, required this.dateRange});

  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<AiInsightsCard>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _askNow() async {
    if (_loading) return;
    setState(() => _loading = true);
    _progress
      ..value = 0
      ..animateTo(0.9, duration: const Duration(seconds: 14), curve: Curves.easeOut);
    try {
      final ble = context.read<BluetoothScanModel>();
      if (ble.isConnected) {
        await ble.syncStoredHistory(
          timeout: const Duration(seconds: 10),
        );
      }

      final wearable = ble.liveSnapshot();
      final rangeStart = DateTime(
        widget.dateRange.start.year,
        widget.dateRange.start.month,
        widget.dateRange.start.day,
      );
      final rangeEnd = DateTime(
        widget.dateRange.end.year,
        widget.dateRange.end.month,
        widget.dateRange.end.day,
        23,
        59,
        59,
        999,
      );

      final ctx = await AiHealthService.gatherContext(
        dateRange: widget.dateRange,
        wearableSnapshot: wearable,
        sessionDeviceReadings: ble.sessionReadingsInRange(
          start: rangeStart,
          end: rangeEnd,
        ),
      );
      final report = await AiHealthService.generateReport(ctx);
      if (!mounted) return;
      await _progress.animateTo(1, duration: const Duration(milliseconds: 350));
      if (!mounted) return;
      NavigationHelper.navPush(
        context,
        AiHealthInsightsScreen(contextData: ctx, report: report),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        _progress.stop();
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      shadowColor: Colors.grey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Get AI-based health insights\nfrom your own data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            16.height,
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.memory, size: 36),
                  Text(
                    'AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            16.height,
            if (_loading)
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final percent = (_progress.value * 100).round();
                  return Column(
                    children: [
                      _ChevronProgressBar(progress: _progress.value),
                      10.height,
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Analyzing your data...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _askNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff00b048),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Ask Now!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChevronProgressBar extends StatelessWidget {
  const _ChevronProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChevronProgressPainter(progress.clamp(0.0, 1.0)),
      ),
    );
  }
}

class _ChevronProgressPainter extends CustomPainter {
  _ChevronProgressPainter(this.progress);

  final double progress;
  static const int _segments = 12;

  @override
  void paint(Canvas canvas, Size size) {
    const tip = 10.0;
    final segmentWidth = (size.width + tip) / _segments;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFE9E9E9));

    for (var i = 0; i < _segments; i++) {
      final start = i / _segments;
      final end = (i + 1) / _segments;
      if (progress <= start) continue;

      final left = i * segmentWidth - tip;
      final right = left + segmentWidth;
      final path = Path()
        ..moveTo(left, 0)
        ..lineTo(right - tip, 0)
        ..lineTo(right, size.height / 2)
        ..lineTo(right - tip, size.height)
        ..lineTo(left, size.height)
        ..lineTo(left + tip, size.height / 2)
        ..close();

      final fill = progress >= end
          ? 1.0
          : ((progress - start) / (end - start)).clamp(0.0, 1.0);
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(
          const Color(0xFFE9E9E9),
          const Color(0xff4caf50),
          fill,
        )!,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChevronProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
