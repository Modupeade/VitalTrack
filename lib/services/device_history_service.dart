import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitals_10/utils/record_time.dart';

/// One timestamped reading pulled off the band (HRV packet, daily steps, etc.).
class DeviceReading {
  const DeviceReading({
    required this.type,
    required this.time,
    this.date,
    this.heartRate,
    this.hrv,
    this.sys,
    this.dia,
    this.stress,
    this.spo2,
    this.steps,
    this.calories,
    this.distance,
    this.sleepMinutes,
    this.temperature,
    this.bloodSugar,
  });

  final String type;
  final int time;
  final String? date;
  final int? heartRate;
  final int? hrv;
  final int? sys;
  final int? dia;
  final int? stress;
  final int? spo2;
  final int? steps;
  final double? calories;
  final double? distance;
  final int? sleepMinutes;
  final double? temperature;
  final double? bloodSugar;

  String get id =>
      '${type}_${time}_${heartRate ?? 0}_${spo2 ?? 0}_${steps ?? 0}_${sleepMinutes ?? 0}';

  bool get hasUsefulValue =>
      (heartRate ?? 0) > 0 ||
      (hrv ?? 0) > 0 ||
      (sys ?? 0) > 0 ||
      (dia ?? 0) > 0 ||
      (spo2 ?? 0) > 0 ||
      (steps ?? 0) > 0 ||
      (sleepMinutes ?? 0) > 0 ||
      (temperature ?? 0) > 0 ||
      (bloodSugar ?? 0) > 0 ||
      (stress ?? 0) > 0 ||
      (calories ?? 0) > 0;

  Map<String, dynamic> toMap(String uid) {
    return {
      'uid': uid,
      'type': type,
      'time': time,
      if (date != null) 'date': date,
      if (heartRate != null) 'heartRate': heartRate,
      if (hrv != null) 'hrv': hrv,
      if (sys != null) 'sys': sys,
      if (dia != null) 'dia': dia,
      if (stress != null) 'stress': stress,
      if (spo2 != null) 'spo2': spo2,
      if (steps != null) 'steps': steps,
      if (calories != null) 'calories': calories,
      if (distance != null) 'distance': distance,
      if (sleepMinutes != null) 'sleepMinutes': sleepMinutes,
      if (temperature != null) 'temperature': temperature,
      if (bloodSugar != null) 'bloodSugar': bloodSugar,
      'source': 'device',
    };
  }

  factory DeviceReading.fromMap(Map<String, dynamic> data, {String? docId}) {
    final n = _DeviceVitalsFields.normalize(data);
    var time = RecordTime.resolveMap(n) ?? RecordTime.resolveMap(data) ?? 0;
    if (time <= 0) {
      time = _DeviceVitalsFields.timeFromDocId(docId) ?? 0;
    }
    return DeviceReading(
      type: (n['type'] ?? 'device').toString(),
      time: time,
      date: n['date']?.toString() ??
          (_DeviceVitalsFields.timeFromDocId(docId) != null ? docId : null),
      heartRate: (n['heartRate'] as num?)?.toInt(),
      hrv: (n['hrv'] as num?)?.toInt(),
      sys: (n['sys'] as num?)?.toInt(),
      dia: (n['dia'] as num?)?.toInt(),
      stress: (n['stress'] as num?)?.toInt(),
      spo2: (n['spo2'] as num?)?.toInt(),
      steps: (n['steps'] as num?)?.toInt(),
      calories: (n['calories'] as num?)?.toDouble(),
      distance: (n['distance'] as num?)?.toDouble(),
      sleepMinutes: (n['sleepMinutes'] as num?)?.toInt(),
      temperature: (n['temperature'] as num?)?.toDouble(),
      bloodSugar: (n['bloodSugar'] as num?)?.toDouble(),
    );
  }

