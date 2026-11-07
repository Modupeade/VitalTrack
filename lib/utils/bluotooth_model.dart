import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ms_ble_data_analysis/ms_ble_data_analysis.dart';
import 'package:ms_ble_data_analysis/device_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitals_10/services/ble_background_service.dart';
import 'package:vitals_10/services/device_history_service.dart';
import 'package:vitals_10/utils/dashboard_models.dart';
import 'package:vitals_10/utils/sleep_calc.dart';
import 'package:vitals_10/utils/vitals_history.dart';
import 'package:vitals_10/utils/vitals_validator.dart';

/// BLE UUIDs for the V8 band.
/// flutter_blue_plus normalises 16-bit short form to full 128-bit on both
/// platforms, so unlike flutter_blue_elves there is no Platform.isAndroid split.
class BleUuids {
  static final Guid service = Guid('fff0');
  static final Guid writeChar = Guid('fff6');
  static final Guid notifyChar = Guid('fff7');
}

enum BleStatus { idle, scanning, connecting, connected, disconnected }


/// Owns the BLE link and every value parsed off it.
///
/// This is provided above MaterialApp in main.dart, so it outlives every route:
/// the notify subscription lives here rather than in a widget's State, and
/// nothing about navigating between pages tears it down. Combined with the
/// Android foreground service (see BleBackgroundService) the link also survives
/// the app being backgrounded.
class BluetoothScanModel extends ChangeNotifier {
  // ---------------------------------------------------------------- state

  BleStatus _status = BleStatus.idle;
  BleStatus get status => _status;

  bool get isScanning => _status == BleStatus.scanning;
  bool get isConnected => _status == BleStatus.connected;

  final List<ScanResult> scanResults = [];

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? _writeChar;

  /// Set when the user taps disconnect, so we don't auto-reconnect.
  bool _manualDisconnect = false;

  /// Consecutive failed reconnects, used to space out the backoff.
  int _reconnectCount = 0;
  Timer? _reconnectTimer;

  /// Cap on the backoff delay. Retries continue indefinitely while the band is
  /// meant to be connected — a wearable that gives up after three attempts
  /// stops reporting the moment the user walks out of range and back.
  static const Duration _maxBackoff = Duration(minutes: 2);

  /// Last error, for the UI to surface instead of the vendor's Get.dialog calls.
  String? errorMessage;

  /// Replaces the vendor's EventBus('dataCallBack') — pages that need to react
  /// to individual command responses listen here instead of rebuilding.
  final StreamController<Map> _dataController =
      StreamController<Map>.broadcast();
  Stream<Map> get dataStream => _dataController.stream;

  /// Replaces EventBus('dataByteCallBack').
  final StreamController<List<int>> _rawController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get rawStream => _rawController.stream;

  // ------------------------------------------------------- latest readings

  Map<dynamic, dynamic> lastResult = {};
  DateTime? lastUpdate;

  int? heartRate;
  int? steps;
  int? bloodOxygen;
  int? batteryLevel;
  int? calories;
  int? distanceMetres;

  /// Skin temperature in celsius. Decimal, unlike the other live readings.
  double? temperature;

  /// Blood sugar as the band reports it — mmol/L on the V8.
  double? bloodSugar;

  /// Sleep totals in minutes, as reported by the band's nightly summary.
  int? sleepTotalMinutes;
  int? deepSleepMinutes;
  int? remSleepMinutes;
  int? awakeMinutes;

  /// Not shown on the Sleep tab, which has no light-sleep row, but counted
  /// towards the total. Kept distinct from REM on purpose: most bands in this
  /// class report deep/light and never REM, and showing light sleep under a
  /// "REM SLEEP" heading would misreport it.
  int? lightSleepMinutes;

  /// Band's own 0..100 sleep score when it sends one.
  int? sleepScore;

  /// From HRV history packets. Same fields the dashboard shows as BP.
  int? hrv;
  int? highBp;
  int? lowBp;

  /// The band doesn't report a resting rate, so the day's lowest reading
  /// stands in for it — the usual approximation.
  int? get restingHeartRate => hrHistory.restingEstimate()?.round();

  DateTime? _lastLivePersist;
  Future<void>? _historySyncJob;
  final Map<String, _HistoryPull> _historyPulls = {};

  // -------------------------------------------------------------- history

  /// Session history, kept in memory only. Cleared when the process dies.
  final VitalSeries hrHistory = VitalSeries();
  final VitalSeries spo2History = VitalSeries();
  final VitalSeries stepsHistory = VitalSeries();
  final VitalSeries temperatureHistory = VitalSeries();
  final VitalSeries bloodSugarHistory = VitalSeries();

  /// Averages for [range], sized to match that range's axis labels.
  List<double> heartRateTrend(TrendRange range) => hrHistory.bucketed(range);
  List<double> bloodOxygenTrend(TrendRange range) => spo2History.bucketed(range);
  List<double> stepsTrend(TrendRange range) => stepsHistory.bucketed(range);
  List<double> temperatureTrend(TrendRange range) =>
      temperatureHistory.bucketed(range);
  List<double> bloodSugarTrend(TrendRange range) =>
      bloodSugarHistory.bucketed(range);

  // ----------------------------------------------------------- keep-alive

  Timer? _keepAlive;

  /// How often to poke the band. Frequent enough that Android doesn't tear
  /// down an idle GATT link, rare enough not to drain the band's battery.
  static const Duration _keepAliveInterval = Duration(seconds: 30);

  // --------------------------------------------------------- active device model

  DeviceModel _activeDeviceModel = DeviceModel.v8;

  /// Call this when the user picks a different device in the picker so the
  /// correct SDK parser is used even when the dashboard page is not mounted.
  void setDeviceModel(DeviceModel model) {
    _activeDeviceModel = model;
  }

  // -------------------------------------------------------- vitals timestamps

  String heartRateTime = '';
  String oxygenLevelTime = '';
  String temperatureTime = '';

  // -------------------------------------------------------- extra vitals

  int stress = 0;
  int vascularAging = 0;

  // ------------------------------------------------------- daily step counter

