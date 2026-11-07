import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/components/glass_card.dart';
import 'package:vitals_10/ui/devices/dashboard/components/painters.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.stepsTaken,
    required this.stepsGoal,
  });

  final int stepsTaken;
  final int stepsGoal;

  @override
  Widget build(BuildContext context) {
    final progress = (stepsTaken / stepsGoal).clamp(0.0, 1.0);
    final score    = (progress * 100).round().clamp(0, 100);
    final kcal     = (stepsTaken * 0.0306).toStringAsFixed(2);
    final km       = (stepsTaken * 0.0008).toStringAsFixed(2);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Activity',
                style: TextStyle(
                    color: cWhite, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: cGray, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 200,
              height: 110,
              child: CustomPaint(
                painter: TickGaugePainter(progress: progress.toDouble()),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        stepsTaken > 0 ? '$stepsTaken' : '--',
                        style: const TextStyle(
                          color: cWhite,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cStatBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events,
                      color: Color(0xFFD4AF37), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    stepsTaken < 3000 ? 'Too little exercise' : 'Keep going!',
                    style: const TextStyle(color: cWhite, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, color: cGray, size: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActivityStat(
                emoji: '🦶',
                value: stepsTaken > 0 ? '$stepsTaken' : '--',
                label: 'Steps',
              ),
              _ActivityStat(
                emoji: '🔥',
                value: stepsTaken > 0 ? kcal : '--',
                label: 'Kcal',
              ),
              _ActivityStat(
                emoji: '📍',
                value: stepsTaken > 0 ? km : '--',
                label: 'km',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(value,
                style: const TextStyle(
                    color: cWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        Text(label, style: const TextStyle(color: cGray, fontSize: 12)),
      ],
    );
  }
}