  /// One Firestore doc in [my_device_vitals] may be a snapshot or a list.
  static List<DeviceReading> fromClientDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    final readings = _DeviceVitalsFields.splitClientSnapshot(docId, data);
    if (readings.isNotEmpty) return readings;

    for (final map in _DeviceVitalsFields.flatten(data)) {
      final reading = DeviceReading.fromMap(map, docId: docId);
      if (reading.time <= 0 || !reading.hasUsefulValue) continue;
      readings.add(reading);
    }
    if (readings.isEmpty) {
      debugPrint(
        'my_device_vitals skipped $docId (no dated vital fields) '
        'times=${_DeviceVitalsFields.sampleTimes(data)}',
      );
    }
    return readings;
  }
}

/// Stores band history so the 30-day AI report can use it after the session ends.
class DeviceHistoryService {
  static final Map<String, DeviceReading> _cache = {};

  static const _clientCollection = 'my_device_vitals';

  static CollectionReference<Map<String, dynamic>> get _col {
    return FirebaseFirestore.instance.collection('deviceHistory');
  }

  static CollectionReference<Map<String, dynamic>> get _clientCol {
    return FirebaseFirestore.instance.collection(_clientCollection);
  }

  static DateTime? parseDeviceTime(String? raw) => RecordTime.parse(raw);