  int stepsToday = 0;
  static const String _kStepBaseDate = 'step_day_date';
  static const String _kStepBaseline = 'step_day_baseline';
  static const String _kStepLastRaw  = 'step_last_raw';

  // -------------------------------------------------- sleep (dataType 26)

  /// Sleep for the current sleep day (last night — see SleepCalc.dayShift).
  /// Despite the name this is MINUTES, asleep only (deep + light + REM);
  /// the name is kept so existing callers still compile.
  double sleepHours = 0.0;

  /// Start of the first record of the current sleep day.
  String sleepDate = '';

  /// Stage minutes for the current sleep day.
  double deepSleepTime = 0;
  double lightSleepTime = 0;
  double awakeTime = 0;
  double remSleepTime = 0;

  /// One entry per device record, as last saved to `sleep_logs`.
  List<Map<String, dynamic>> mySleepTimeLog = [];

  /// One entry per sleep day, as last saved to `daily_sleep`.
  List<Map<String, dynamic>> dailySleepTimeList = [];

  /// Bumped after every sleep save so screens know to re-read.
  int sleepSyncVersion = 0;

  /// Records received since the last save, keyed by start minute so a
  /// record the band sends twice is only kept once.
  final Map<String, SleepRecord> _pendingSleep = {};
  Timer? _sleepFlushTimer;
  Future<void> _sleepSaveChain = Future.value();

  /// Save this long after the last sleep packet if dataEnd never arrives.
  static const Duration _sleepQuietPeriod = Duration(seconds: 4);

  // ------------------------------------------------- background data poll timer

  Timer? _dataPollTimer;
  bool   _dataPollBusy = false;

  // ------------------------------------------------------------ last device

  static const String _kLastDeviceKey = 'last_ble_device_id';

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _notifySub;

  void _setStatus(BleStatus s) {
    _status = s;
    notifyListeners();
  }

  // ---------------------------------------------------------------- scanning

  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (await FlutterBluePlus.isSupported == false) {
      errorMessage = 'Bluetooth not supported on this device';
      notifyListeners();
      return;
    }

