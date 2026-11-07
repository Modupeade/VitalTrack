// lib/utils/sleep_calc.dart
//
// Decodes the band's sleep history (dataType 26) according to the
// manufacturer's spec, and turns it into per-record and per-day totals.
//
// Pure Dart: no Flutter, BLE or Firebase imports, so it can be unit tested.
//
// Packet shape (one record per packet, sent one after the other):
//   {dataEnd: false, dataType: 26, dicData: [{date: 2026-10-08 21:59:01,
//     sleepUnitLength: 1, arraySleepQuality: 30 2 2 2 ... 1 1 1 }]}
//   {dataEnd: true,  dataType: 26, dicData: []}
//
// - date               start of the record
// - sleepUnitLength=1  each value is one minute: 1 deep, 2 light, 3 REM,
//                      anything else awake
// - sleepUnitLength=5  each value covers five minutes; value / 5 gives
//                      0..2 deep, >2..8 light, >8..20 REM, else awake

enum SleepStage { deep, light, rem, awake }

class SleepCalc {
  SleepCalc._();

  /// A night's sleep crosses midnight. Every timestamp is shifted forward by
  /// this much before its date is taken, so sleep from 18:00 onwards counts
  /// toward the next morning and one night lands on one day.
  /// Set to Duration.zero for plain calendar days.
  static const Duration dayShift = Duration(hours: 6);

  static SleepStage stageOf(int raw, int unitLength) {
    if (unitLength == 5) {
      final v = raw / 5;
      if (v >= 0 && v <= 2) return SleepStage.deep;
      if (v > 2 && v <= 8) return SleepStage.light;
      if (v > 8 && v <= 20) return SleepStage.rem;
      return SleepStage.awake;
    }
    switch (raw) {
      case 1:
        return SleepStage.deep;
      case 2:
        return SleepStage.light;
      case 3:
        return SleepStage.rem;
      default:
        return SleepStage.awake;
    }
  }

  // Accepts 2026-10-08 21:59:01, 2026.10.08 21:59:01, 2026/10/08 21:59,
  // ISO strings, and stray quotes/whitespace/null bytes around them.
  static final RegExp _dateRe = RegExp(
      r'(\d{4})[-./](\d{1,2})[-./](\d{1,2})[ T]+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?');

  static DateTime? parseDeviceDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final m = _dateRe.firstMatch(raw.toString());
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  static List<int> parseValues(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e is num ? e.toInt() : int.tryParse(e.toString().trim()))
          .whereType<int>()
          .toList();
    }
    return raw
        .toString()
        .split(RegExp(r'[\s,]+'))
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// yyyy-MM-dd — the format daily_sleep / daily_steps use for `date`.
  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';

  /// The day a moment of sleep belongs to (see [dayShift]).
  static String sleepDayKey(DateTime t) => dayKey(t.add(dayShift));

  /// yyyyMMddHHmm — identifies a record by its start minute.
  static String minuteKey(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}';
}

/// Minute counts per stage.
class SleepTotals {
  int deep = 0;
  int light = 0;
  int rem = 0;
  int awake = 0;

  void add(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        deep++;
        break;
      case SleepStage.light:
        light++;
        break;
      case SleepStage.rem:
        rem++;
        break;
      case SleepStage.awake:
        awake++;
        break;
    }
  }

  /// Time actually asleep: deep + light + REM. Awake is not sleep.
  int get sleep => deep + light + rem;

  /// Everything the band recorded, awake included.
  int get recorded => sleep + awake;

  /// Field names match what the app already stores and reads.
  /// All values are minutes.
  Map<String, dynamic> toMap() => {
        'sleepTime': sleep,
        'deepSleepTime': deep,
        'lightSleepTime': light,
        'remSleepTime': rem,
        'awakeTime': awake,
        'recordedTime': recorded,
      };

  @override
  String toString() =>
      'sleep ${sleep}m (deep $deep, light $light, REM $rem, awake $awake)';
}

/// One record from dicData.
class SleepRecord {
  SleepRecord({
    required DateTime start,
    required this.unitLength,
    required List<int> values,
  })  : start = DateTime(
            start.year, start.month, start.day, start.hour, start.minute),
        values = List.unmodifiable(values);