  static Future<void> persist(List<DeviceReading> readings) async {
    final useful = readings.where((r) => r.hasUsefulValue).toList();
    if (useful.isEmpty) return;

    for (final reading in useful) {
      _cache[reading.id] = reading;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      const chunk = 400;
      for (var i = 0; i < useful.length; i += chunk) {
        final slice = useful.sublist(
          i,
          i + chunk > useful.length ? useful.length : i + chunk,
        );
        final batch = FirebaseFirestore.instance.batch();
        for (final reading in slice) {
          batch.set(
            _col.doc('${uid}_${reading.id}'),
            reading.toMap(uid),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('device history persist failed: $e');
    }
  }

  static Future<DeviceHistoryQuery> queryForRange(DateTimeRange range) async {
    final merged = <String, DeviceReading>{};
    for (final reading in _cache.values) {
      merged[reading.id] = reading;
    }

    final rawDocs = <String, Map<String, dynamic>>{};
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await Future.wait([
        _mergeLegacyHistory(merged, uid),
        _mergeClientVitals(merged, rawDocs, uid),
      ]);
    }

    final inRange = <DeviceReading>[];
    var excluded = 0;
    for (final reading in merged.values) {
      if (RecordTime.isInRange(range, reading.time)) {
        inRange.add(reading);
      } else if (reading.time > 0) {
        excluded++;
      }
    }
    inRange.sort((a, b) => b.time.compareTo(a.time));

    final myDeviceVitals = <Map<String, dynamic>>[];
    var rawInRange = 0;
    var rawExcluded = 0;
    var rawUndated = 0;
    for (final entry in rawDocs.entries) {
      if (_rawDocInRange(range, entry.key, entry.value)) {
        rawInRange++;
        if (myDeviceVitals.length < 80) {
          myDeviceVitals.add({
            'id': entry.key,
            ...entry.value,
          });
        }
      } else if (_rawDocHasDate(entry.key, entry.value)) {
        rawExcluded++;
      } else {
        rawUndated++;
      }
    }

    debugPrint(
      'device analysis: ${inRange.length} mapped in period, $excluded outside; '
      'my_device_vitals docs ${myDeviceVitals.length} in period, '
      '$rawExcluded outside, $rawUndated undated',
    );
    return DeviceHistoryQuery(
      inRange: inRange,
      excludedOutsidePeriod: excluded,
      range: range,
      myDeviceVitals: myDeviceVitals,
      myDeviceVitalsInPeriod: rawInRange,
      myDeviceVitalsExcluded: rawExcluded,
      myDeviceVitalsUndated: rawUndated,
    );
  }

  static Future<void> _mergeLegacyHistory(
    Map<String, DeviceReading> merged,
    String uid,
  ) async {
    try {
      final snapshot =
          await _col.where('uid', isEqualTo: uid).limit(2500).get();
      for (final doc in snapshot.docs) {
        final reading = DeviceReading.fromMap(doc.data());
        if (reading.time > 0) merged[reading.id] = reading;
      }
    } catch (e) {
      debugPrint('deviceHistory fetch failed: $e');
    }
  }

  /// Client wearable store: top-level [my_device_vitals] and
  /// users/{uid}/my_device_vitals.
  static const _ownerFields = [
    'uid',
    'userId',
    'user_id',
    'userUID',
    'ownerId',
    'patientId',
  ];

  static Future<void> _mergeClientVitals(
    Map<String, DeviceReading> merged,
    Map<String, Map<String, dynamic>> rawDocs,
    String uid,
  ) async {
    final email = FirebaseAuth.instance.currentUser?.email;

    void takeDoc(String id, Map<String, dynamic> data) {
      rawDocs[id] = _jsonSafe(data);
      for (final reading in DeviceReading.fromClientDoc(id, data)) {
        merged[reading.id] = reading;
      }
    }

    Future<void> ingest(
      QuerySnapshot<Map<String, dynamic>> snap,
      String label,
    ) async {
      for (final doc in snap.docs) {
        takeDoc(doc.id, doc.data());
      }
      debugPrint(
        'my_device_vitals $label: ${snap.docs.length} docs',
      );
    }

    Future<void> tryQuery(
      Query<Map<String, dynamic>> query,
      String label,
    ) async {
      try {
        await ingest(await query.limit(2500).get(), label);
      } catch (e) {
        debugPrint('my_device_vitals $label failed: $e');
      }
    }

    final lookups = <Future<void>>[
      for (final field in _ownerFields)
        tryQuery(_clientCol.where(field, isEqualTo: uid), field),
      tryQuery(
        _clientCol
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: uid)
            .where(FieldPath.documentId, isLessThan: '$uid\uf8ff'),
        'docId prefix',
      ),
      tryQuery(
        _clientCol.where(
          'user',
          isEqualTo: FirebaseFirestore.instance.collection('users').doc(uid),
        ),
        'user ref',
      ),
    ];

    if (email != null && email.isNotEmpty) {
      lookups.add(tryQuery(_clientCol.where('email', isEqualTo: email), 'email'));
      lookups.add(
        tryQuery(_clientCol.where('userEmail', isEqualTo: email), 'userEmail'),
      );
    }

    lookups.add(() async {
      try {
        final sub = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection(_clientCollection)
            .limit(2500)
            .get();
        await ingest(sub, 'users/$uid/$_clientCollection');
      } catch (e) {
        debugPrint('my_device_vitals subcollection failed: $e');
      }
    }());

    for (final child in const ['vitals', 'readings', 'history', 'data']) {
      lookups.add(() async {
        try {
          final sub = await _clientCol.doc(uid).collection(child).limit(2500).get();
          await ingest(sub, '$_clientCollection/$uid/$child');
        } catch (e) {
          debugPrint('my_device_vitals $child failed: $e');
        }
      }());
    }

    await Future.wait(lookups);

    if (rawDocs.isEmpty) {
      try {
        final doc = await _clientCol.doc(uid).get();
        if (doc.exists && doc.data() != null) {
          takeDoc(doc.id, doc.data()!);
          debugPrint('my_device_vitals doc($uid): 1 doc');
        }
      } catch (e) {
        debugPrint('my_device_vitals doc($uid) failed: $e');
      }
    }

    // No collection-group index needed. If rules already limit reads to this
    // user, an unfiltered get returns only their wearable docs.
    if (rawDocs.isEmpty) {
      try {
        final snap = await _clientCol.limit(2500).get();
        if (snap.docs.isEmpty) {
          debugPrint(
            'my_device_vitals: collection is readable but empty for this account',
          );
        } else {
          debugPrint(
            'my_device_vitals readable: ${snap.docs.length} docs, '
            'sample keys=${snap.docs.first.data().keys.toList()}',
          );
          var matched = 0;
          for (final doc in snap.docs) {
            if (_belongsToUser(doc.id, doc.data(), uid, email)) {
              takeDoc(doc.id, doc.data());
              matched++;
            }
          }
          if (matched == 0 &&
              snap.docs.every(
                (doc) => !_claimsOtherUser(doc.data(), uid, email),
              )) {
            for (final doc in snap.docs) {
              takeDoc(doc.id, doc.data());
            }
            debugPrint(
              'my_device_vitals took ${snap.docs.length} rule-scoped docs',
            );
          } else if (matched == 0) {
            debugPrint(
              'my_device_vitals readable docs belong to other users; none match $uid',
            );
          }
        }
      } catch (e) {
        debugPrint('my_device_vitals readable fetch failed: $e');
      }
    }
  }

  static bool _belongsToUser(
    String docId,
    Map<String, dynamic> data,
    String uid,
    String? email,
  ) {
    if (docId == uid || docId.startsWith('${uid}_')) return true;
    bool hit(dynamic value) {
      if (value == null) return false;
      if (value is DocumentReference) {
        return value.id == uid || value.path.endsWith('/$uid');
      }
      if (value is Map) {
        return value.values.any(hit);
      }
      if (value is List) return value.any(hit);
      final text = value.toString();
      return text == uid || (email != null && email.isNotEmpty && text == email);
    }

    return data.values.any(hit);
  }

  static bool _claimsOtherUser(
    Map<String, dynamic> data,
    String uid,
    String? email,
  ) {
    for (final field in [..._ownerFields, 'email', 'userEmail']) {
      final value = data[field];
      if (value == null) continue;
      final text = value.toString();
      if (text.isEmpty) continue;
      if (text == uid) continue;
      if (email != null && text == email) continue;
      return true;
    }
    return false;
  }

  static bool _rawDocInRange(
    DateTimeRange range,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _DeviceVitalsFields
        .allTimes(docId, data)
        .any((ms) => RecordTime.isInRange(range, ms));
  }

  static bool _rawDocHasDate(String docId, Map<String, dynamic> data) {
    return _DeviceVitalsFields.allTimes(docId, data).isNotEmpty;
  }

  static Map<String, dynamic> _jsonSafe(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      out[key] = _jsonValue(value);
    });
    return out;
  }

  static dynamic _jsonValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is DocumentReference) return value.path;
    if (value is GeoPoint) {
      return {'lat': value.latitude, 'lng': value.longitude};
    }
    if (value is Map) {
      return _jsonSafe(Map<String, dynamic>.from(value));
    }
    if (value is List) return value.map(_jsonValue).toList();
    return value;
  }

  static Future<List<DeviceReading>> fetchForRange(DateTimeRange range) async {
    return (await queryForRange(range)).inRange;
  }

  static Map<String, dynamic> summarize(
    List<DeviceReading> readings, {
    int excludedOutsidePeriod = 0,
    DateTimeRange? range,
  }) {
    final header = <String, dynamic>{
      if (range != null) 'period': RecordTime.formatRange(range),
      'source': 'wearable device data',
      'readingsInPeriod': readings.length,
      'readingsExcludedAsOutsidePeriod': excludedOutsidePeriod,
    };
    if (readings.isEmpty) {
      return {
        ...header,
        'note': excludedOutsidePeriod > 0
            ? 'Device history exists, but $excludedOutsidePeriod reading(s) are outside this period. Last 30 days only includes dates inside ${range == null ? 'the selected range' : RecordTime.formatRange(range)}.'
            : 'No stored device readings in this period. Connect a band or wait for wearable sync.',
      };
    }

    List<num> nums(num? Function(DeviceReading r) pick) => readings
        .map(pick)
        .whereType<num>()
        .where((v) => v > 0)
        .toList();

    Map<String, dynamic>? stats(List<num> values, {String? unit}) {
      if (values.isEmpty) return null;
      final sorted = [...values]..sort();
      final avg = values.fold<num>(0, (a, b) => a + b) / values.length;
      return {
        'count': values.length,
        'avg': num.parse(avg.toStringAsFixed(1)),
        'min': sorted.first,
        'max': sorted.last,
        'latest': values.first,
        if (unit != null) 'unit': unit,
      };
    }

    String fmt(int ms) => DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(ms));

    final bp = readings
        .where((r) => (r.sys ?? 0) > 0 && (r.dia ?? 0) > 0)
        .take(40)
        .map((r) => {
              'time': fmt(r.time),
              'sys': r.sys,
              'dia': r.dia,
              if (r.heartRate != null) 'heartRate': r.heartRate,
              if (r.hrv != null) 'hrv': r.hrv,
            })
        .toList();

    final activity = readings
        .where((r) => (r.steps ?? 0) > 0)
        .take(31)
        .map((r) => {
              'date': r.date ?? fmt(r.time).split(' ').first,
              'steps': r.steps,
              if (r.calories != null) 'calories': r.calories,
              if (r.distance != null) 'distanceKm': r.distance,
            })
        .toList();

    final sleep = readings
        .where((r) => (r.sleepMinutes ?? 0) > 0)
        .take(31)
        .map((r) => {
              'date': r.date ?? fmt(r.time),
              'sleepMinutes': r.sleepMinutes,
            })
        .toList();

    final hrvSamples = readings
        .where((r) => (r.hrv ?? 0) > 0)
        .take(20)
        .map((r) => {
              'time': fmt(r.time),
              'hrv': r.hrv,
              if (r.heartRate != null) 'heartRate': r.heartRate,
            })
        .toList();

    final recentSamples = readings.take(20).map((r) {
      return {
        'time': fmt(r.time),
        if (r.heartRate != null) 'heartRate': r.heartRate,
        if (r.hrv != null) 'hrv': r.hrv,
        if (r.spo2 != null) 'spo2': r.spo2,
        if (r.sys != null) 'sys': r.sys,
        if (r.dia != null) 'dia': r.dia,
        if (r.steps != null) 'steps': r.steps,
        if (r.sleepMinutes != null) 'sleepMinutes': r.sleepMinutes,
        if (r.temperature != null) 'temperatureC': r.temperature,
        if (r.bloodSugar != null) 'bloodSugar': r.bloodSugar,
      };
    }).toList();

    final summary = <String, dynamic>{
      ...header,
      if (recentSamples.isNotEmpty) 'recentSamples': recentSamples,
      'heartRate': stats(
        nums((r) => r.heartRate),
        unit: 'bpm',
      ),
      'hrv': stats(nums((r) => r.hrv)),
      'stress': stats(nums((r) => r.stress)),
      'spo2': stats(nums((r) => r.spo2), unit: '%'),
      'temperatureC': stats(nums((r) => r.temperature), unit: 'C'),
      'deviceBloodSugar': stats(nums((r) => r.bloodSugar)),
      if (bp.isNotEmpty)
        'deviceBloodPressure': {
          'note':
              'Band-estimated BP from HRV packets, not a cuff measurement.',
          'samples': bp,
        },
      if (hrvSamples.isNotEmpty) 'hrvSamples': hrvSamples,
      if (activity.isNotEmpty) 'dailyActivity': activity,
      if (sleep.isNotEmpty) 'sleep': sleep,
    };

    summary.removeWhere((_, value) => value == null);
    return summary;
  }
}

