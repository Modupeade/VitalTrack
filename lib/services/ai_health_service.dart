import 'dart:convert';

import 'package:age_calculator/age_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:vitals_10/services/device_history_service.dart';
import 'package:vitals_10/utils/record_time.dart';

class AiChatTurn {
  final String role; // user | assistant
  final String text;

  const AiChatTurn({required this.role, required this.text});
}

class AiHealthContext {
  final String userName;
  final String userEmail;
  final String? age;
  final String gender;
  final String dateRange;
  final List<Map<String, dynamic>> bpRecords;
  final List<Map<String, dynamic>> glucoseRecords;
  final List<Map<String, dynamic>> weightRecords;
  final Map<String, dynamic>? wearableSnapshot;
  final Map<String, dynamic>? deviceHistory;
  final List<Map<String, dynamic>> myDeviceVitals;
  final int myDeviceVitalsInPeriod;
  final int myDeviceVitalsExcluded;
  final int myDeviceVitalsUndated;
  final Map<String, List<Map<String, dynamic>>> otherLoggedTrackers;
  final List<Map<String, dynamic>> sleepLogs;
  final List<Map<String, dynamic>> dailySleepRecords;

  const AiHealthContext({
    required this.userName,
    required this.userEmail,
    required this.age,
    required this.gender,
    required this.dateRange,
    required this.bpRecords,
    required this.glucoseRecords,
    required this.weightRecords,
    this.wearableSnapshot,
    this.deviceHistory,
    this.myDeviceVitals = const [],
    this.myDeviceVitalsInPeriod = 0,
    this.myDeviceVitalsExcluded = 0,
    this.myDeviceVitalsUndated = 0,
    this.otherLoggedTrackers = const {},
    this.sleepLogs = const [],
    this.dailySleepRecords = const [],
  });

  String get latestWeight {
    if (weightRecords.isEmpty) return 'not logged';
    final latest = weightRecords.first;
    return '${latest['weight'] ?? latest['value']} ${latest['unit'] ?? 'kg'}';
  }
}

class AiFollowUpState {
  const AiFollowUpState({
    required this.used,
    required this.dateRange,
    required this.turns,
  });

  final int used;
  final String dateRange;
  final List<AiChatTurn> turns;
}

class AiHealthService {
  static const int maxFollowUps = 10;
  static const _followUpsUsedField = 'aiFollowUpsUsed';
  static const _followUpsRangeField = 'aiFollowUpsDateRange';
  static const _followUpsTurnsField = 'aiFollowUpTurns';
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _configCollection = 'config';
  static const _configDocId = 'w2z3f1gZ884WoNxSw3en';
  static const _fallbackModels = [
    'claude-sonnet-5',
    'claude-sonnet-4-5',
    'claude-3-5-sonnet-latest',
  ];

  static String _apiKey = '';
  static String _preferredModel = _fallbackModels.first;
  static Future<_ClaudeConfig>? _configFuture;

  static bool get hasApiKey =>
      _apiKey.isNotEmpty && _apiKey.startsWith('sk-ant-');