  /// Start, truncated to the minute.
  final DateTime start;

  /// 1 or 5 minutes per value.
  final int unitLength;
  final List<int> values;

  String get id => SleepCalc.minuteKey(start);
  int get recordedMinutes => values.length * unitLength;
  DateTime get end => start.add(Duration(minutes: recordedMinutes));

  /// The whole record is filed under the day its start belongs to.
  String get sleepDay => SleepCalc.sleepDayKey(start);

  /// One entry per minute: value i starts at start + i * unitLength minutes.
  Iterable<MapEntry<DateTime, SleepStage>> minutes() sync* {
    var t = start;
    for (final v in values) {
      final stage = SleepCalc.stageOf(v, unitLength);
      for (var i = 0; i < unitLength; i++) {
        yield MapEntry(t, stage);
        t = t.add(const Duration(minutes: 1));
      }
    }
  }

  SleepTotals get totals {
    final t = SleepTotals();
    for (final m in minutes()) {
      t.add(m.value);
    }
    return t;
  }

  /// From one dicData entry. Returns null if the date or values are missing.
  static SleepRecord? fromDevice(Map entry, {Object? valuesKey}) {
    final start = SleepCalc.parseDeviceDate(entry['date']);
    if (start == null) return null;
    final values = SleepCalc.parseValues(
        (valuesKey != null ? entry[valuesKey] : null) ??
            entry['arraySleepQuality']);
    if (values.isEmpty) return null;
    final unit =
        int.tryParse(entry['sleepUnitLength']?.toString().trim() ?? '') ?? 1;
    return SleepRecord(
        start: start, unitLength: unit == 5 ? 5 : 1, values: values);
  }

  /// From a sleep_logs document written by [toFirestore].
  static SleepRecord? fromFirestore(Map<String, dynamic> data) {
    final start = SleepCalc.parseDeviceDate(data['date']);
    final values = SleepCalc.parseValues(data['values']);
    if (start == null || values.isEmpty) return null;
    final unit = (data['sleepUnitLength'] as num?)?.toInt() ?? 1;
    return SleepRecord(
        start: start, unitLength: unit == 5 ? 5 : 1, values: values);
  }

  /// A sleep_logs document. The raw values are kept so a day can be
  /// rebuilt from stored records without double counting.
  Map<String, dynamic> toFirestore(String userId) => {
        'userId': userId,
        'date': start.toIso8601String(),
        'endDate': end.toIso8601String(),
        'sleepDay': sleepDay,
        'sleepUnitLength': unitLength,
        'values': values,
        ...totals.toMap(),
      };
}

/// All the sleep filed under one day.
class SleepDay {
  SleepDay._(this.day, this.totals, this.records);

  /// yyyy-MM-dd
  final String day;
  final SleepTotals totals;

  /// Sorted by start.
  final List<SleepRecord> records;

  DateTime? get start => records.isEmpty ? null : records.first.start;
  DateTime? get end => records.isEmpty
      ? null
      : records.map((r) => r.end).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Counts every minute once. When records overlap (the band often starts
  /// the next record a minute before the previous one ends), the earlier
  /// record's reading for that minute is the one kept.
  factory SleepDay.build(String day, Iterable<SleepRecord> records) {
    final byId = <String, SleepRecord>{};
    for (final r in records) {
      byId.putIfAbsent(r.id, () => r);
    }
    final sorted = byId.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final seen = <DateTime>{};
    final totals = SleepTotals();
    for (final r in sorted) {
      for (final m in r.minutes()) {
        if (seen.add(m.key)) totals.add(m.value);
      }
    }
    return SleepDay._(day, totals, sorted);
  }

  /// A daily_sleep document.
  Map<String, dynamic> toFirestore(String userId) => {
        'userId': userId,
        'date': day,
        ...totals.toMap(),
        'records': records.length,
        if (start != null) 'sleepStart': start!.toIso8601String(),
        if (end != null) 'sleepEnd': end!.toIso8601String(),
      };
}