class DeviceHistoryQuery {
  const DeviceHistoryQuery({
    required this.inRange,
    required this.excludedOutsidePeriod,
    required this.range,
    this.myDeviceVitals = const [],
    this.myDeviceVitalsInPeriod = 0,
    this.myDeviceVitalsExcluded = 0,
    this.myDeviceVitalsUndated = 0,
  });

  final List<DeviceReading> inRange;
  final int excludedOutsidePeriod;
  final DateTimeRange range;
  final List<Map<String, dynamic>> myDeviceVitals;
  final int myDeviceVitalsInPeriod;
  final int myDeviceVitalsExcluded;
  final int myDeviceVitalsUndated;
}

/// Maps client [my_device_vitals] field names onto [DeviceReading].
class _DeviceVitalsFields {
  static const _nestedKeys = {
    'vitals',
    'data',
    'dicdata',
    'payload',
    'reading',
    'readings',
    'history',
    'samples',
    'items',
    'records',
    'values',
    'metrics',
  };

  static const _timeKeys = [
    'time',
    'timestamp',
    'ts',
    'date',
    'day',
    'datetime',
    'dateTime',
    'measuredAt',
    'recordedAt',
    'createdAt',
    'created_at',
    'addedTime',
    'deviceDate',
    ...RecordTime.metricTimeKeys,
  ];

