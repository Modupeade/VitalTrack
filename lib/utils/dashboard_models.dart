import 'package:flutter/material.dart';

/// A tile on the Overview tab.
class Metric {
  const Metric({
    required this.title,
    required this.value,
    required this.unit,
    this.caption,
    this.gaugeValue,
  });

  final String title;

  /// Formatted reading, or "--" when nothing has been recorded yet.
  final String value;
  final String unit;

  /// Zone name ("LIGHT") or "NO DATA".
  final String? caption;

  /// 0..1 needle position. Null hides the needle and dims the tile.
  final double? gaugeValue;

  bool get hasValue => gaugeValue != null;
}

/// A row on the Sleep tab.
class SleepMetric {
  const SleepMetric({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;

  /// Formatted duration, or "--".
  final String value;
}

/// Time window for the Trends tab.
enum TrendRange {
  day('D'),
  week('W'),
  month('M');

  const TrendRange(this.label);
  final String label;
}

/// One chart on the Trends tab.
class TrendSeries {
  const TrendSeries({
    required this.title,
    required this.icon,
    required this.color,
    required this.values,
    required this.labels,
  }) : assert(values.length == labels.length,
            'values and labels must line up 1:1');

  final String title;
  final IconData icon;
  final Color color;

  /// Y values, one per x label.
  final List<double> values;

  /// X axis labels — days of week, hours, or dates depending on the range.
  final List<String> labels;
}