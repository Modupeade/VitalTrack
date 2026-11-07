import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/measure_type.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

/// A single row tile on the Health tab / Home-tab health section.
class HealthTile extends StatelessWidget {
  const HealthTile({
    super.key,
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.titleColor,
    required this.timestamp,
    required this.value,
    required this.unit,
    required this.sub,
    required this.right,
    this.onTap,
  });

  final Color   iconBg;
  final IconData icon;
  final String  title;
  final Color   titleColor;
  final String  timestamp;
  final String  value;
  final String  unit;
  final String  sub;
  final Widget  right;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cHealthTile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(timestamp,
                        style:
                            const TextStyle(color: cGray, fontSize: 11)),
                    const Icon(Icons.chevron_right,
                        color: cDimGray, size: 14),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: value,
                                style: const TextStyle(
                                    color: cWhite,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700),
                              ),
                              if (unit.isNotEmpty)
                                TextSpan(
                                  text: ' $unit',
                                  style: const TextStyle(
                                      color: cGray,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400),
                                ),
                            ],
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Text(sub,
                              style: const TextStyle(
                                  color: cGray, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    right,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}

/// Outlined "Measure" button used on Health tiles.
class MeasureButton extends StatelessWidget {
  const MeasureButton({
    super.key,
    required this.isConnected,
    required this.type,
    required this.onMeasure,
  });

  final bool isConnected;
  final MeasureType type;
  final void Function(MeasureType) onMeasure;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isConnected ? () => onMeasure(type) : () => onMeasure(type),
      icon: const Icon(Icons.show_chart, size: 14),
      label: const Text('Measure', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: cWhite,
        disabledForegroundColor: cDimGray,
        side: BorderSide(color: isConnected ? cGray : cDimGray),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// Mini bar-chart widget (HRV, Stress).
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.color});
  final Color color;

  static const _heights = [0.4, 0.7, 0.5, 0.9, 0.6];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _heights.map((h) {
          return Container(
            width: 5,
            height: 28 * h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Sleep progress bar (purple).
class SleepProgressBar extends StatelessWidget {
  const SleepProgressBar({super.key, required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Container(color: const Color(0xFF2A2A2A)),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: cPurple),
            ),
          ],
        ),
      ),
    );
  }
}