  /// Loads Claude key + model from Firestore config (cached for the session).
  static Future<_ClaudeConfig> _loadClaudeConfig({bool force = false}) async {
    if (!force && hasApiKey) {
      return _ClaudeConfig(apiKey: _apiKey, model: _preferredModel);
    }
    if (!force && _configFuture != null) return _configFuture!;

    _configFuture = () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(_configCollection)
            .doc(_configDocId)
            .get();
        final data = doc.data() ?? {};
        final key = (data['ANTHROPIC_API_KEY'] ?? '').toString().trim();
        final model = (data['CLAUDE_MODEL'] ?? '').toString().trim();
        _apiKey = key;
        if (model.isNotEmpty) _preferredModel = model;
        debugPrint(
          'Claude config loaded from Firestore '
          '(key=${hasApiKey ? 'ok' : 'missing'}, model=$_preferredModel)',
        );
        return _ClaudeConfig(apiKey: _apiKey, model: _preferredModel);
      } catch (e) {
        _configFuture = null;
        debugPrint('Claude config fetch failed: $e');
        rethrow;
      }
    }();

    return _configFuture!;
  }

  static Future<AiHealthContext> gatherContext({
    required DateTimeRange dateRange,
    Map<String, dynamic>? wearableSnapshot,
    List<DeviceReading> sessionDeviceReadings = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in again.');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final dob = (data['dob'] ?? '').toString();

    String? age;
    if (dob.isNotEmpty) {
      try {
        final parsed = DateFormat('dd/MM/yyyy').parse(dob);
        age = '${AgeCalculator.age(parsed).years}';
      } catch (_) {
        age = null;
      }
    }

    if (sessionDeviceReadings.isNotEmpty) {
      await DeviceHistoryService.persist(sessionDeviceReadings);
    }

    final historySnap = await FirebaseFirestore.instance
        .collection('trackingHistory')
        .where('uid', isEqualTo: user.uid)
        .orderBy('addedTime', descending: true)
        .limit(2500)
        .get();

    final bp = _filterByTracker(historySnap.docs, dateRange, 'Blood Pressure');
    final glucose =
        _filterByTracker(historySnap.docs, dateRange, 'Blood Glucose');
    final weight = _filterByTracker(historySnap.docs, dateRange, 'Weight');
    final otherLogs = _otherTrackersInRange(historySnap.docs, dateRange);
    final deviceQueryFuture = DeviceHistoryService.queryForRange(dateRange);
    final sleepLogsFuture = _querySleepCollection(
      collection: 'sleep_logs',
      userId: user.uid,
      dateRange: dateRange,
    );
    final dailySleepFuture = _querySleepCollection(
      collection: 'daily_sleep',
      userId: user.uid,
      dateRange: dateRange,
    );
    final deviceQuery = await deviceQueryFuture;
    final sleepLogs = await sleepLogsFuture;
    final dailySleep = await dailySleepFuture;

    return AiHealthContext(
      userName: (data['name'] ?? 'User').toString(),
      userEmail: (data['email'] ?? user.email ?? '').toString(),
      age: age,
      gender: (data['gender'] ?? 'not set').toString(),
      dateRange: RecordTime.formatRange(dateRange),
      bpRecords: bp,
      glucoseRecords: glucose,
      weightRecords: weight,
      wearableSnapshot: wearableSnapshot,
      deviceHistory: DeviceHistoryService.summarize(
        deviceQuery.inRange,
        excludedOutsidePeriod: deviceQuery.excludedOutsidePeriod,
        range: dateRange,
      ),
      myDeviceVitals: deviceQuery.myDeviceVitals,
      myDeviceVitalsInPeriod: deviceQuery.myDeviceVitalsInPeriod,
      myDeviceVitalsExcluded: deviceQuery.myDeviceVitalsExcluded,
      myDeviceVitalsUndated: deviceQuery.myDeviceVitalsUndated,
      otherLoggedTrackers: otherLogs,
      sleepLogs: sleepLogs,
      dailySleepRecords: dailySleep,
    );
  }

  static Future<String> generateReport(AiHealthContext ctx) async {
    final prompt = _buildReportPrompt(ctx);
    return _complete(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    );
  }

  static Future<AiFollowUpState> loadFollowUpState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AiFollowUpState(used: 0, dateRange: '', turns: []);
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    final used = (data[_followUpsUsedField] as num?)?.toInt() ?? 0;
    final storedRange = (data[_followUpsRangeField] ?? '').toString();
    final rawTurns = data[_followUpsTurnsField];
    final turns = <AiChatTurn>[];
    if (rawTurns is List) {
      for (final item in rawTurns) {
        if (item is! Map) continue;
        final role = (item['role'] ?? '').toString();
        final text = (item['text'] ?? '').toString();
        if (role.isEmpty || text.isEmpty) continue;
        turns.add(AiChatTurn(role: role, text: text));
      }
    }
    return AiFollowUpState(
      used: used.clamp(0, maxFollowUps),
      dateRange: storedRange,
      turns: turns,
    );
  }

  static Future<void> saveFollowUpState({
    required int used,
    required String dateRange,
    required List<AiChatTurn> turns,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      _followUpsUsedField: used.clamp(0, maxFollowUps),
      _followUpsRangeField: dateRange,
      _followUpsTurnsField: turns
          .map((turn) => {'role': turn.role, 'text': turn.text})
          .toList(),
    }, SetOptions(merge: true));
  }

  static Future<String> askFollowUp({
    required AiHealthContext ctx,
    required String report,
    required List<AiChatTurn> followUps,
    required String question,
  }) async {
    final saved = await loadFollowUpState();
    if (saved.used >= maxFollowUps) {
      throw Exception(
        'You have used all $maxFollowUps follow-up questions.',
      );
    }

    final messages = <Map<String, String>>[
      {'role': 'user', 'content': _buildReportPrompt(ctx)},
      {'role': 'assistant', 'content': report},
    ];
    for (final turn in followUps) {
      messages.add({'role': turn.role, 'content': turn.text});
    }
    messages.add({'role': 'user', 'content': question});
    return _complete(messages: messages);
  }

  static String _buildReportPrompt(AiHealthContext ctx) {
    return '''
Write a deep health review for this Vitals 101 user for the selected period only.

Profile:
- Name: ${ctx.userName}
- Age: ${ctx.age ?? 'unknown'}
- Gender: ${ctx.gender}
- Latest logged weight: ${ctx.latestWeight}
- Period: ${ctx.dateRange}

Manually logged Blood Pressure records (sys/dia/pulse):
${_json(ctx.bpRecords)}

Manually logged Blood Glucose records:
${_json(ctx.glucoseRecords)}

Manually logged Weight records:
${_json(ctx.weightRecords)}

Wearable device data for this same period only. Use these numbers in section 5. Older months such as Sept–Dec 2025 must be excluded unless they fall inside Period:
${_deviceVitalsPrompt(ctx)}

Summarized device / wearable readings for the same period:
${ctx.deviceHistory == null ? 'No summarized device history for this period.' : _json(ctx.deviceHistory!)}

Sleep logs for this same period only (date and sleep duration as stored):
${ctx.sleepLogs.isEmpty ? 'No sleep logs in this period.' : _json(ctx.sleepLogs)}

Daily sleep for this same period only (date and sleep duration as stored):
${ctx.dailySleepRecords.isEmpty ? 'No daily sleep records in this period.' : _json(ctx.dailySleepRecords)}

Other logged trackers in this same period:
${ctx.otherLoggedTrackers.isEmpty ? 'None.' : _json(ctx.otherLoggedTrackers)}

Current wearable snapshot (latest values held in this app session):
${ctx.wearableSnapshot == null ? 'No wearable reading in this session.' : _json(ctx.wearableSnapshot!)}

Structure the report with:
1. Period summary
2. Blood pressure (manual logs and any device-estimated BP)
3. Blood sugar
4. Weight
5. Device data (heart rate, HRV, SpO2, steps, sleep, temperature) when present
6. Sleep — cover Sleep logs and Daily sleep when present. Use the actual duration values; if units are unclear, report the raw numbers and say so. In the written report use the labels "Sleep logs" and "Daily sleep" only. Never name databases, collection names, or technical store names.
7. Patterns or gaps in the logged and device data
8. Questions the user could ask a clinician

Use the actual numbers. If a section has no data, say so. Do not invent wearable history, HRV history, sleep history, or medical diagnoses.
Write the report in plain English for the user. Do not mention collection names, Firestore, or document IDs.
''';
  }

  static String _deviceVitalsPrompt(AiHealthContext ctx) {
    final counts =
        '${ctx.myDeviceVitalsInPeriod} document(s) in period, ${ctx.myDeviceVitalsExcluded} outside period, ${ctx.myDeviceVitalsUndated} with no parseable date.';
    if (ctx.myDeviceVitals.isEmpty) {
      return 'No wearable device documents in this period. $counts';
    }
    return '$counts\n${_json(ctx.myDeviceVitals)}';
  }

  static String _json(Object value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  static Future<String> _complete({
    required List<Map<String, String>> messages,
  }) async {
    try {
      await _loadClaudeConfig();
    } catch (e) {
      throw Exception(
        'Could not load Claude settings from Firestore config. $e',
      );
    }
    if (!hasApiKey) {
      throw Exception(
        'Claude API key is missing in Firestore config/$_configDocId '
        '(field ANTHROPIC_API_KEY).',
      );
    }

    final models = <String>{_preferredModel, ..._fallbackModels}.toList();

    Object? lastError;
    for (final model in models) {
      try {
        return await _post(model: model, messages: messages);
      } catch (e) {
        lastError = e;
        final text = e.toString().toLowerCase();
        if (text.contains('not_found_error') ||
            text.contains('404') ||
            text.contains('invalid model')) {
          continue;
        }
        rethrow;
      }
    }
    throw Exception(lastError?.toString() ?? 'Claude request failed.');
  }

  static Future<String> _post({
  required String model,
  required List<Map<String, String>> messages,
}) async {
  final response = await http.post(
    Uri.parse(_apiUrl),
    headers: {
      'x-api-key': _apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'model': model,
      'max_tokens': 8192, // ← was 2500 – thinking tokens count against this
      // Disable adaptive thinking for structured health reports
      // (Sonnet 5 has it on by default)
      'thinking': {'type': 'disabled'},
      'system': '''
You are a health-data reviewer inside the Vitals 101 app.
You are not a doctor. Do not diagnose, prescribe, or tell the user to stop medication.
Only use the data provided in the conversation.
When wearable device readings or summarized device readings for the selected period are provided, use them in the report. Do not say wearable history is missing if those numbers are present.
When Sleep logs or Daily sleep records for the selected period are provided, use them in the sleep section. Do not say sleep data is missing if those numbers are present.
In the user-facing report, use everyday labels only (for example Sleep logs, Daily sleep, device data). Never mention collection names, database names, or Firestore.
If a metric truly has no values in the provided data, say so.
Keep answers in English, clear, and based on the user's own logged numbers and device readings.
Always include this reminder when writing the first report: "This is not medical advice. It is based only on the data you logged in Vitals and any device readings for this period."
''',
      'messages': messages,
    }),
  );

  final decoded = jsonDecode(response.body);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final err = decoded is Map ? decoded['error'] : null;
    final message = err is Map
        ? (err['message'] ?? response.body)
        : response.body;
    throw Exception(message);
  }

  final content = decoded['content'];
  if (content is List) {
    // Collect every text block (ignore thinking blocks)
    final text = content
        .whereType<Map>()
        .where((block) => block['type'] == 'text')
        .map((block) => (block['text'] ?? '').toString())
        .join('\n')
        .trim();

    if (text.isNotEmpty) return text;

    // Helpful debug if it ever happens again
    final types = content
        .whereType<Map>()
        .map((b) => b['type'])
        .toList();
    print('Claude returned no text. Content block types: $types');
    print('Full body: ${response.body}');
  }

  throw Exception('Claude returned an empty report.');
}

  static List<Map<String, dynamic>> _filterByTracker(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTimeRange dateRange,
    String trackerName,
  ) {
    final filtered = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final data = doc.data();
      final name = data['trackerName']?.toString();
      if (name != trackerName) continue;
      if (!RecordTime.isInRange(dateRange, RecordTime.resolveMap(data))) {
        continue;
      }

      if (trackerName == 'Blood Pressure') {
        filtered.add({
          'time': data['time'] ?? data['date'] ?? data['addedTime'],
          'sys': data['sys'],
          'dia': data['dia'],
          'pulse': data['pulse'] ?? data['pul'] ?? '0',
        });
      } else {
        filtered.add({
          'time': data['time'] ?? data['date'] ?? data['addedTime'],
          'value': data['value'],
          if (trackerName == 'Weight') 'unit': data['unit'] ?? 'kg',
          if (trackerName == 'Blood Glucose') 'type': data['type'] ?? 'N/A',
        });
      }
    }

    return filtered;
  }

  static Map<String, List<Map<String, dynamic>>> _otherTrackersInRange(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTimeRange dateRange,
  ) {
    const skip = {'Blood Pressure', 'Blood Glucose', 'Weight'};
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final doc in docs) {
      final data = doc.data();
      final name = data['trackerName']?.toString() ?? '';
      if (name.isEmpty || skip.contains(name)) continue;
      if (!RecordTime.isInRange(dateRange, RecordTime.resolveMap(data))) {
        continue;
      }
      grouped.putIfAbsent(name, () => []).add({
        'time': data['time'] ?? data['date'] ?? data['addedTime'],
        'value': data['value'],
        if (data['sys'] != null) 'sys': data['sys'],
        if (data['dia'] != null) 'dia': data['dia'],
      });
    }
    return grouped;
  }

  /// Parses sleep document dates (ISO, padded, or "2026-6-30").
  static DateTime? _parseSleepDate(dynamic raw) {
    final fromRecordTime = RecordTime.parse(raw);
    if (fromRecordTime != null) return fromRecordTime;

    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final iso = DateTime.tryParse(s);
    if (iso != null && iso.year >= 2020 && iso.year <= 2100) return iso;

    // daily_sleep stores unpadded months: "2026-6-30"
    final parts = s.split(RegExp(r'[T\s]')).first.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  static bool _sleepDateInRange(DateTimeRange range, dynamic rawDate) {
    final dt = _parseSleepDate(rawDate);
    if (dt == null) return false;
    return RecordTime.isInRange(range, dt.millisecondsSinceEpoch);
  }

  static Future<List<Map<String, dynamic>>> _querySleepCollection({
    required String collection,
    required String userId,
    required DateTimeRange dateRange,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .limit(2500)
          .get();

      final out = <Map<String, dynamic>>[];
      var excluded = 0;
      var undated = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final parsed = _parseSleepDate(data['date']);
        if (parsed == null) {
          undated++;
          continue;
        }
        if (!_sleepDateInRange(dateRange, data['date'])) {
          excluded++;
          continue;
        }
        out.add({
          'id': doc.id,
          'date': data['date'],
          'sleepTime': data['sleepTime'],
        });
      }

      out.sort((a, b) {
        final da = _parseSleepDate(a['date']);
        final db = _parseSleepDate(b['date']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      debugPrint(
        '$collection: ${out.length} in period, $excluded outside, '
        '$undated undated (of ${snap.docs.length} for userId)',
      );
      if (out.length > 80) return out.take(80).toList();
      return out;
    } catch (e) {
      debugPrint('$collection fetch failed: $e');
      return [];
    }
  }
}

class _ClaudeConfig {
  const _ClaudeConfig({required this.apiKey, required this.model});

  final String apiKey;
  final String model;
}
