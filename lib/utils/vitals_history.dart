import 'package:vitals_10/utils/dashboard_models.dart';

/// One timestamped reading from the band.
class VitalSample {
  const VitalSample(this.time, this.value);

  final DateTime time;
  final double value;
}

/// Fixed-capacity in-memory series for a single metric.
///
/// The band pushes readings continuously for as long as it stays connected, so
/// an unbounded list would grow all session. Once [capacity] is reached the
/// oldest sample drops off the front.
class VitalSeries {
  VitalSeries({this.capacity = 2880});

  /// 2880 samples is roughly 24 hours at one reading every 30 seconds.
  final int capacity;

  final List<VitalSample> _samples = <VitalSample>[];

  List<VitalSample> get samples => List.unmodifiable(_samples);

  bool get isEmpty => _samples.isEmpty;
  bool get isNotEmpty => _samples.isNotEmpty;

  double? get latest => _samples.isEmpty ? null : _samples.last.value;
  DateTime? get latestTime => _samples.isEmpty ? null : _samples.last.time;

  void add(double value, [DateTime? at]) {
    _samples.add(VitalSample(at ?? DateTime.now(), value));
    if (_samples.length > capacity) {
      _samples.removeRange(0, _samples.length - capacity);
    }
  }

  void clear() => _samples.clear();

  /// Mean of every sample recorded today, or null if there are none.
  double? get todayAverage {
    final now = DateTime.now();
    final todays = _samples
        .where((s) =>
            s.time.year == now.year &&
            s.time.month == now.month &&
            s.time.day == now.day)
        .toList();
    if (todays.isEmpty) return null;
    final total = todays.fold<double>(0, (sum, s) => sum + s.value);
    return total / todays.length;
  }

  /// Lowest reading inside [window]. Used as a resting heart rate estimate —
  /// the band doesn't report resting rate directly, and the daily minimum is
  /// the usual stand-in for it.
  double? restingEstimate({Duration window = const Duration(hours: 12)}) {
    final cutoff = DateTime.now().subtract(window);
    final recent =
        _samples.where((s) => s.time.isAfter(cutoff)).map((s) => s.value);
    if (recent.isEmpty) return null;
    return recent.reduce((a, b) => a < b ? a : b);
  }

  /// Averages bucketed to line up 1:1 with the axis labels [range] renders.
  ///
  /// Empty buckets come back as 0 so the chart draws a flat segment instead of
  /// tripping TrendSeries' values/labels length assertion.
  List<double> bucketed(TrendRange range) {
    final count = bucketCount(range);
    final sums = List<double>.filled(count, 0);
    final hits = List<int>.filled(count, 0);
    final cutoff = _cutoffFor(range);

    for (final s in _samples) {
      if (s.time.isBefore(cutoff)) continue;
      final i = _bucketIndex(s.time, range, count);
      sums[i] += s.value;
      hits[i]++;
    }

    return List<double>.generate(
      count,
      (i) => hits[i] == 0 ? 0 : sums[i] / hits[i],
    );
  }

  /// Bucket counts match the label lists in DeviceHomeDashboardScreen.
  static int bucketCount(TrendRange range) => switch (range) {
        TrendRange.day => 7, // 0, 4, 8, 12, 16, 20, 24
        TrendRange.week => 7, // Mon..Sun
        TrendRange.month => 4, // W1..W4
      };

  /// Start of the window each range covers, floored to midnight so a sample
  /// taken earlier today still lands inside the week and month windows.
  static DateTime _cutoffFor(TrendRange range) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return switch (range) {
      TrendRange.day => midnight,
      TrendRange.week => midnight.subtract(Duration(days: now.weekday - 1)),
      TrendRange.month => DateTime(now.year, now.month, 1),
    };
  }

  static int _bucketIndex(DateTime t, TrendRange range, int count) {
    final raw = switch (range) {
      TrendRange.day => t.hour ~/ 4,
      TrendRange.week => t.weekday - 1,
      TrendRange.month => (t.day - 1) ~/ 7,
    };
    return raw.clamp(0, count - 1);
  }
}