    // Ask the user to switch Bluetooth on rather than throwing.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {/* user declined */}
    }

    try {
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      errorMessage = 'Bluetooth is off';
      notifyListeners();
      return;
    }

    scanResults.clear();
    _setStatus(BleStatus.scanning);

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      scanResults
        ..clear()
        ..addAll(results);
      notifyListeners();
    });

    await _isScanningSub?.cancel();
    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _status == BleStatus.scanning) {
        _setStatus(BleStatus.idle);
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        // Uncomment once you've confirmed the band advertises FFF0:
        // withServices: [BleUuids.service],
      );
    } catch (e) {
      errorMessage = 'Scan failed: $e';
      _setStatus(BleStatus.idle);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (_status == BleStatus.scanning) _setStatus(BleStatus.idle);
  }

  // ---------------------------------------------------------------- connect

  Future<void> connectDevice(BluetoothDevice device) async {
    await stopScan();

    connectedDevice = device;
    _manualDisconnect = false;
    _reconnectCount = 0;
    _setStatus(BleStatus.connecting);

    await _rememberDevice(device);

    // Replaces the vendor's stateStream switch statement.
    await _connStateSub?.cancel();
    _connStateSub = device.connectionState.listen((state) async {
      switch (state) {
        case BluetoothConnectionState.connected:
          debugPrint('device connected');
          _reconnectCount = 0; // the vendor example forgets to reset this
          _setStatus(BleStatus.connected);
          await _discoverAndSubscribe();
          await _startBackgroundKeepAlive(device);
          break;

        case BluetoothConnectionState.disconnected:
          debugPrint('device disconnected: ${device.disconnectReason}');
          _writeChar = null;
          _stopKeepAlive();
          _setStatus(BleStatus.disconnected);
          if (_manualDisconnect) {
            await BleBackgroundService.stop();
          } else {
            await BleBackgroundService.update(
                message: 'Reconnecting to your device…');
            _scheduleReconnect(device);
          }
          break;

        default:
          break;
      }
    });

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      errorMessage = 'Connect failed: $e';
      _setStatus(BleStatus.disconnected);
      if (!_manualDisconnect) _scheduleReconnect(device);
    }
  }

  /// Backs off exponentially — 2s, 4s, 8s … capped at [_maxBackoff] — and keeps
  /// trying for as long as the user hasn't explicitly disconnected.
  void _scheduleReconnect(BluetoothDevice device) {
    _reconnectTimer?.cancel();

    _reconnectCount++;
    final seconds = (1 << _reconnectCount.clamp(1, 7)).clamp(2, _maxBackoff.inSeconds);
    final delay = Duration(seconds: seconds);
    debugPrint('reconnect attempt $_reconnectCount in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () async {
      if (_manualDisconnect) return;
      try {
        await device.connect(
          license: License.nonprofit,
          timeout: const Duration(seconds: 10),
        );
      } catch (_) {
        if (!_manualDisconnect) _scheduleReconnect(device);
      }
    });
  }

  // ------------------------------------------------- discovery + notify

  Future<void> _discoverAndSubscribe() async {
    final device = connectedDevice;
    if (device == null) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await device.requestMtu(247);
      } catch (_) {/* some firmware rejects this; not fatal */}
    }

    final services = await device.discoverServices();
    debugPrint('services: ${services.map((s) => s.uuid).join(', ')}');

    BluetoothService? service;
    for (final s in services) {
      if (s.uuid == BleUuids.service) {
        service = s;
        break;
      }
    }
    if (service == null) {
      errorMessage = 'Service FFF0 not found on this device';
      notifyListeners();
      return;
    }

    BluetoothCharacteristic? notifyChar;
    for (final c in service.characteristics) {
      if (c.uuid == BleUuids.notifyChar) notifyChar = c;
      if (c.uuid == BleUuids.writeChar) _writeChar = c;
    }
    if (notifyChar == null) {
      errorMessage = 'Notify characteristic FFF7 not found';
      notifyListeners();
      return;
    }

    // setNotifyValue writes the 2902 CCCD for you — no manual descriptor write.
    await notifyChar.setNotifyValue(true);

    await _notifySub?.cancel();
    _notifySub = notifyChar.onValueReceived.listen(
      _handlePacket,
      onError: (e) => debugPrint('notify error: $e'),
    );
    device.cancelWhenDisconnected(_notifySub!);

    notifyListeners();
    unawaited(syncStoredHistory());
  }

  /// One BLE notification == one complete frame for this SDK, so the payload
  /// goes straight into the parser with no buffering.
  void _handlePacket(List<int> rawData) {
    if (rawData.isEmpty) return;

    try {
      final Map map = MsBleDataAnalysis.dataParsingWithData(
        rawData,
        model: _activeDeviceModel,
      );
      if (map.isEmpty) return;

      lastResult = map;
      debugPrint('parsed: $map');

      if (!_dataController.isClosed) _dataController.add(map);
      if (!_rawController.isClosed) _rawController.add(rawData);

      _applyFrame(map);
      _applyDashboardData(map);
      _ingestHistoryFrame(map);
      _maybePersistLiveSnapshot();

      lastUpdate = DateTime.now();
      notifyListeners();
    } catch (e, st) {
      debugPrint('parse failed: $e\n$st');
    }
  }

  /// Pulls every value the dashboard shows out of one parsed frame.
  ///
  /// A frame only carries the fields the band chose to send, so each read is
  /// independent and a null just means "not in this frame" — never "reset".
  void _applyFrame(Map map) {
    final hr = _readInt(map, known: DeviceKey.heartRate, aliases: const [
      'heartrate',
      'heart_rate',
    ]);
    if (VitalsValidator.isValidHr(hr)) {
      heartRate = hr;
      hrHistory.add(hr!.toDouble());
    }

    final step = _readInt(map, known: DeviceKey.step, aliases: const ['step']);
    if (step != null && step >= 0) {
      steps = step;
      stepsHistory.add(step.toDouble());
    }

    final spo2 = _readInt(map, aliases: const [
      'bloodoxygen',
      'blood_oxygen',
      'oxygen',
      'spo2',
    ]);
    if (VitalsValidator.isValidSpo2(spo2)) {
      bloodOxygen = spo2;
      spo2History.add(spo2!.toDouble());
    }

    // Temperature and blood sugar are decimals — reading them as ints would
    // turn 36.6 °C into 36.
    final temp = _readDouble(map, aliases: const [
      'temperature',
      'temp',
    ]);
    if (temp != null && temp > 0) {
      final celsius = temp / 10;
      if (VitalsValidator.isValidTemp(celsius)) {
        temperature = celsius;
        temperatureHistory.add(celsius);
      }
    }

    final sugar = _readDouble(map, aliases: const [
      'bloodsugar',
      'blood_sugar',
      'bloodglucose',
      'glucose',
    ]);
    if (sugar != null && sugar > 0) {
      bloodSugar = sugar;
      bloodSugarHistory.add(sugar);
    }

    batteryLevel =
        _readInt(map, aliases: const ['battery']) ?? batteryLevel;
    calories = _readInt(map, aliases: const ['calor', 'kcal']) ?? calories;
    distanceMetres =
        _readInt(map, aliases: const ['distance']) ?? distanceMetres;

    // Sleep arrives as a nightly summary rather than a live stream.
    deepSleepMinutes =
        _readInt(map, aliases: const ['deepsleep', 'deep_sleep']) ??
            deepSleepMinutes;
    remSleepMinutes =
        _readInt(map, aliases: const ['remsleep', 'rem_sleep']) ??
            remSleepMinutes;
    lightSleepMinutes =
        _readInt(map, aliases: const ['lightsleep', 'light_sleep']) ??
            lightSleepMinutes;
    awakeMinutes =
        _readInt(map, aliases: const ['awake', 'sober']) ?? awakeMinutes;
    sleepTotalMinutes = _readInt(map, aliases: const [
          'sleeptotal',
          'totalsleep',
          'sleepduration',
          'allsleep',
        ]) ??
        _derivedSleepTotal() ??
        sleepTotalMinutes;
    sleepScore =
        _readInt(map, aliases: const ['sleepscore', 'sleepquality']) ??
            sleepScore;
  }

  /// Falls back to summing the stages when the band doesn't send a total.
  /// Awake time is excluded — it's time in bed, not time asleep.
  int? _derivedSleepTotal() {
    final deep = deepSleepMinutes;
    final rem = remSleepMinutes;
    final light = lightSleepMinutes;
    if (deep == null && rem == null && light == null) return null;
    return (deep ?? 0) + (rem ?? 0) + (light ?? 0);
  }

  // -------------------------------------------------------- dashboard data layer

  /// Handles fields that the generic [_applyFrame] key-alias scan doesn't cover:
  /// timestamps, stress/vascularAging from HRV frames, daily step delta, and
  /// sleep-detail accumulation.  Called on every BLE notification so it runs
  /// regardless of which page the user is on.
  void _applyDashboardData(Map map) {
    final now     = DateTime.now();
    final typeStr = map[DeviceKey.dataType]?.toString() ?? '';
    final dicData = map['dicData'];

    // ── timestamps ──────────────────────────────────────────────────────────
    if ((heartRate ?? 0) > 0)    heartRateTime    = now.toIso8601String();
    if ((bloodOxygen ?? 0) > 0)  oxygenLevelTime  = now.toIso8601String();
    if ((temperature ?? 0) > 0)  temperatureTime  = now.toIso8601String();

    // ── stress + vascular aging from HRV array (dataType 42) ────────────────
    if (typeStr == '42' && dicData is List) {
      for (int i = dicData.length - 1; i >= 0; i--) {
        final item = dicData[i];
        if (item is! Map) continue;
        final s = _toInt(item['stress']);
        final v = _toInt(item['vascularAging']);
        if (s != null) stress         = s;
        if (v != null) vascularAging  = v;
        break;
      }
    }

    // ── daily step delta (dataType 23) ───────────────────────────────────────
    if (typeStr == '23' && dicData is Map) {
      final raw = _toInt(dicData['step']);
      if (raw != null) unawaited(_processSteps(raw));
    }

    // ── sleep history (dataType 26) ──────────────────────────────────────────
    // The final packet is {dataEnd: true, dicData: []}, so this must run even
    // when dicData is empty — that packet is what triggers the save.
    if (typeStr == '26') {
      _collectSleep(map, dicData);
    }
  }

  // ─────────────────────────────────────────────── sleep history (type 26)

  /// Buffers each record as it arrives. Saves when the band sends dataEnd,
  /// or after [_sleepQuietPeriod] with no new sleep packet.
  void _collectSleep(Map map, Object? dicData) {
    if (dicData is List) {
      for (final entry in dicData) {
        if (entry is! Map) continue;
        final record = SleepRecord.fromDevice(entry);
        if (record == null) {
          debugPrint('sleep: skipped record, date="${entry['date']}"');
          continue;
        }
        _pendingSleep.putIfAbsent(record.id, () => record);
      }
    }

    _sleepFlushTimer?.cancel();
    final end = map[DeviceKey.end] ?? map['dataEnd'];
    if (end == true || end?.toString() == 'true') {
      unawaited(_flushSleep());
    } else {
      _sleepFlushTimer = Timer(_sleepQuietPeriod, () => unawaited(_flushSleep()));
    }
  }

  /// Saves the buffered records. Saves are queued one after another, so two
  /// syncs never interleave their Firestore reads and writes.
  Future<void> _flushSleep() {
    _sleepFlushTimer?.cancel();
    _sleepFlushTimer = null;
    if (_pendingSleep.isNotEmpty) {
      final batch = _pendingSleep.values.toList();
      _pendingSleep.clear();
      _sleepSaveChain = _sleepSaveChain.then((_) => _saveSleep(batch));
    }
    return _sleepSaveChain;
  }

  Future<void> _saveSleep(List<SleepRecord> incoming) async {
    final days = incoming.map((r) => r.sleepDay).toSet();
    final results = <SleepDay>[];
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        final db = FirebaseFirestore.instance;
        final logs = db.collection('sleep_logs');

        // 1. One sleep_logs doc per record. The id comes from the record's
        //    start minute, so a resend overwrites itself instead of adding
        //    a duplicate.
        for (var i = 0; i < incoming.length; i += 400) {
          final batch = db.batch();
          for (final r in incoming.skip(i).take(400)) {
            batch.set(logs.doc('${user.uid}_${r.id}'), r.toFirestore(user.uid));
          }
          await batch.commit();
        }

        // 2. Rebuild each affected day from every record stored for it, so a
        //    night pulled over several syncs is still counted exactly once.
        for (final day in days) {
          final snap = await logs
              .where('userId', isEqualTo: user.uid)
              .where('sleepDay', isEqualTo: day)
              .get();
          final stored = snap.docs
              .map((d) => SleepRecord.fromFirestore(d.data()))
              .whereType<SleepRecord>();
          final sleepDay = SleepDay.build(day, [...stored, ...incoming.where((r) => r.sleepDay == day)]);
          await _writeDailySleep(user.uid, sleepDay);
          results.add(sleepDay);
        }
      }
    } catch (e, st) {
      debugPrint('sleep save failed: $e\n$st');
      results.clear();
    }

    // Signed out or offline failure: still show what this sync received.
    if (results.isEmpty) {
      for (final day in days) {
        results.add(SleepDay.build(day, incoming.where((r) => r.sleepDay == day)));
      }
    }

    _applySleepResults(incoming, results);
  }

  /// Writes one daily_sleep doc per user per day, replacing the previous one.
  Future<void> _writeDailySleep(String uid, SleepDay day) async {
    final col = FirebaseFirestore.instance.collection('daily_sleep');
    final id = '${uid}_${day.day}';
    await col.doc(id).set(day.toFirestore(uid));

    // The old code created daily_sleep docs with random ids and inflated
    // totals. Remove them so the dashboard can't read one instead of this.
    final legacy = await col
        .where('userId', isEqualTo: uid)
        .where('date', isEqualTo: day.day)
        .get();
    for (final d in legacy.docs) {
      if (d.id != id) await d.reference.delete();
    }
  }

  void _applySleepResults(List<SleepRecord> records, List<SleepDay> days) {
    for (final r in records) {
      mySleepTimeLog.removeWhere((m) => m['id'] == r.id);
      mySleepTimeLog.add({
        'id': r.id,
        'date': r.start.toIso8601String(),
        'endDate': r.end.toIso8601String(),
        'sleepDay': r.sleepDay,
        ...r.totals.toMap(),
      });
    }
    mySleepTimeLog
        .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    for (final d in days) {
      dailySleepTimeList.removeWhere((m) => m['date'] == d.day);
      dailySleepTimeList.add({'date': d.day, ...d.totals.toMap()});
    }
    dailySleepTimeList
        .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    final today = SleepCalc.sleepDayKey(DateTime.now());
    for (final d in days) {
      if (d.day != today) continue;
      final t = d.totals;
      sleepHours = t.sleep.toDouble();
      deepSleepTime = t.deep.toDouble();
      lightSleepTime = t.light.toDouble();
      remSleepTime = t.rem.toDouble();
      awakeTime = t.awake.toDouble();
      sleepDate = (d.start ?? DateTime.now()).toIso8601String();

      sleepTotalMinutes = t.sleep;
      deepSleepMinutes = t.deep;
      lightSleepMinutes = t.light;
      remSleepMinutes = t.rem;
      awakeMinutes = t.awake;
    }

    for (final d in days) {
      debugPrint('sleep ${d.day}: ${d.totals}');
    }

    sleepSyncVersion++;
    notifyListeners();
  }

  /// Clears the in-memory sleep state. Firestore is not touched.
  void resetSleepAccumulation() {
    _sleepFlushTimer?.cancel();
    _sleepFlushTimer = null;
    _pendingSleep.clear();
    sleepHours = 0;
    deepSleepTime = 0;
    lightSleepTime = 0;
    awakeTime = 0;
    remSleepTime = 0;
    sleepDate = DateTime.now().toIso8601String();
    mySleepTimeLog.clear();
    dailySleepTimeList.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────── steps-today (daily delta)

  Future<void> _processSteps(int rawSteps) async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final today    = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
      final savedDate     = prefs.getString(_kStepBaseDate);
      final savedBaseline = prefs.getInt(_kStepBaseline);

      int baseline;
      if (savedDate != todayStr || savedBaseline == null) {
        baseline = rawSteps;
        await prefs.setString(_kStepBaseDate, todayStr);
        await prefs.setInt(_kStepBaseline, baseline);
      } else {
        baseline = savedBaseline;
        if (rawSteps < baseline) {
          baseline = rawSteps;
          await prefs.setInt(_kStepBaseline, baseline);
        }
      }

      stepsToday = rawSteps - baseline;
      await prefs.setInt(_kStepLastRaw, rawSteps);
      unawaited(_saveDailySteps(todayStr, stepsToday));
      notifyListeners();
    } catch (e) {
      debugPrint('_processSteps error: $e');
    }
  }

  Future<void> _saveDailySteps(String date, int steps) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('daily_steps')
          .where('userId', isEqualTo: user.uid)
          .where('date',   isEqualTo: date)
          .get();
      if (snap.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('daily_steps').add({
          'userId': user.uid,
          'date':   date,
          'steps':  steps,
        });
      } else {
        await snap.docs.first.reference.update({'steps': steps});
      }
    } catch (e) {
      debugPrint('_saveDailySteps error: $e');
    }
  }

  /// Restores the "steps today" counter from SharedPreferences so the UI is
  /// not blank before the first BLE poll after a cold start.
  Future<void> loadInitialSteps() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final today    = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
      final savedDate     = prefs.getString(_kStepBaseDate);
      final savedBaseline = prefs.getInt(_kStepBaseline);
      final savedLast     = prefs.getInt(_kStepLastRaw);
      if (savedDate == todayStr && savedBaseline != null && savedLast != null) {
        stepsToday = (savedLast - savedBaseline).clamp(0, 1 << 30);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadInitialSteps error: $e');
    }
  }

  // ─────────────────────────────────────────────────── Firestore save

  /// Saves all current vitals to Firestore.  Called automatically by the
  /// background poll cycle, and also from the on-demand measurement flow.
  /// Runs regardless of which page the user is on.
  Future<void> saveAllDataToServer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Only write a document when at least one validated vital is present.
    // This prevents storing frames that carried nothing but device artefacts.
    final hasVitals = VitalsValidator.isValidHr(heartRate) ||
        VitalsValidator.isValidSpo2(bloodOxygen) ||
        VitalsValidator.isValidTemp(temperature);
    if (!hasVitals) return;

    try {
      final _now = DateTime.now();
      final _dateKey = '${_now.year.toString().padLeft(4,'0')}-'
          '${_now.month.toString().padLeft(2,'0')}-'
          '${_now.day.toString().padLeft(2,'0')}';
      await _addDoc('my_device_vitals', {
        'userId':          user.uid,
        // Date-only key lets the Readiness Index query deduplicate by day.
        'date':            _dateKey,
        if (VitalsValidator.isValidHr(heartRate)) ...{
          'heartRate':     heartRate!,
          'heartRateTime': heartRateTime,
          'hrv':           VitalsValidator.isValidHrv(hrv) ? hrv! : 0,
        },
        if (VitalsValidator.isValidSpo2(bloodOxygen)) ...{
          'oxygenLevel':     bloodOxygen!,
          'oxygenLevelTime': oxygenLevelTime,
        },
        'stepsTaken':      stepsToday,
        'calories':        calories        ?? 0,
        'distance':        distanceMetres  ?? 0,
        'exerciseTime':    0,
        'exerciseMinutes': 0,
        if (VitalsValidator.isValidTemp(temperature)) ...{
          'temperature':     temperature!,
          'temperatureTime': temperatureTime,
        },
      });
      // sleep_logs and daily_sleep are written by _saveSleep as soon as a
      // sleep sync finishes, not here.
    } catch (e) {
      debugPrint('saveAllDataToServer error: $e');
    }
  }

  Future<void> _addDoc(String collection, Map<String, dynamic> data) =>
      FirebaseFirestore.instance.collection(collection).add(data);

  // ──────────────────────────────────────────── 20-minute background poll

  /// Runs a full data collection cycle: steps → heart rate → SPO2 → sleep detail.
  /// Called on every timer tick so all vitals are refreshed together.
  Future<void> _runDataPoll() async {
    if (!isConnected || _dataPollBusy) return;
    _dataPollBusy = true;
    try {
      // Steps
      await writeData(MsBleDataAnalysis.realTimeStep(true));
      await Future.delayed(const Duration(seconds: 2));

      if (!isConnected) return;

      // Heart rate — device needs ~30 s to complete the measurement
      await writeData(MsBleDataAnalysis.healthMeasurementWithDataType(2, false));
      await Future.delayed(const Duration(seconds: 32));

      if (!isConnected) return;

      // SPO2 / blood oxygen — same measurement window
      await writeData(MsBleDataAnalysis.healthMeasurementWithDataType(3, false));
      await Future.delayed(const Duration(seconds: 32));

      if (!isConnected) return;

      // Sleep detail. Records arrive one packet at a time; _collectSleep
      // saves them when dataEnd arrives (or after a quiet period). Wait for
      // that save so the vitals doc below carries this sync's sleep.
      await writeData(MsBleDataAnalysis.getDetailSleepDataWithMode(1));
      await Future.delayed(_sleepQuietPeriod + const Duration(seconds: 2));
      await _flushSleep();

      unawaited(saveAllDataToServer());
    } catch (e) {
      debugPrint('_runDataPoll error: $e');
    } finally {
      _dataPollBusy = false;
    }
  }

  /// Live values for the AI report. Included even if the band just dropped,
  /// as long as this process still holds a reading.
  Map<String, dynamic>? liveSnapshot() {
    final snapshot = <String, dynamic>{
      if (heartRate != null) 'heartRate': heartRate,
      if (hrv != null) 'hrv': hrv,
      if (highBp != null) 'deviceSys': highBp,
      if (lowBp != null) 'deviceDia': lowBp,
      if (bloodOxygen != null) 'bloodOxygen': bloodOxygen,
      if (steps != null) 'steps': steps,
      if (temperature != null) 'temperatureC': temperature,
      if (bloodSugar != null) 'bloodSugar': bloodSugar,
      if (sleepTotalMinutes != null) 'sleepTotalMinutes': sleepTotalMinutes,
      if (deepSleepMinutes != null) 'deepSleepMinutes': deepSleepMinutes,
      if (lightSleepMinutes != null) 'lightSleepMinutes': lightSleepMinutes,
      if (remSleepMinutes != null) 'remSleepMinutes': remSleepMinutes,
      if (calories != null) 'calories': calories,
      if (lastUpdate != null)
        'lastUpdate': lastUpdate!.toIso8601String(),
      'connectedNow': isConnected,
    };
    if (snapshot.length <= 1) return null;
    return snapshot;
  }

  List<DeviceReading> sessionReadingsInRange({
    required DateTime start,
    required DateTime end,
  }) {
    final out = <DeviceReading>[];
    void addSeries(VitalSeries series, DeviceReading Function(VitalSample s) map) {
      for (final sample in series.samples) {
        if (sample.time.isBefore(start) || sample.time.isAfter(end)) continue;
        if (sample.value <= 0) continue;
        out.add(map(sample));
      }
    }

    addSeries(
      hrHistory,
      (s) => DeviceReading(
        type: 'heartRate',
        time: s.time.millisecondsSinceEpoch,
        heartRate: s.value.round(),
      ),
    );
    addSeries(
      spo2History,
      (s) => DeviceReading(
        type: 'spo2',
        time: s.time.millisecondsSinceEpoch,
        spo2: s.value.round(),
      ),
    );
    addSeries(
      stepsHistory,
      (s) => DeviceReading(
        type: 'activity',
        time: s.time.millisecondsSinceEpoch,
        steps: s.value.round(),
      ),
    );
    addSeries(
      temperatureHistory,
      (s) => DeviceReading(
        type: 'temperature',
        time: s.time.millisecondsSinceEpoch,
        temperature: s.value,
      ),
    );
    addSeries(
      bloodSugarHistory,
      (s) => DeviceReading(
        type: 'bloodSugar',
        time: s.time.millisecondsSinceEpoch,
        bloodSugar: s.value,
      ),
    );
    return out;
  }

  /// Pulls stored history off the band (HRV/BP, HR, SpO2, steps, sleep, temp).
  /// Safe to call from Ask Now; no-ops if already running or disconnected.
  Future<void> syncStoredHistory({
    Duration timeout = const Duration(seconds: 12),
  }) {
    if (!isConnected) return Future.value();
    return _historySyncJob ??= _runHistorySync(timeout).whenComplete(() {
      _historySyncJob = null;
    });
  }

  Future<void> _runHistorySync(Duration timeout) async {
    _historyPulls
      ..clear()
      ..[BleConst.getHrvData] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getHRVDataWithMode(mode),
      )
      ..[BleConst.getDynamicHr] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getDynamicHRWithMode(mode),
      )
      ..[BleConst.getStaticHr] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getStaticHRWithMode(mode),
      )
      ..[BleConst.bloodOxygen] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getBloodOxygen(mode),
      )
      ..[BleConst.getTotalActivityData] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getTotalActivityDataWithMode(mode),
      )
      ..[BleConst.getDetailSleepData] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getDetailSleepDataWithMode(mode),
      )
      ..[BleConst.temperatureHistory] = _HistoryPull(
        (mode) => MsBleDataAnalysis.getTemperature_historyDataWithMode(mode),
      );

    for (final pull in _historyPulls.values) {
      if (!isConnected) break;
      await writeData(pull.command(0));
      await Future.delayed(const Duration(milliseconds: 250));
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) && isConnected) {
      if (_historyPulls.values.every((p) => p.done)) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _historyPulls.clear();
  }

  void _ingestHistoryFrame(Map map) {
    final type = map[DeviceKey.dataType]?.toString();
    final payload = map[DeviceKey.data];
    final ended = map[DeviceKey.end] == true;

    final items = <Map>[];
    if (payload is List) {
      for (final item in payload) {
        if (item is Map) items.add(item);
      }
    } else if (payload is Map && payload[DeviceKey.date] != null) {
      items.add(payload);
    }

    if (items.isNotEmpty) {
      final readings = <DeviceReading>[];
      for (final item in items) {
        readings.addAll(_readingsFromHistoryItem(type, item));
      }
      _applyLatestFromHistory(type, items);
      if (readings.isNotEmpty) {
        unawaited(DeviceHistoryService.persist(readings));
      }
    }

    _continueHistoryIfNeeded(type, ended, items.length);
  }

  void _continueHistoryIfNeeded(String? type, bool ended, int itemCount) {
    if (type == null) return;
    final pull = _historyPulls[type];
    if (pull == null) return;
    pull.packets += 1;
    if (ended || itemCount == 0) {
      pull.done = true;
      return;
    }
    if (pull.packets % 50 == 0 && !pull.done) {
      unawaited(writeData(pull.command(2)));
    }
  }

  void _applyLatestFromHistory(String? type, List<Map> items) {
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      if (type == BleConst.getHrvData) {
        final hr = _toInt(item[DeviceKey.heartRate]);
        if (!VitalsValidator.isValidHr(hr)) continue;
        heartRate = hr;
        hrHistory.add(hr!.toDouble());
        final newHrv = VitalsValidator.sanitizeHrv(_toInt(item[DeviceKey.hrv]));
        if (newHrv != null) hrv = newHrv;
        final newSys = VitalsValidator.sanitizeSysBp(_toInt(item[DeviceKey.highBP]));
        if (newSys != null) highBp = newSys;
        final newDia = VitalsValidator.sanitizeDiaBp(_toInt(item[DeviceKey.lowBP]));
        if (newDia != null) lowBp = newDia;
        return;
      }
      if (type == BleConst.bloodOxygen || type == BleConst.autoBloodOxygen) {
        final spo2 = _toInt(item[DeviceKey.bloodOxygen]);
        if (!VitalsValidator.isValidSpo2(spo2)) continue;
        bloodOxygen = spo2;
        spo2History.add(spo2!.toDouble());
        return;
      }
      if (type == BleConst.getTotalActivityData) {
        final step = _toInt(item[DeviceKey.step]);
        if (step == null) continue;
        steps = step;
        stepsHistory.add(step.toDouble());
        return;
      }
      if (type == BleConst.getStaticHr) {
        final hr = _toInt(item[DeviceKey.staticHR]) ?? _toInt(item[DeviceKey.heartRate]);
        if (!VitalsValidator.isValidHr(hr)) continue;
        heartRate = hr;
        hrHistory.add(hr!.toDouble());
        return;
      }
    }
  }

  List<DeviceReading> _readingsFromHistoryItem(String? type, Map item) {
    final dateStr = item[DeviceKey.date]?.toString();
    final parsed = DeviceHistoryService.parseDeviceTime(dateStr);
    if (parsed == null) return const [];
    final time = parsed.millisecondsSinceEpoch;

    switch (type) {
      case BleConst.getHrvData:
        return [
          DeviceReading(
            type: 'hrv',
            time: time,
            date: dateStr,
            heartRate: _toInt(item[DeviceKey.heartRate]),
            hrv: _toInt(item[DeviceKey.hrv]),
            sys: _toInt(item[DeviceKey.highBP]),
            dia: _toInt(item[DeviceKey.lowBP]),
            stress: _toInt(item[DeviceKey.stress]),
          ),
        ];
      case BleConst.bloodOxygen:
      case BleConst.autoBloodOxygen:
        return [
          DeviceReading(
            type: 'spo2',
            time: time,
            date: dateStr,
            spo2: _toInt(item[DeviceKey.bloodOxygen]),
          ),
        ];
      case BleConst.getTotalActivityData:
        return [
          DeviceReading(
            type: 'activity',
            time: time,
            date: dateStr,
            steps: _toInt(item[DeviceKey.step]),
            calories: _toDouble(item[DeviceKey.calories]),
            distance: _toDouble(item[DeviceKey.distance]),
          ),
        ];
      case BleConst.getDynamicHr:
        final values = item[DeviceKey.arrayDynamicHR]
                ?.toString()
                .split(RegExp(r'\s+'))
                .map(_toInt)
                .whereType<int>()
                .where((v) => v > 0)
                .toList() ??
            const <int>[];
        if (values.isEmpty) return const [];
        final avg = values.reduce((a, b) => a + b) / values.length;
        return [
          DeviceReading(
            type: 'heartRate',
            time: time,
            date: dateStr,
            heartRate: avg.round(),
          ),
        ];
      case BleConst.getStaticHr:
        return [
          DeviceReading(
            type: 'heartRate',
            time: time,
            date: dateStr,
            heartRate: _toInt(item[DeviceKey.staticHR]) ??
                _toInt(item[DeviceKey.heartRate]),
          ),
        ];
      case BleConst.getDetailSleepData:
        final record =
            SleepRecord.fromDevice(item, valuesKey: DeviceKey.arraySleep);
        if (record == null) return const [];
        return [
          DeviceReading(
            type: 'sleep',
            time: time,
            date: dateStr,
            // Asleep only — every value used to be counted, awake included.
            sleepMinutes: record.totals.sleep,
          ),
        ];
      case BleConst.temperatureHistory:
      case BleConst.getAxillaryTemperatureDataWithMode:
        return [
          DeviceReading(
            type: 'temperature',
            time: time,
            date: dateStr,
            temperature: _toDouble(item[DeviceKey.temperature]) ??
                _toDouble(item[DeviceKey.axillaryTemperature]),
          ),
        ];
      default:
        return const [];
    }
  }

  void _maybePersistLiveSnapshot() {
    final now = DateTime.now();
    if (_lastLivePersist != null &&
        now.difference(_lastLivePersist!) < const Duration(minutes: 10)) {
      return;
    }
    if ((heartRate ?? 0) <= 0 &&
        (bloodOxygen ?? 0) <= 0 &&
        (steps ?? 0) <= 0 &&
        (sleepTotalMinutes ?? 0) <= 0) {
      return;
    }
    _lastLivePersist = now;
    unawaited(DeviceHistoryService.persist([
      DeviceReading(
        type: 'hrv',
        time: now.millisecondsSinceEpoch,
        heartRate: heartRate,
        hrv: hrv,
        sys: highBp,
        dia: lowBp,
      ),
      DeviceReading(
        type: 'spo2',
        time: now.millisecondsSinceEpoch,
        spo2: bloodOxygen,
      ),
      DeviceReading(
        type: 'activity',
        time: now.millisecondsSinceEpoch,
        steps: steps,
        calories: calories?.toDouble(),
        distance: distanceMetres == null ? null : distanceMetres! / 1000,
      ),
      if ((sleepTotalMinutes ?? 0) > 0)
        DeviceReading(
          type: 'sleep',
          time: now.millisecondsSinceEpoch,
          sleepMinutes: sleepTotalMinutes,
        ),
      if ((temperature ?? 0) > 0)
        DeviceReading(
          type: 'temperature',
          time: now.millisecondsSinceEpoch,
          temperature: temperature,
        ),
      if ((bloodSugar ?? 0) > 0)
        DeviceReading(
          type: 'bloodSugar',
          time: now.millisecondsSinceEpoch,
          bloodSugar: bloodSugar,
        ),
    ]));
  }

  /// Reads an int out of a parsed frame.
  ///
  /// [known] is the SDK constant where we're confident it exists; [aliases] are
  /// lower-case fragments matched against the key's string form. The SDK's key
  /// set varies between firmware revisions and the package is pulled from a git
  /// ref rather than vendored, so alias matching keeps an unrecognised key a
  /// no-op instead of a crash.
  /// Command responses nest their payload under a `data` sub-map (see the
  /// getDeviceInfo branch in DeviceInformationPage), so this searches nested
  /// maps too, with a depth guard against a self-referential frame.
  int? _readInt(
    Map map, {
    Object? known,
    List<String> aliases = const [],
    int depth = 0,
  }) {
    if (known != null && map.containsKey(known)) {
      final parsed = _toInt(map[known]);
      if (parsed != null) return parsed;
    }

    for (final entry in map.entries) {
      final name = entry.key.toString().toLowerCase();
      for (final alias in aliases) {
        if (name.contains(alias)) {
          final parsed = _toInt(entry.value);
          if (parsed != null) return parsed;
        }
      }
    }

    if (depth >= 3) return null;
    for (final value in map.values) {
      if (value is Map) {
        final parsed = _readInt(
          value,
          known: known,
          aliases: aliases,
          depth: depth + 1,
        );
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Decimal counterpart of [_readInt], for readings the band sends with a
  /// fractional part.
  double? _readDouble(
    Map map, {
    Object? known,
    List<String> aliases = const [],
    int depth = 0,
  }) {
    if (known != null && map.containsKey(known)) {
      final parsed = _toDouble(map[known]);
      if (parsed != null) return parsed;
    }

    for (final entry in map.entries) {
      final name = entry.key.toString().toLowerCase();
      for (final alias in aliases) {
        if (name.contains(alias)) {
          final parsed = _toDouble(entry.value);
          if (parsed != null) return parsed;
        }
      }
    }

    if (depth >= 3) return null;
    for (final value in map.values) {
      if (value is Map) {
        final parsed = _readDouble(
          value,
          known: known,
          aliases: aliases,
          depth: depth + 1,
        );
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static double? _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // ------------------------------------------------- background keep-alive

  Future<void> _startBackgroundKeepAlive(BluetoothDevice device) async {
    final name = device.platformName.isNotEmpty ? device.platformName : 'device';
    await BleBackgroundService.start(message: 'Reading from $name');
    _stopKeepAlive();
    _keepAlive = Timer.periodic(_keepAliveInterval, (_) => _poll());
    _poll();
    // Start the 20-minute data poll.  This continues even when the dashboard
    // page is not mounted, stopping only when the device disconnects or the
    // app process exits.
    _dataPollTimer?.cancel();
    _dataPollTimer = Timer.periodic(
      const Duration(minutes: 35),
      (_) => unawaited(_runDataPoll()),
    );
    unawaited(_runDataPoll()); // immediate first poll on connect
  }

  void _stopKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = null;
    _dataPollTimer?.cancel();
    _dataPollTimer = null;
  }

  /// Asks the band for a fresh frame now, rather than waiting for the next
  /// keep-alive tick. Wired to the dashboard's Measure button.
  Future<void> requestRefresh() => _poll();

  /// Pokes the band so Android doesn't tear down an idle GATT link, and
  /// refreshes the battery reading as a side effect.
  ///
  /// If the SDK exposes a live heart rate or SpO2 command for the V8, issue it
  /// here as well — the response arrives through the same notify stream and
  /// gets parsed by [_applyFrame] with no extra wiring.
  Future<void> _poll() async {
    if (!isConnected) return;
    try {
      await writeData(MsBleDataAnalysis.getDeviceBatteryLevel());
    } catch (e) {
      debugPrint('keep-alive poll failed: $e');
    }
  }

  // ------------------------------------------------------- device memory

  Future<void> _rememberDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastDeviceKey, device.remoteId.str);
    } catch (e) {
      debugPrint('could not remember device: $e');
    }
  }

  Future<void> _forgetDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastDeviceKey);
    } catch (e) {
      debugPrint('could not forget device: $e');
    }
  }

  /// Reconnects to the last device the user paired, without scanning.
  ///
  /// Called on app start and whenever the app returns to the foreground, so a
  /// process death or a walk out of range recovers on its own.
  Future<void> reconnectLastDevice() async {
    if (isConnected || _status == BleStatus.connecting) return;

    String? id;
    try {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString(_kLastDeviceKey);
    } catch (e) {
      debugPrint('could not read last device: $e');
    }
    if (id == null || id.isEmpty) return;

    if (await FlutterBluePlus.isSupported == false) return;
    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) return;

    await connectDevice(BluetoothDevice.fromId(id));
  }

  // ---------------------------------------------------------------- writing

  /// Single write. Awaiting completion replaces the vendor's ACK handshake:
  /// their `characteristicsWrite` signal with data[0] == 0 was just the
  /// platform's write-success callback, which `await write()` already gives us.
  Future<void> writeData(List<int> data) async {
    final c = _writeChar;
    if (c == null || !isConnected) {
      errorMessage = 'Device not connected';
      notifyListeners();
      return;
    }
    try {
      await c.write(data, withoutResponse: false);
    } catch (e) {
      errorMessage = 'Write failed: $e';
      notifyListeners();
    }
  }

  /// Sequential chunked write for payloads larger than one MTU.
  /// Replaces offerData / offerValue / _nextQueue and the LinkedList queue.
  Future<void> writeLongData(List<int> data) async {
    final device = connectedDevice;
    if (_writeChar == null || device == null || !isConnected) {
      errorMessage = 'Device not connected';
      notifyListeners();
      return;
    }

    final chunkSize = (device.mtuNow - 3).clamp(20, 512);
    for (var i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      await writeData(data.sublist(i, end));
    }
  }

  // ------------------------------------------------------------- teardown

  Future<void> disconnectDevice() async {
    _manualDisconnect = true;
    _reconnectCount = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopKeepAlive();

    await _notifySub?.cancel();
    _notifySub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;

    try {
      await connectedDevice?.disconnect();
    } catch (_) {}

    connectedDevice = null;
    _writeChar = null;

    await _forgetDevice();
    await BleBackgroundService.stop();

    _setStatus(BleStatus.idle);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _connStateSub?.cancel();
    _notifySub?.cancel();
    _reconnectTimer?.cancel();
    _sleepFlushTimer?.cancel();
    _stopKeepAlive(); // also cancels _dataPollTimer
    _dataController.close();
    _rawController.close();
    BleBackgroundService.stop();
    super.dispose();
  }
}

class _HistoryPull {
  _HistoryPull(this.command);

  final List<int> Function(int mode) command;
  int packets = 0;
  bool done = false;
}