  static List<Map<String, dynamic>> flatten(Map<String, dynamic> data) {
    final out = <Map<String, dynamic>>[];

    void walk(
      Map<String, dynamic> map,
      int depth,
      Map<String, dynamic> inherited,
    ) {
      final merged = {...inherited, ...map};
      out.add(merged);
      if (depth > 3) return;
      final nextInherited = Map<String, dynamic>.from(inherited);
      for (final key in _timeKeys) {
        if (map[key] != null) nextInherited[key] = map[key];
      }
      map.forEach((key, value) {
        if (!_nestedKeys.contains(_compact(key))) return;
        if (value is Map) {
          walk(Map<String, dynamic>.from(value), depth + 1, nextInherited);
        } else if (value is List) {
          for (final item in value) {
            if (item is Map) {
              walk(Map<String, dynamic>.from(item), depth + 1, nextInherited);
            }
          }
        }
      });
    }

    walk(data, 0, const {});
    return out;
  }

  static int? timeFromDocId(String? docId) {
    if (docId == null || docId.isEmpty) return null;
    final direct = RecordTime.parse(docId) ?? RecordTime.toDateTime(docId);
    if (direct != null) return direct.millisecondsSinceEpoch;
    for (final part in docId.split(RegExp(r'[_/]'))) {
      final parsed = RecordTime.parse(part) ?? RecordTime.toDateTime(part);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return null;
  }

  static int? _asTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.trim().isEmpty) return null;
    return RecordTime.toEpochMs(raw) ??
        RecordTime.parse(raw)?.millisecondsSinceEpoch;
  }

  static Map<String, String> sampleTimes(Map<String, dynamic> data) {
    final out = <String, String>{};
    data.forEach((key, value) {
      if (!key.toString().toLowerCase().contains('time')) return;
      out[key] = value?.toString() ?? 'null';
    });
    return out;
  }

  static List<int> allTimes(String docId, Map<String, dynamic> data) {
    final times = <int>{};
    void consider(dynamic raw) {
      final ms = _asTime(raw);
      if (ms != null && ms > 0) times.add(ms);
    }

    for (final key in _timeKeys) {
      consider(data[key]);
    }
    data.forEach((key, value) {
      if (key.toString().toLowerCase().endsWith('time')) consider(value);
    });
    final fromId = timeFromDocId(docId);
    if (fromId != null) times.add(fromId);
    return times.toList();
  }

  /// Client docs store one snapshot with per-metric stamps:
  /// heartRate + heartRateTime, oxygenLevel + oxygenLevelTime, etc.
  static List<DeviceReading> splitClientSnapshot(
    String docId,
    Map<String, dynamic> data,
  ) {
    final out = <DeviceReading>[];

    void add(DeviceReading reading) {
      if (reading.time > 0 && reading.hasUsefulValue) out.add(reading);
    }

    add(DeviceReading(
      type: 'heartRate',
      time: _asTime(data['heartRateTime']) ?? 0,
      heartRate: _asNum(data['heartRate'])?.toInt(),
    ));
    add(DeviceReading(
      type: 'spo2',
      time: _asTime(data['oxygenLevelTime']) ?? 0,
      spo2: _asNum(data['oxygenLevel'])?.toInt(),
    ));
    add(DeviceReading(
      type: 'temperature',
      time: _asTime(data['temperatureTime']) ?? 0,
      temperature: _asNum(data['temperature'])?.toDouble(),
    ));

    final activityTime =
        _asTime(data['exerciseTime']) ?? _asTime(data['stepsTime']);
    add(DeviceReading(
      type: 'activity',
      time: activityTime ?? 0,
      steps: _asNum(data['stepsTaken'] ?? data['steps'])?.toInt(),
      calories: _asNum(data['calories'])?.toDouble(),
      distance: _asNum(data['distance'])?.toDouble(),
    ));

    final sleepStamp = _asTime(data['sleepTime']);
    final sleepMinutes = _asNum(data['sleepMinutes'] ?? data['sleep'])?.toInt() ??
        (sleepStamp == null ? _asNum(data['sleepTime'])?.toInt() : null);
    add(DeviceReading(
      type: 'sleep',
      time: sleepStamp ??
          _asTime(data['heartRateTime']) ??
          activityTime ??
          0,
      sleepMinutes: sleepMinutes,
    ));

    if (out.isEmpty && allTimes(docId, data).isNotEmpty) {
      add(DeviceReading.fromMap(data, docId: docId));
    }
    return out;
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final keys = <String, dynamic>{};
    raw.forEach((key, value) {
      keys[_compact(key)] = value;
    });

    num? pick(List<String> names) {
      for (final name in names) {
        final n = _asNum(keys[name]);
        if (n != null) return n;
      }
      return null;
    }

    String? pickText(List<String> names) {
      for (final name in names) {
        final value = keys[name] ?? raw[name];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') return text;
      }
      return null;
    }

    final typeRaw = (pickText(['type', 'metric', 'vital', 'vitaltype', 'category']) ??
            'device')
        .toLowerCase();
    final value = pick(['value', 'val', 'amount', 'readingvalue']);

    var heartRate = pick([
      'heartrate',
      'hr',
      'bpm',
      'pulse',
      'heartratebpm',
      'avghr',
      'statichr',
      'resthr',
    ])?.toInt();
    var hrv = pick(['hrv', 'heartratevariability'])?.toInt();
    var sys = pick([
      'sys',
      'highbp',
      'systolic',
      'sbp',
      'systolicbp',
      'bloodpressuresystolic',
    ])?.toInt();
    var dia = pick([
      'dia',
      'lowbp',
      'diastolic',
      'dbp',
      'diastolicbp',
      'bloodpressurediastolic',
    ])?.toInt();
    var stress = pick(['stress', 'stressindex'])?.toInt();
    var spo2 = pick([
      'spo2',
      'bloodoxygen',
      'oxygen',
      'spo2value',
      'o2',
      'oxygensaturation',
      'oxygenlevel',
    ])?.toInt();
    var steps = pick([
      'steps',
      'step',
      'stepstaken',
      'stepcount',
      'todaysteps',
    ])?.toInt();
    var calories = pick(['calories', 'calorie', 'kcal'])?.toDouble();
    var distance = pick(['distance', 'distancekm', 'dist'])?.toDouble();
    var sleepMinutes = pick([
      'sleepminutes',
      'sleeptotal',
      'totalsleep',
      'sleepduration',
      'allsleep',
      'sleeptime',
      'sleepmins',
    ])?.toInt();
    final sleepHours = pick(['sleephours', 'hoursofsleep']);
    if ((sleepMinutes ?? 0) <= 0 && sleepHours != null && sleepHours > 0) {
      sleepMinutes = (sleepHours * 60).round();
    }
    if ((sleepMinutes ?? 0) <= 0) {
      final sleep = pick(['sleep']);
      if (sleep != null && sleep > 24) sleepMinutes = sleep.round();
    }
    var temperature = pick(['temperature', 'temp', 'temperaturec'])?.toDouble();
    var bloodSugar = pick([
      'bloodsugar',
      'glucose',
      'bloodglucose',
      'sugar',
      'bg',
    ])?.toDouble();

    if (value != null) {
      if (heartRate == null && _matches(typeRaw, const ['hr', 'heart', 'bpm'])) {
        heartRate = value.toInt();
      } else if (hrv == null && typeRaw.contains('hrv')) {
        hrv = value.toInt();
      } else if (spo2 == null &&
          _matches(typeRaw, const ['spo2', 'oxygen', 'o2'])) {
        spo2 = value.toInt();
      } else if (steps == null && typeRaw.contains('step')) {
        steps = value.toInt();
      } else if (sleepMinutes == null && typeRaw.contains('sleep')) {
        sleepMinutes = value > 24 ? value.round() : (value * 60).round();
      } else if (temperature == null && typeRaw.contains('temp')) {
        temperature = value.toDouble();
      } else if (bloodSugar == null &&
          _matches(typeRaw, const ['sugar', 'glucose', 'bg'])) {
        bloodSugar = value.toDouble();
      } else if (stress == null && typeRaw.contains('stress')) {
        stress = value.toInt();
      } else if (sys == null && _matches(typeRaw, const ['sys', 'systolic'])) {
        sys = value.toInt();
      } else if (dia == null && _matches(typeRaw, const ['dia', 'diastolic'])) {
        dia = value.toInt();
      }
    }

    var type = typeRaw;
    if (type == 'device' || type.isEmpty) {
      if ((hrv ?? 0) > 0) {
        type = 'hrv';
      } else if ((steps ?? 0) > 0 && (heartRate ?? 0) <= 0) {
        type = 'activity';
      } else if ((sleepMinutes ?? 0) > 0 && (heartRate ?? 0) <= 0) {
        type = 'sleep';
      } else if ((heartRate ?? 0) > 0) {
        type = 'heartRate';
      } else if ((spo2 ?? 0) > 0) {
        type = 'spo2';
      } else if ((temperature ?? 0) > 0) {
        type = 'temperature';
      }
    }

    return {
      'type': type,
      'time': raw['time'] ??
          raw['timestamp'] ??
          raw['ts'] ??
          keys['time'] ??
          keys['timestamp'],
      'date': pickText(['date', 'day', 'recorddate', 'devicedate']) ??
          raw['date'],
      'measuredAt': raw['measuredAt'] ??
          raw['recordedAt'] ??
          raw['readingAt'] ??
          keys['measuredat'],
      'addedTime': raw['addedTime'] ??
          raw['createdAt'] ??
          raw['created_at'] ??
          keys['createdat'],
      if (heartRate != null) 'heartRate': heartRate,
      if (hrv != null) 'hrv': hrv,
      if (sys != null) 'sys': sys,
      if (dia != null) 'dia': dia,
      if (stress != null) 'stress': stress,
      if (spo2 != null) 'spo2': spo2,
      if (steps != null) 'steps': steps,
      if (calories != null) 'calories': calories,
      if (distance != null) 'distance': distance,
      if (sleepMinutes != null) 'sleepMinutes': sleepMinutes,
      if (temperature != null) 'temperature': temperature,
      if (bloodSugar != null) 'bloodSugar': bloodSugar,
    };
  }

  static String _compact(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  static bool _matches(String type, List<String> tokens) =>
      tokens.any(type.contains);

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    final text = value.toString().trim().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }
}
