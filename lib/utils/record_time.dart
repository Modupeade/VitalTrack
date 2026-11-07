import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Resolves the actual measurement time from mixed Firestore / band fields.
///
/// Device dumps from 2025 were showing up in "last 30 days" because we used
/// save-time (`addedTime`) or [DateTime.now] when the real date failed to parse.
class RecordTime {
  RecordTime._();

  static const _formats = [
    'dd/MM/yyyy HH:mm:ss',
    'dd/MM/yyyy HH:mm',
    'dd/MM/yyyy',
    'dd.MM.yyyy HH:mm:ss',
    'dd.MM.yyyy HH:mm',
    'dd.MM.yyyy',
    'yyyy.MM.dd HH:mm:ss',
    'yyyy.MM.dd HH:mm',
    'yyyy.MM.dd',
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd',
    'yyyyMMddHHmmss',
    'yyyyMMdd',
  ];

  static DateTime? parse(Object? raw) {
    if (raw == null) return null;

    final fromEpoch = toDateTime(raw);
    if (fromEpoch != null) return fromEpoch;

    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null' || text == '0') return null;

    final candidates = <String>{
      text,
      text.replaceAll('.', '/'),
      text.replaceAll('/', '-'),
      text.replaceAll('-', '.'),
    };
    for (final source in candidates) {
      for (final pattern in _formats) {
        try {
          final parsed = DateFormat(pattern).parseStrict(source);
          if (parsed.year >= 2020 && parsed.year <= 2100) return parsed;
        } catch (_) {}
      }
    }
    final iso = DateTime.tryParse(text);
    if (iso != null && iso.year >= 2020 && iso.year <= 2100) return iso;
    return null;
  }

  static DateTime? toDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is num) {
      final compact = _compactDate(raw.round());
      if (compact != null) return compact;
      final ms = _epochMs(raw);
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final asInt = int.tryParse(raw.toString());
    if (asInt != null) {
      final ms = _epochMs(asInt);
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return null;
  }

  static int? toEpochMs(Object? raw) => toDateTime(raw)?.millisecondsSinceEpoch;

  /// Prefer the measurement stamp (`time` / `date`) over when it was saved.
  static int? resolve({
    Object? time,
    Object? date,
    Object? addedTime,
    Object? measuredAt,
  }) {
    return toEpochMs(time) ??
        parse(time)?.millisecondsSinceEpoch ??
        toEpochMs(date) ??
        parse(date)?.millisecondsSinceEpoch ??
        toEpochMs(measuredAt) ??
        parse(measuredAt)?.millisecondsSinceEpoch ??
        toEpochMs(addedTime);
  }

  static const metricTimeKeys = [
    'heartRateTime',
    'oxygenLevelTime',
    'temperatureTime',
    'exerciseTime',
    'sleepTime',
    'stepsTime',
    'stepsTakenTime',
    'caloriesTime',
    'distanceTime',
  ];

  static int? resolveMap(Map<String, dynamic> data) {
    Object? firstMetricTime;
    for (final key in metricTimeKeys) {
      if (data[key] != null) {
        firstMetricTime = data[key];
        break;
      }
    }
    if (firstMetricTime == null) {
      data.forEach((key, value) {
        if (firstMetricTime != null || value == null) return;
        if (key.toString().toLowerCase().endsWith('time')) {
          firstMetricTime = value;
        }
      });
    }
    return resolve(
      time: data['time'] ??
          data['timestamp'] ??
          data['ts'] ??
          data['datetime'] ??
          data['dateTime'] ??
          data['readingTime'] ??
          firstMetricTime,
      date: data['date'] ?? data['day'] ?? data['recordDate'],
      measuredAt: data['measuredAt'] ??
          data['deviceDate'] ??
          data['recordedAt'] ??
          data['readingAt'],
      addedTime: data['addedTime'] ??
          data['createdAt'] ??
          data['created_at'] ??
          data['updatedAt'] ??
          data['serverTime'],
    );
  }

  static bool isInRange(DateTimeRange range, int? ms) {
    if (ms == null || ms <= 0) return false;
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    return ms >= start.millisecondsSinceEpoch && ms <= end.millisecondsSinceEpoch;
  }

  static String formatRange(DateTimeRange range) {
    final start = range.start;
    final end = range.end;
    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  static int? _epochMs(num value) {
    final n = value.round();
    // Unix seconds from 2001 are 10 digits. Shorter numbers are dates like 20250915.
    if (n < 1000000000) return null;
    if (n < 100000000000) return n * 1000;
    return n;
  }

  /// Wearable dumps often store the calendar day as 20260920.
  static DateTime? _compactDate(int n) {
    if (n >= 20200101 && n <= 21001231) {
      try {
        return DateFormat('yyyyMMdd').parseStrict(n.toString());
      } catch (_) {
        return null;
      }
    }
    if (n >= 20200101000000 && n <= 21001231235959) {
      try {
        return DateFormat('yyyyMMddHHmmss').parseStrict(n.toString());
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
