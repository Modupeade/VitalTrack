import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/components/glass_card.dart';
import 'package:vitals_10/ui/devices/dashboard/components/lalignemt_tools.dart';
import 'package:vitals_10/ui/devices/dashboard/components/painters.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class SleepCard extends StatelessWidget {
  const SleepCard({
    super.key,
    required this.readinessScore,
    required this.sleepTotalMinutes,
    required this.deepSleepMinutes,
    required this.remSleepMinutes,
    required this.awakeMinutes,
    required this.heartRateLabel,
    required this.spo2Label,
    required this.sleepDurationLabel,
  });

  final int readinessScore;
  final int sleepTotalMinutes;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int awakeMinutes;
  final String heartRateLabel;
  final String spo2Label;
  final String sleepDurationLabel;

  String get _scoreLabel {
    if (readinessScore >= 85) return 'Optimal';
    if (readinessScore >= 70) return 'Good';
    if (readinessScore >= 55) return 'Fair';
    if (readinessScore >= 40) return 'Low';
    if (readinessScore > 0)   return 'Poor';
    return '--';
  }

  Color get _accentColor {
    if (readinessScore >= 85) return const Color(0xFF2EC886);
    if (readinessScore >= 70) return const Color(0xFF00C8A0);
    if (readinessScore >= 55) return const Color(0xFFE88A30);
    if (readinessScore > 0)   return const Color(0xFFE05252);
    return const Color(0xFF8A9BA8);
  }

  IconData get _icon {
    if (readinessScore >= 70) return Icons.bolt;
    if (readinessScore >= 55) return Icons.bolt_outlined;
    if (readinessScore > 0)   return Icons.warning_amber_rounded;
    return Icons.bolt_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Heading
          Row(
            children: const [
              Text(
                'Vitality Score',
                style: TextStyle(
                  color: cWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          // Score
          Text(
            readinessScore > 0 ? '$readinessScore' : '--',
            style: TextStyle(
              color: _accentColor,
              fontSize: 52,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cStatBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, color: _accentColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  _scoreLabel,
                  style: const TextStyle(
                    color: cWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Timeline bar
          const SleepTimelineBar(),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('08:39', style: TextStyle(color: cGray, fontSize: 11)),
                Text('10:49', style: TextStyle(color: cGray, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: cStatBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                StartCol(value: sleepDurationLabel, label: 'Sleep Time'),
                VDivider(),
                StartCol(value: heartRateLabel, label: 'HR'),
                VDivider(),
                StartCol(value: spo2Label, label: 'SpO2'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
