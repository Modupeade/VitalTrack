// lib/utils/readiness_calc.dart
//
// Ports the Python rolling-28-day Readiness Index to Dart.
// Pure Dart — no Flutter or Firebase imports.
//
// Algorithm (exact translation):
//   Norm_HRV   = (hrv  - min28) / (max28 - min28)   × 100  (higher = better)
//   Norm_RHR   = (max28 - rhr)  / (max28 - min28)   × 100  (lower  = better)
//   Norm_Sleep = min(100, sleepHours / 8 × 100)
//   Norm_Load  = (max28 - load) / (max28 - min28)   × 100  (lower  = better)
//   Score      = 0.40·HRV + 0.20·RHR + 0.25·Sleep + 0.15·Load
//
// If the window has fewer than 28 samples, or if a metric is flat (max == min),
// that component falls back to 50 — matching the Python fillna(50).

import 'dart:math' as math;

class ReadinessSample {
  const ReadinessSample({
    required this.hrv,
    required this.rhr,
    required this.sleepHours,
    required this.dailyLoad,
  });

  final int    hrv;        // ms (RMSSD/SDNN)
  final int    rhr;        // bpm
  final double sleepHours; // hours
  final double dailyLoad;  // calories (or any energy-expenditure proxy)
}

class ReadinessCalc {
  ReadinessCalc._();

  static const int    _kWindow      = 28;
  static const double _kSleepTarget = 8.0;

  // Weights must sum to 1.0
  static const double _wHrv   = 0.40;
  static const double _wRhr   = 0.20;
  static const double _wSleep = 0.25;
  static const double _wLoad  = 0.15;

  /// Returns a 0–100 Readiness Index for the most recent entry in [history].
  ///
  /// [history] must be sorted oldest-first; pass at most [_kWindow] entries
  /// (the last 28 days).  Returns 0 when the list is empty.
  static double calculate(List<ReadinessSample> history) {
    if (history.isEmpty) return 0;
    final latest = history.last;

    final hrvVals  = history.map((s) => s.hrv.toDouble()).toList();
    final rhrVals  = history.map((s) => s.rhr.toDouble()).toList();
    final loadVals = history.map((s) => s.dailyLoad).toList();

    final normHrv   = _higherBetter(latest.hrv.toDouble(),  hrvVals);
    final normRhr   = _lowerBetter( latest.rhr.toDouble(),  rhrVals);
    final normSleep = math.min(100.0, (latest.sleepHours / _kSleepTarget) * 100.0);
    final normLoad  = _lowerBetter( latest.dailyLoad,       loadVals);

    return (normHrv   * _wHrv)  +
           (normRhr   * _wRhr)  +
           (normSleep * _wSleep) +
           (normLoad  * _wLoad);
  }

  // ── private helpers ────────────────────────────────────────────────────────

  static double _higherBetter(double value, List<double> window) {
    if (window.length < _kWindow) return 50.0;
    final mn = window.reduce(math.min);
    final mx = window.reduce(math.max);
    if (mx == mn) return 50.0;
    return ((value - mn) / (mx - mn)) * 100.0;
  }

  static double _lowerBetter(double value, List<double> window) {
    if (window.length < _kWindow) return 50.0;
    final mn = window.reduce(math.min);
    final mx = window.reduce(math.max);
    if (mx == mn) return 50.0;
    return ((mx - value) / (mx - mn)) * 100.0;
  }
}
