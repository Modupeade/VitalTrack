import 'package:flutter/material.dart';

import 'dashboard_theme.dart';

/// Battery / date stepper / profile row at the top of every tab.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
    this.onPickDate,
    this.onProfile,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPickDate;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.battery_full, color: Color(0xFF3DBE6B), size: 22),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left, size: 26),
                  color: AppColors.textMuted,
                  tooltip: 'Previous day',
                ),
                GestureDetector(
                  onTap: onPickDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D222A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: AppColors.textPrimary),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right, size: 26),
                  color: AppColors.textMuted,
                  tooltip: 'Next day',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onProfile,
            icon: const Icon(Icons.person_outline, size: 24),
            color: AppColors.textPrimary,
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// OVERVIEW / SLEEP / TRENDS pill selector.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141920),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: active ? AppColors.background : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class EditButton extends StatelessWidget {
  const EditButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.edit_outlined, size: 20),
      color: AppColors.textMuted,
      tooltip: 'Edit layout',
    );
  }
}

/// Rounded dark panel used for CORE METRICS, SLEEP METRICS and trend charts.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: child,
    );
  }
}

class UpdatedStamp extends StatelessWidget {
  const UpdatedStamp({super.key, required this.time, this.centered = false});

  final String time;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final text = Text('Updated $time', style: AppText.updated);
    return centered ? Center(child: text) : text;
  }
}

/// Floating white tab bar.
class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <(IconData, String)>[
    (Icons.home, 'Home'),
    (Icons.description_outlined, 'Updates'),
    (Icons.medical_services_outlined, 'Medicine'),
    (Icons.monitor_heart_outlined, 'Vitals'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == index;
            final color =
                active ? AppColors.navActive : const Color(0xFF5A6270);
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_items[i].$1, size: 22, color: color),
                    const SizedBox(height: 4),
                    Text(
                      _items[i].$2,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}