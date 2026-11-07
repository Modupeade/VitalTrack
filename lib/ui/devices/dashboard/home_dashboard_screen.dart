import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ms_ble_data_analysis/device_key.dart';

import 'package:ms_ble_data_analysis/ms_ble_data_analysis.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitals_10/ui/devices/dashboard/components/device_picker.dart';
import 'package:vitals_10/ui/devices/dashboard/components/measure_loading_dialog.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/measure_type.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';
import 'package:vitals_10/ui/devices/dashboard/pages/about_page.dart';
import 'package:vitals_10/ui/devices/dashboard/pages/exercise_page.dart';
import 'package:vitals_10/ui/devices/dashboard/pages/health_page.dart';
import 'package:vitals_10/ui/devices/dashboard/pages/home_page.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';
import 'package:vitals_10/utils/event_bus.dart';
import 'package:vitals_10/utils/readiness_calc.dart';
import 'package:vitals_10/utils/sleep_calc.dart';
import 'package:intl/intl.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceHomeDashboardScreen extends StatefulWidget {
  const DeviceHomeDashboardScreen({super.key});

  @override
  State<DeviceHomeDashboardScreen> createState() =>
      _DeviceHomeDashboardScreenState();
}

class _DeviceHomeDashboardScreenState
    extends State<DeviceHomeDashboardScreen> {
  // ── constants ──────────────────────────────────────────────────────────────
  static const int    _stepsGoal       = 10000;
  static const String _kFilterKey      = 'scan_filter';
  static const String _kDeviceModelKey = 'device_model';
  static const String _dash            = '--';

  bool isDeviceBusy = false;

  // ── BLE polling (timer now lives in BluetoothScanModel) ───────────────────

  StreamSubscription<List<int>>?        _rawSub;
  StreamSubscription<QuerySnapshot>?    _vitalsListenerSub;
  final List<List<int>> _frames = [];

  // ── model listener ─────────────────────────────────────────────────────────
  BluetoothScanModel? _model;
  BleStatus?          _lastStatus;
  bool                _pickerOpen = false;

  // ── UI state ───────────────────────────────────────────────────────────────
  int    _navIndex   = 0;
  DateTime _selectedDate = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _filter     = '';
  final  TextEditingController _filterController = TextEditingController();

  int measuringDataType = 1;  // 1: heart rate , 2: oxygen

  String  _deviceModel = 'V8';

  bool    _permissionsReady = false;
  String? _permissionError;

  // ── vitals (filled by _handlePacket) ──────────────────────────────────────

  
  int    heartRate   = 0;
  String heartRateTime = "";

  int    oxygenLevel = 0;
  String oxygenLevelTime = "";

  double temperature = 0;
  String temperatureTime = "";
  double bloodSugar  = 0;
  double calories = 0;
  double distance = 0;
  double exerciseTime = 0;
  double exerciseMinutes = 0;

  int    hrv  = 0;
  int    _readinessScore = 0;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  int    vascularAging = 0;
  int    stress = 0;
  int    highBp = 0;
  int    lowBp = 0;
  int    batteryLevel = 0;
  double sleepTime = 0;
  double deepSleepTime = 0;
  double lightSleepTime = 0;
  double awakeTime = 0;
  double remSleepTime = 0;
  String sleepTimeDate = DateTime.now().toIso8601String();
  String _sleepDayKey  = DateTime.now().toIso8601String().split('T')[0];

  // null = show live model.stepsToday; set when viewing a past date.
  int? _selectedDateSteps;

  /// Last BluetoothScanModel.sleepSyncVersion seen; a change means new sleep
  /// was saved, so the selected day is re-read from Firestore.
  int _lastSleepVersion = 0;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFilter();
    _loadDeviceModel();
    _onDateChanged(DateTime.now());
    unawaited(_computeReadiness());
    _startVitalsListener();
    final model = context.read<BluetoothScanModel>();
    unawaited(model.loadInitialSteps());
    _rawSub = model.rawStream.listen((bytes) {
      if (!mounted) return;
      _handlePacket(bytes);
      setState(() {
        _frames.insert(0, bytes);
        if (_frames.length > 100) _frames.removeLast();
      });
    }, onError: (e) => debugPrint('[dashboard] stream error: $e'));

    EventBus().on('dataCallBack', (arg) {
      Map map = arg;

      switch(map[DeviceKey.dataType] as String){
        case BleConst.measurementHrvCallback:
        debugPrint('[heart rv measurement call back   ${map.toString()}');
        break;
        case BleConst.measurementHeartCallback:
        debugPrint('[heart rate measurement call back   ${map.toString()}');
        break;
        case BleConst.measurementOxygenCallback:
        debugPrint('[oxygen rate measurement call back   ${map.toString()}');
        break;
        case BleConst.measurementTempCallback:
        debugPrint('[temp rate measurement call back   ${map.toString()}');
        break;
        case BleConst.stopMeasurementHrvCallback:
        case BleConst.stopMeasurementHeartCallback:
        case BleConst.stopMeasurementOxygenCallback:
        case BleConst.stopMeasurementTempCallback:
          // controller.showContentDialog(map.toString());
          
          debugPrint('[measurements gotten -----------------------------  ${map.toString()}');
          break;
      }

    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _initPermissions());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = context.read<BluetoothScanModel>();
    if (!identical(model, _model)) {
      _model?.removeListener(_onModelChanged);
      _model = model..addListener(_onModelChanged);
      _lastStatus = model.status;
    }
  }

  @override
  void dispose() {
    _model?.removeListener(_onModelChanged);
    _filterController.dispose();
    _rawSub?.cancel();
    _vitalsListenerSub?.cancel();
    EventBus().off('dataCallBack');
    super.dispose();
  }

  /// The band sends 2026-10-08 21:59:01 (dashes). The old parser only accepted
  /// 2026.10.08 (dots), so every date failed. This accepts both.
  DateTime? _parseDeviceDate(dynamic value) {
    final parsed = SleepCalc.parseDeviceDate(value);
    if (parsed == null && value != null) {
      debugPrint('Invalid device date: "$value"');
    }
    return parsed;
  }

  DeviceModel get _bleDeviceModel {
    switch (_deviceModel) {
      case '2208A':    return DeviceModel.v2208;
      case 'V4':       return DeviceModel.v4;
      case 'V5':       return DeviceModel.v5;
      case 'Aura V10': return DeviceModel.x3;
      default:         return DeviceModel.v8; // 'V8'
    }
  }

  void _handlePacket(List<int> bytes) {
    if (bytes.isEmpty) return;
    final Map result = MsBleDataAnalysis.dataParsingWithData(bytes, model: _bleDeviceModel);

    debugPrint('result read fro device is is : $result');
    final dataType = int.tryParse(result["dataType"]?.toString() ?? '');
    if (dataType == null) return;
    var dicData = result["dicData"];
    
    debugPrint('rdic data : $dataType');
    debugPrint('rdic data : $dicData');

   

    if(dataType == 42){
       // heart beat data
       setState(() {
           heartRate = 0;
       });
       for(int i= (dicData.length -1 ); i>=0; --i ){
          var heartBt = int.parse(dicData[i]["heartRate"]);
          var heartRv = int.parse(dicData[i]["hrv"]);
          final deviceDate = _parseDeviceDate(dicData[i]["date"]);

          if(heartBt > 0){
             setState(() {
                  heartRate = heartBt;
                  hrv = int.parse(dicData[i]["hrv"]);
                  heartRateTime =  deviceDate != null ? deviceDate.toIso8601String() : heartRateTime;
                  vascularAging = int.parse(dicData[i]["vascularAging"]);
                  stress = int.parse(dicData[i]["stress"]);
                  highBp = int.parse(dicData[i]["highBP"]);
                  lowBp = int.parse(dicData[i]["lowBP"]);
              });
              unawaited(_computeReadiness());
              break;
          }
       }
    }
    else if(dataType == 9){
       // battery level
       setState(() {
            batteryLevel = int.parse(dicData["batteryLevel"]);
       });
    }
    else if(dataType == 27){
       // not known

    }
    // dataType 26 (sleep history) is handled in BluetoothScanModel, which
    // saves it to Firestore; this screen re-reads it via _onModelChanged.
    else if(dataType == 23){

        int readSteps = int.parse(dicData["step"]);
        double readCalories = double.parse(dicData["calories"]);
        double readDistance = double.parse(dicData["distance"]);
        double readExcerciseMinutes = double.parse(dicData["exerciseMinutes"]);
        double readExceciseTime = double.parse(dicData["ExerciseTime"]);
        double readTemp = double.parse(dicData["TempData"]);

        // set the time read if these values are not zero update the read time
        DateTime now = DateTime.now();

        if(readTemp > 0){
            setState(() {
                temperatureTime = now.toIso8601String();
            });
        }

        setState(() {
            temperature = readTemp <= 0 ? temperature : readTemp;
            bloodSugar  = 0;
            calories = readCalories;
            distance = readDistance;
            exerciseTime = readExceciseTime;
            exerciseMinutes = readExcerciseMinutes;
        });
        unawaited(_computeReadiness());
    }
    else if(dataType == 64){
       // heart rate
       // {dataType: 64, dataEnd: true, dicData: {heartRate: 70}}
       setState(() {
           heartRate = 0;
       });

       var myHeartRate = dicData["heartRate"];

       if(myHeartRate > 0){
            setState(() {
                heartRate = myHeartRate;
                heartRateTime = DateTime.now().toIso8601String();
            });
        }
       
    }
    else if(dataType == 65){
       // blood oxygen
       // {dataType: 65, dataEnd: true, dicData: {Blood_oxygen: 98}}
       setState(() {
           oxygenLevel = 0;
       });
       debugPrint("this is oxygen ${dicData["Blood_oxygen"]}");
       var oxygen = dicData["Blood_oxygen"];
       if(oxygen > 0){
            setState(() {
                oxygenLevel = oxygen;
                oxygenLevelTime = DateTime.now().toIso8601String();
            });
        }
       
    }

  }



  // ── on-demand measurement ──────────────────────────────────────────────────

  Future<void> _startMeasure(MeasureType type) async {
    if (isDeviceBusy) return;
    setState(() => isDeviceBusy = true);

    final model = context.read<BluetoothScanModel>();
    if (!model.isConnected) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Connect a device first')));
      setState(() => isDeviceBusy = false);
      return;
    }

    // Complete as soon as the measurement result arrives in the model's stream.
    final completer = Completer<void>();
    final dataSub = model.dataStream.listen((map) {
      final typeStr = map['dataType']?.toString() ?? '';
      final isHr   = type == MeasureType.heartRate && typeStr == '64';
      final isSpo2 = type == MeasureType.spo2      && typeStr == '65';
      if ((isHr || isSpo2) && !completer.isCompleted) completer.complete();
    });

    try {
      await _writeMeasureCommand(type, model);
    } catch (e) {
      debugPrint('measure write failed: $e');
    }

    bool dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MeasureLoadingDialog(label: _measureLabel(type)),
    ).then((_) {
      dialogOpen = false;
      setState(() => isDeviceBusy = false);
    });

    // Fall-through timeout if the device never responds.
    final timeout = Timer(const Duration(seconds: 35), () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    timeout.cancel();
    await dataSub.cancel();

    // Stop the measurement on the device, then persist the result.
    try {
      if (type == MeasureType.heartRate) {
        await model.writeData(MsBleDataAnalysis.healthMeasurementWithDataType(2, false));
      } else if (type == MeasureType.spo2) {
        await model.writeData(MsBleDataAnalysis.healthMeasurementWithDataType(3, false));
      }
    } catch (e) {
      debugPrint('stop measure failed: $e');
    }

    unawaited(model.saveAllDataToServer());

    if (mounted && dialogOpen) Navigator.of(context).pop();
  }

  Future<void> _writeMeasureCommand(MeasureType type, BluetoothScanModel model) async {
    if (type == MeasureType.heartRate) {
      await model.writeData(MsBleDataAnalysis.healthMeasurementWithDataType(2, true));
      measuringDataType = 1;
    } else if (type == MeasureType.spo2) {
      await model.writeData(MsBleDataAnalysis.healthMeasurementWithDataType(3, true));
      measuringDataType = 2;
    }
  }

 

  // ── readiness ─────────────────────────────────────────────────────────────

  void _startVitalsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _vitalsListenerSub = FirebaseFirestore.instance
        .collection('my_device_vitals')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .skip(1) // skip the initial snapshot — initState already computed
        .listen(
          (_) => unawaited(_computeReadiness()),
          onError: (e) => debugPrint('[readiness listener] error: $e'),
        );
  }

  Future<void> _computeReadiness() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final todayKey  = _dateFmt.format(DateTime.now());
    final cutoffKey = _dateFmt.format(DateTime.now().subtract(const Duration(days: 27)));

    try {
      // Query by userId only — avoids composite index requirement.
      // Date filtering is done in Dart below.
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('my_device_vitals')
            .where('userId', isEqualTo: user.uid)
            .get(),
        FirebaseFirestore.instance
            .collection('daily_sleep')
            .where('userId', isEqualTo: user.uid)
            .get(),
      ]);

      // Build date-keyed maps, keeping only the 28-day window.
      final vitalsMap = <String, Map<String, dynamic>>{};

      for (final doc in results[0].docs) {
        final d = doc.data();
        final date = d['date'] as String? ?? '';

        if (date.isNotEmpty &&
            DateTime.parse(date).isAfter(DateTime.parse(cutoffKey)
            .subtract(const Duration(days: 1)))) {
          vitalsMap[date] = d;
        }
      }

      final sleepMap = <String, double>{};

      for (final doc in results[1].docs) {
        final d = doc.data();
        final date = d['date'] as String? ?? '';

        if (date.isNotEmpty &&
            DateTime.parse(date).isAfter(DateTime.parse(cutoffKey)
            .subtract(const Duration(days: 1)))) {
          sleepMap[date] =
              ((d['sleepTime'] as num?)?.toDouble() ?? 0) / 60.0;
        }
      }

      debugPrint('[readiness] vitals days: ${vitalsMap.length}, sleep days: ${sleepMap.length}');

      // Merge all dates across both collections, excluding today.
      final allDates = ({...vitalsMap.keys, ...sleepMap.keys}.toList()..sort())
          .where((k) => k != todayKey)
          .toList();

      final samples = allDates.map((date) {
        final v = vitalsMap[date];
        return ReadinessSample(
          hrv:        (v?['hrv']       as num?)?.toInt()    ?? 0,
          rhr:        (v?['heartRate'] as num?)?.toInt()    ?? 0,
          sleepHours: sleepMap[date] ?? 0,
          dailyLoad:  (v?['calories']  as num?)?.toDouble() ?? 0,
        );
      }).where((s) => s.rhr > 0 || s.sleepHours > 0).toList();

      // Append today's reading: prefer live values, fall back to today's
      // saved Firestore doc when the device is not yet connected.
      final liveHr = heartRate > 0 ? heartRate : null;
      final todayVitals = vitalsMap[todayKey];
      final todayHr = liveHr ?? (todayVitals?['heartRate'] as num?)?.toInt() ?? 0;
      if (todayHr > 0) {
        samples.add(ReadinessSample(
          hrv:        liveHr != null ? hrv : ((todayVitals?['hrv'] as num?)?.toInt() ?? 0),
          rhr:        todayHr,
          sleepHours: sleepTime > 0 ? sleepTime / 60.0 : (sleepMap[todayKey] ?? 0),
          dailyLoad:  liveHr != null ? calories : ((todayVitals?['calories'] as num?)?.toDouble() ?? 0),
        ));
      }

      debugPrint('[readiness] samples: ${samples.length}');

      final window = samples.length > 28
          ? samples.sublist(samples.length - 28)
          : samples;

      final score = ReadinessCalc.calculate(window);
      debugPrint('[readiness] score: $score');
      if (!mounted) return;
      setState(() => _readinessScore = score.clamp(0.0, 100.0).round());
    } catch (e) {
      debugPrint('[readiness] error: $e');
    }
  }

  //------- read sleep by date -----------------------------------
  /// Reads the daily_sleep doc for [date] (yyyy-MM-dd). The model writes one
  /// doc per user per day with id "<uid>_<date>"; the query is a fallback
  /// for days saved before that change.
  Future<void> _readDataByDate(String date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in again.');
    }

    final col = FirebaseFirestore.instance.collection('daily_sleep');
    Map<String, dynamic>? data = (await col.doc('${user.uid}_$date').get()).data();
    if (data == null) {
      final snap = await col
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) data = snap.docs.first.data();
    }

    double minutes(String key) => (data?[key] as num?)?.toDouble() ?? 0.0;

    if (!mounted) return;
    if (data == null) debugPrint('No sleep record found for $date');

    setState(() {
      // All values are minutes; sleepTime is asleep only (deep+light+REM).
      sleepTime      = minutes('sleepTime');
      deepSleepTime  = minutes('deepSleepTime');
      lightSleepTime = minutes('lightSleepTime');
      remSleepTime   = minutes('remSleepTime');
      awakeTime      = minutes('awakeTime');
      sleepTimeDate  = (data?['sleepStart'] as String?) ??
          DateTime.parse(date).toIso8601String();
      _sleepDayKey   = date;
    });
  }

  /// Re-reads sleep for the day currently shown, e.g. after a sync.
  Future<void> _reloadSleepForSelectedDate() async {
    try {
      await _readDataByDate(SleepCalc.dayKey(_selectedDate));
    } catch (e) {
      debugPrint('reload sleep failed: $e');
    }
  }

  //------- read steps by date -----------------------------------
  Future<void> _readStepsByDate(String date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('daily_steps')
          .where('userId', isEqualTo: user.uid)
          .where('date',   isEqualTo: date)
          .get();

      if (!mounted) return;
      setState(() {
        _selectedDateSteps = snap.docs.isEmpty
            ? 0
            : (snap.docs.first.data()['steps'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      debugPrint('_readStepsByDate error ($date): $e');
    }
  }

  //------- date selector callback -------------------------------
  // Keys match the daily_sleep / daily_steps date format: yyyy-MM-dd.
  // A day's sleep is the night that ends that morning (SleepCalc.dayShift).
Future<void> _onDateChanged(DateTime date) async {
  final day = DateTime(date.year, date.month, date.day);

  setState(() {
    _selectedDate = day;
  });

  final key =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  try {
    await Future.wait([
      _readDataByDate(key),
      _readStepsByDate(key),
    ]);
  } catch (e) {
    debugPrint('read data by date failed ($key): $e');
  }
}

  String _measureLabel(MeasureType type) => switch (type) {
        MeasureType.heartRate   => 'Heart Rate',
        MeasureType.spo2        => 'SpO2',
        MeasureType.sleep       => 'Sleep',
        MeasureType.hrv         => 'HRV',
        MeasureType.temperature => 'Temperature',
      };

  // ── device / scan plumbing ─────────────────────────────────────────────────

  void _onModelChanged() async {
    final model = _model;
    if (model == null) return;

    // New sleep was saved by the model — refresh the day on screen.
    if (model.sleepSyncVersion != _lastSleepVersion) {
      _lastSleepVersion = model.sleepSyncVersion;
      if (mounted) unawaited(_reloadSleepForSelectedDate());
    }

    final was = _lastStatus;
    final now = model.status;
    if (was == now) return;
    _lastStatus = now;
    final scanDone = was == BleStatus.scanning && now != BleStatus.scanning;
    final busy     = now == BleStatus.connecting || now == BleStatus.connected;
    if (scanDone && !busy && !_pickerOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDevicePicker());
    }
    if (now == BleStatus.connected && mounted) {
      if (_pickerOpen) Navigator.of(context).maybePop();
      _onDeviceConnected(model);
    }
  }

  Future<void> _onDeviceConnected(BluetoothScanModel model) async {
    try {
      debugPrint('Setting device datetime');
      await model.writeData(MsBleDataAnalysis.setDeviceTime(DateTime.now()));
    } catch (e) {
      debugPrint('setDeviceTime failed: $e');
    }

    final day = DateTime.now();
    final key =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    if (!mounted) return;
    setState(() {
      _selectedDate = day;
      _selectedDateSteps = null; // today — use live model value
    });

    try {
      await _readDataByDate(key);
    } catch (e) {
      debugPrint('read data by date failed ($key): $e');
    }
  }

  Future<void> _openDevicePicker() async {
    if (!mounted || _pickerOpen) return;
    _pickerOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DevicePickerSheet(
        initialFilter:    _filter,
        onFilterChanged:  _saveFilter,
        onSelect:         _onDeviceTap,
        onRescan:         _startScan,
        onStopScan:       _stopScan,
        initialModel:     _deviceModel,
        onModelSelected:  _saveDeviceModel,
      ),
    );
    _pickerOpen = false;
  }

  Future<void> _loadFilter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _filter = prefs.getString(_kFilterKey) ?? '';
      _filterController.text = _filter;
    });
  }

  Future<void> _loadDeviceModel() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _deviceModel = prefs.getString(_kDeviceModelKey) ?? 'V8';
    });
    context.read<BluetoothScanModel>().setDeviceModel(_bleDeviceModel);
  }

  Future<void> _saveDeviceModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceModelKey, value);
    if (!mounted) return;
    setState(() => _deviceModel = value);
    context.read<BluetoothScanModel>().setDeviceModel(_bleDeviceModel);
  }

  Future<void> _saveFilter(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFilterKey, value);
    if (!mounted) return;
    setState(() => _filter = value);
  }

  Future<void> _initPermissions() async {
    if (!Platform.isAndroid) {
      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.unauthorized) {
        setState(() => _permissionError = 'Bluetooth permission denied');
        return;
      }
      setState(() => _permissionsReady = true);
      _startScan();
      return;
    }

    // Only prompt if any permission is still not granted.
    final scanStatus    = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;
    final locStatus     = await Permission.locationWhenInUse.status;

    final needsRequest = !scanStatus.isGranted ||
        !connectStatus.isGranted ||
        !locStatus.isGranted;

    if (needsRequest) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final anyPermanentlyDenied = statuses.values
          .any((s) => s.isPermanentlyDenied);
      if (anyPermanentlyDenied) {
        setState(() => _permissionError =
            'Permission permanently denied — enable in app settings');
        return;
      }

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final locGranted  = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      if (!scanGranted && !locGranted) {
        setState(() => _permissionError = 'Bluetooth scan permission required');
        return;
      }
    }

    // Location services being off does not block the app — scanning will
    // simply fail on older Android, which is handled gracefully by the BLE layer.
    setState(() => _permissionsReady = true);
    _startScan();
  }

  void _startScan() {
    if (_permissionError != null) return;
    context.read<BluetoothScanModel>().disconnectDevice();
    context.read<BluetoothScanModel>().startScan();
  }

  void _stopScan()   => context.read<BluetoothScanModel>().stopScan();
  void _disconnect() => context.read<BluetoothScanModel>().disconnectDevice();

  Future<void> _onDeviceTap(ScanResult result) async {
    final model     = context.read<BluetoothScanModel>();
    final navigator = Navigator.of(context);
    await model.stopScan();
    if (navigator.canPop()) navigator.pop();
    await model.connectDevice(result.device);
  }

  // ── string helpers ─────────────────────────────────────────────────────────


  String _fmt(int? v)      => (v == null || v == 0) ? _dash : '$v';
  String _fmtD(double? v)  => (v == null || v <= 0) ? _dash : v.toStringAsFixed(1);

  String _duration(int? min) {
    if (min == null || min <= 0) return _dash;
    final h = min ~/ 60, m = min % 60;
    return h == 0 ? '${m}m' : '${h}h${m}m';
  }

  String _hrZone(int bpm) {
    if (bpm <= 0) return '';
    if (bpm < 60)  return 'Resting';
    if (bpm < 100) return 'Light';
    if (bpm < 140) return 'Moderate';
    return 'Intense';
  }

  String _spo2Zone(int v) {
    if (v <= 0)  return '';
    if (v >= 95) return 'Normal';
    if (v >= 90) return 'Low';
    return 'Very Low';
  }

  String _tempZone(double c) {
    if (c <= 0)    return '';
    if (c < 36.0)  return 'Below Baseline';
    if (c <= 37.5) return 'Normal';
    return 'Above Baseline';
  }

  String _spo2Zone2(int v) => _spo2Zone(v);

  List<String> _dateLabels() {
    final now = DateTime.now();
    String md(DateTime d) {
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}';
    }
    return [
      md(now.subtract(const Duration(days: 2))),
      'Yesterday, ${md(now.subtract(const Duration(days: 1)))}',
      'Today, ${md(now)}',
    ];
  }

  // ── build ──────────────────────────────────────────────────────────────────

  //  ---push data to firebase

  /*Future<void> pushVitalToCloud() async{
      try{
          await FirebaseFirestore.instance
          .collection('users')
          .doc('user123')
          .set({
            'name': 'Christian',
            'age': 30,
          });
      }
      catch(err){
          debugPrint('Error loading doctors: $err');
      }
  }*/

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BluetoothScanModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Background(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  battery:      model.batteryLevel,
                  isConnected:  model.isConnected,
                  onSync:       () { if (model.isConnected) model.requestRefresh(); },
                  onAddDevice:  _openDevicePicker,
                ),
                _DateSelector(
                  labels:        _dateLabels(),
                  selectedDate:  _selectedDate,
                  onDateChanged: _onDateChanged,
                ),
                if (!model.isConnected && _navIndex == 0)
                  _ConnectionBanner(
                    status:      model.status,
                    onScan:      _startScan,
                    onStop:      _stopScan,
                    onDisconnect: _disconnect,
                  ),
                Expanded(child: _buildCurrentPage(model)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index:      _navIndex,
        onChanged:  (i) => setState(() => _navIndex = i),
        onCenterTap: () {
          final m = context.read<BluetoothScanModel>();
          if (m.isConnected) m.requestRefresh(); else _openDevicePicker();
        },
      ),
    );
  }

  int _effectiveSteps(BluetoothScanModel model) {
    if (DateUtils.isSameDay(_selectedDate, DateTime.now())) {
      return model.stepsToday;
    }
    return _selectedDateSteps ?? 0;
  }

  Widget _buildCurrentPage(BluetoothScanModel model) {
    // Read all BLE-sourced vitals from the model so background-poll updates
    // are reflected immediately when notifyListeners() fires.
    final hr          = model.heartRate      ?? 0;
    final spo2        = model.bloodOxygen    ?? 0;
    final temp        = model.temperature    ?? 0.0;
    final sugar       = model.bloodSugar     ?? 0.0;
    final stressVal   = model.stress;
    final hrTime      = model.heartRateTime;
    final spo2Time    = model.oxygenLevelTime;
    final tempTime    = model.temperatureTime;
    final bpHigh      = model.highBp         ?? 0;
    final bpLow       = model.lowBp          ?? 0;

    return switch (_navIndex) {
      1    => HealthPage(
                model:          model,
                heartRate:      hr,
                oxygenLevel:    spo2,
                temperature:    temp,
                heartRateTime:  hrTime,
                oxygenTime:     spo2Time,
                temperatureTime: tempTime,
                sleepTime:      sleepTime,
                sleepTimeDate:  sleepTimeDate,
                sleepDayKey:    _sleepDayKey,
                stress:         stressVal,
                duration:       _duration,
                spo2Zone:       _spo2Zone,
                tempZone:       _tempZone,
                onMeasure:      _startMeasure,
                lowBp:          bpLow,
                highBp:         bpHigh,
              ),
      3    => const ExercisePage(),
      4    => AboutPage(model: model, onScan: _openDevicePicker),
      _    => HomePage(
                model:          model,
                stress:         stressVal,
                heartRate:      hr,
                oxygenLevel:    spo2,
                stepsTaken:     _effectiveSteps(model),
                heartRateTime:  hrTime,
                sleepTime:      sleepTime,
                sleepTimeDate:  sleepTimeDate,
                sleepDayKey:    _sleepDayKey,
                oxygenTime:     spo2Time,
                temperatureTime: tempTime,
                temperature:    temp,
                bloodSugar:     sugar,
                stepsGoal:      _stepsGoal,
                lowBp:          bpLow,
                highBp:         bpHigh,
                duration:       _duration,
                spo2Zone:       _spo2Zone,
                tempZone:       _tempZone,
                onMeasure:      _startMeasure,
                hrv:            hrv,
                calories:       calories,
                readinessScore: _readinessScore,
              ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout widgets (private to this file — no BLE logic)
// ─────────────────────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.45, 0.75, 1.0],
            colors: [
              Color(0xFF0C3040),
              Color(0xFF1A3A50),
              Color(0xFF3B2010),
              Color(0xFF050A0D),
            ],
          ),
        ),
      );
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.battery,
    required this.isConnected,
    required this.onSync,
    required this.onAddDevice,
  });

  final int?       battery;
  final bool       isConnected;
  final VoidCallback onSync;
  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final bat = battery ?? 100;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const Text('Vitals101',
              style: TextStyle(
                  color: cWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2)),
          const Spacer(),
          GestureDetector(
            onTap: onSync,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.sync, color: cGray, size: 24),
            ),
          ),
          GestureDetector(
            onTap: onAddDevice,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.add, color: cGray, size: 24),
            ),
          ),
          const SizedBox(width: 4),
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: bat / 100.0,
                        strokeWidth: 2,
                        backgroundColor: cDimGray,
                        valueColor: const AlwaysStoppedAnimation<Color>(cTeal),
                      ),
                    ),
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: cTeal, shape: BoxShape.circle)),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text('$bat%',
                  style: const TextStyle(
                      color: cWhite, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Date selector ─────────────────────────────────────────────────────────────
// Quick tabs for the last three days plus a calendar button for any other date.
// Calls onDateChanged only when the selected day actually changes.

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.labels,
    required this.selectedDate,
    required this.onDateChanged,
  });

  final List<String>            labels;        // [two-days-ago, yesterday, today]
  final DateTime                selectedDate;
  final void Function(DateTime) onDateChanged;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                          'Jul','Aug','Sep','Oct','Nov','Dec'];

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _select(DateTime date) {
    if (DateUtils.isSameDay(date, selectedDate)) return;
    onDateChanged(_day(date));
  }

  Future<void> _pickDate(BuildContext context) async {
    final today = _day(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(today) ? today : selectedDate,
      firstDate: DateTime(2020),
      lastDate: today,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: cTeal,
            onPrimary: Colors.black,
            surface: Color(0xFF1A3A50),
            onSurface: cWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final quickDates = List.generate(
      labels.length,
      (i) => DateTime(today.year, today.month, today.day - (labels.length - 1 - i)),
    );
    final isQuick = quickDates.any((d) => DateUtils.isSameDay(d, selectedDate));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < quickDates.length; i++)
                    _tab(
                      labels[i],
                      DateUtils.isSameDay(quickDates[i], selectedDate),
                      () => _select(quickDates[i]),
                    ),
                  if (!isQuick)
                    _tab(
                      '${_months[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}',
                      true,
                      () => _pickDate(context),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _pickDate(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.calendar_month_outlined, color: cGray, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: active ? cWhite : cGray,
                    fontSize: 13,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w400)),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: active ? label.length * 7.5 : 0,
              decoration: BoxDecoration(
                color: cWhite,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connection banner ─────────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.status,
    required this.onScan,
    required this.onStop,
    required this.onDisconnect,
  });

  final BleStatus   status;
  final VoidCallback onScan;
  final VoidCallback onStop;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final (label, action, tap) = switch (status) {
      BleStatus.connecting => ('Connecting…', 'Stop', onDisconnect),
      BleStatus.scanning   => ('Scanning…',   'Stop', onStop),
      _                    => ('No device',   'Scan', onScan),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cStatBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cBorder),
      ),
      child: Row(
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Color(0xFFF0C040), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: cGray, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: tap,
            child: Text(action,
                style: const TextStyle(
                    color: cTeal, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onChanged,
    required this.onCenterTap,
  });

  final int             index;
  final void Function(int) onChanged;
  final VoidCallback    onCenterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF222222), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(idx: 0, offIcon: Icons.home_outlined, onIcon: Icons.home,
                  label: 'Home', current: index, onTap: onChanged),
              _NavItem(idx: 1, offIcon: Icons.favorite_border, onIcon: Icons.favorite,
                  label: 'Health', current: index, onTap: onChanged),
              // Center teal circle
              Expanded(
                child: GestureDetector(
                  onTap: onCenterTap,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: cTeal, width: 2),
                      ),
                      child: const Icon(Icons.auto_awesome, color: cTeal, size: 24),
                    ),
                  ),
                ),
              ),
              _NavItem(idx: 3, offIcon: Icons.directions_run_outlined,
                  onIcon: Icons.directions_run,
                  label: 'Exercise', current: index, onTap: onChanged),
              _NavItem(idx: 4, offIcon: Icons.sentiment_satisfied_alt_outlined,
                  onIcon: Icons.sentiment_satisfied_alt,
                  label: 'About', current: index, onTap: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.idx,
    required this.offIcon,
    required this.onIcon,
    required this.label,
    required this.current,
    required this.onTap,
  });

  final int      idx;
  final IconData offIcon;
  final IconData onIcon;
  final String   label;
  final int      current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final active = current == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? onIcon : offIcon,
                color: active ? cWhite : cDimGray, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: active ? cWhite : cDimGray,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}