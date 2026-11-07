import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitals_10/ui/devices/device_information.dart';

import 'package:vitals_10/utils/bluotooth_model.dart';
import 'package:vitals_10/ui/devices/device_detail_screen.dart';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  static const _kFilterKey = 'scan_filter';

  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  bool _permissionsReady = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _loadFilter();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPermissions());
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- filter

  Future<void> _loadFilter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _filter = prefs.getString(_kFilterKey) ?? '';
      _filterController.text = _filter;
    });
  }

  Future<void> _saveFilter(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFilterKey, value);
    setState(() => _filter = value);
  }

  void _showFilterDialog() {
    _filterController.text = _filter;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter by name'),
        content: TextField(
          controller: _filterController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. V8'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveFilter('');
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              _saveFilter(_filterController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- permissions

  /// flutter_blue_plus doesn't bundle permission helpers the way
  /// flutter_blue_elves does, so this is plain permission_handler.
  Future<void> _initPermissions() async {
    if (!Platform.isAndroid) {
      // iOS: the OS prompts on first use; just confirm the adapter is usable.
      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.unauthorized) {
        setState(() => _permissionError = 'Bluetooth permission denied');
        return;
      }
      setState(() => _permissionsReady = true);
      _startScan();
      return;
    }

    // Android 12+ (API 31): scan + connect. Older: location.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();

    if (denied.isNotEmpty) {
      setState(() => _permissionError =
          'Permission permanently denied — enable it in app settings');
      return;
    }

    final granted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    if (!granted && !(statuses[Permission.locationWhenInUse]?.isGranted ?? false)) {
      setState(() => _permissionError = 'Bluetooth scan permission required');
      return;
    }

    // MIUI in particular returns zero scan results with Location switched off,
    // even when permissions are granted.
    if (await Permission.locationWhenInUse.serviceStatus.isDisabled) {
      setState(() => _permissionError =
          'Turn on Location services — BLE scanning returns nothing without it');
      return;
    }

    setState(() => _permissionsReady = true);
    _startScan();
  }

  // -------------------------------------------------------------- scanning

  void _startScan() {
    context.read<BluetoothScanModel>().startScan();
  }

  void _stopScan() {
    context.read<BluetoothScanModel>().stopScan();
  }

  /// flutter_blue_plus already de-duplicates by device, so the vendor's
  /// manual mac-matching loop over blueinfos is no longer needed.
  List<ScanResult> _visibleResults(List<ScanResult> raw) {
    final list = raw.where((r) {
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : r.advertisementData.advName;
      if (name.isEmpty) return false;
      if (_filter.isEmpty) return true;
      return name.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    list.sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<void> _onDeviceTap(ScanResult result) async {
    final model = context.read<BluetoothScanModel>();
    await model.stopScan();
    await model.connectDevice(result.device);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceInformationPage()),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BluetoothScanModel>();
    final results = _visibleResults(model.scanResults);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          if (model.isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: model.isScanning ? _stopScan : _startScan,
            child: Text(
              model.isScanning ? 'Stop' : 'Scan',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _buildBody(results),
    );
  }

  Widget _buildBody(List<ScanResult> results) {
    if (_permissionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_permissionError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Open settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_permissionsReady) {
      return const Center(child: CircularProgressIndicator());
    }

   

    if (results.isEmpty) {
      return Center(
        child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Text(
                  _filter.isEmpty
                      ? 'No devices found yet'
                      : 'No devices matching "$_filter"',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async => _startScan(),
                  child: const Text('Open settings'),
                ),
             ],
        )
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _startScan(),
      child: ListView.separated(
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildDeviceItem(results[index]),
      ),
    );
  }

  Widget _buildDeviceItem(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.advertisementData.advName;

    return ListTile(
      title: Text(
        name.isEmpty ? 'No Name' : name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      // remoteId is the MAC on Android, a system-assigned UUID on iOS.
      subtitle: Text(result.device.remoteId.str),
      trailing: Text('${result.rssi} dBm'),
      onTap: () => _onDeviceTap(result),
    );
  }
}