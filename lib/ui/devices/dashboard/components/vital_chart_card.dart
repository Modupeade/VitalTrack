import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitals_10/ui/devices/dashboard/components/glass_card.dart';
import 'package:vitals_10/ui/devices/dashboard/components/painters.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class VitalChartCard extends StatelessWidget {
  const VitalChartCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.dataDate,
  });

  final String title;
  final String value;
  final String unit;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String dataDate;

  DateTime _chartDate() {
    final raw = dataDate.trim();
    if (raw.isEmpty || raw == '--') return DateTime.now();

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    for (final pattern in const [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy/MM/dd HH:mm',
    ]) {
      try {
        return DateFormat(pattern).parse(raw);
      } catch (_) {}
    }

    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (hm != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(hm.group(1)!),
        int.parse(hm.group(2)!),
      );
    }

    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final date = _chartDate();
    final cursorFraction = (date.hour + date.minute / 60) / 24.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: cWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: cGray, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: CursorChartPainter(cursorFraction: cursorFraction),
              size: const Size(double.infinity, 80),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00:00', style: TextStyle(color: cGray, fontSize: 10)),
              Text('06:00', style: TextStyle(color: cGray, fontSize: 10)),
              Text('12:00', style: TextStyle(color: cGray, fontSize: 10)),
              Text('18:00', style: TextStyle(color: cGray, fontSize: 10)),
              Text('24:00', style: TextStyle(color: cGray, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: cStatBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _StatColWithCheck(value: stat1Value, label: stat1Label),
                _VDivider(),
                _StatColWithCheck(value: stat2Value, label: stat2Label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColWithCheck extends StatelessWidget {
  const _StatColWithCheck({required this.value, required this.label});
  final String value;
  final String label;

  static const _dash = '--';

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: cWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (value != _dash) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, color: cOrange, size: 14),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: cGray, fontSize: 12)),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: cBorder);
}
