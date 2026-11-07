import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ms_ble_data_analysis/ms_ble_data_analysis.dart';

import 'package:vitals_10/utils/bluotooth_model.dart';

/// Device information / settings page.
class DeviceInformationPage extends StatefulWidget {
  const DeviceInformationPage({super.key});

  @override
  State<DeviceInformationPage> createState() => _DeviceInformationPageState();
}

class _DeviceInformationPageState extends State<DeviceInformationPage> {
  StreamSubscription<Map>? _dataSub;

  /// Flash on sport mode
  bool sport = false;

  /// Flash when heart rate is too high in sport mode
  bool heart = false;

  /// All-day heart rate (0x81 = enabled, 0x80 = disabled)
  bool heartDay = false;

  @override
  void initState() {
    super.initState();
    // context isn't safe to read during initState itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dataSub = context.read<BluetoothScanModel>().dataStream.listen(_onData);
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose(); // must come last
  }

  // ---------------------------------------------------------------- data in

  void _onData(Map map) {
    if (!mounted) return;

    final type = map[DeviceKey.dataType] as String?;
    if (type == null) return;

    switch (type) {
      case BleConst.getDeviceBatteryLevel:
      case BleConst.cmdMcuReset:
      case BleConst.getDeviceMacAddress:
      case BleConst.getDeviceVersion:
      case BleConst.setDeviceInfo:
        _showInfoDialog(map.toString());
        break;

      case BleConst.getDeviceInfo:
        final data = map[DeviceKey.data];
        if (data is Map) _applyDeviceInfo(data);
        break;
    }
  }

  void _applyDeviceInfo(Map map) {
    setState(() {
      sport = map[DeviceKey.sportEnable]?.toString() != '0';
      heart = map[DeviceKey.heartEnable]?.toString() != '0';
      heartDay = map[DeviceKey.heartDayEnable]?.toString() != '0';
    });
  }

  
  // --------------------------------------------------------------- data out

  Future<void> _write(List<int> command) async {
    final model = context.read<BluetoothScanModel>();
    if (!model.isConnected) {
      _showInfoDialog('Device not connected');
      return;
    }
    await model.writeData(command);
  }

  // --------------------------------------------------------------- dialogs

  /// Replaces controller.showContentDialog — dialogs belong to the widget
  /// layer, not the model.
  void _showInfoDialog(String text) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Info'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<BluetoothScanModel>().isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Device information')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (!connected)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Device not connected',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          _buttonRow([
            _Action('Factory reset', () async {
              final ok = await _confirm(
                'Confirm',
                'A factory reset clears all data on the device. Continue?',
              );
              if (ok) await _write(MsBleDataAnalysis.reset());
            }),
            _Action('Battery', () => _write(MsBleDataAnalysis.getDeviceBatteryLevel())),
          ]),
          _buttonRow([
            _Action('MAC address', () => _write(MsBleDataAnalysis.getDeviceMacAddress())),
            _Action('Firmware version', () => _write(MsBleDataAnalysis.getDeviceVersion())),
          ]),
          _buttonRow([
            _Action('MCU reset', () => _write(MsBleDataAnalysis.mcuReset())),
            _Action('Enter OTA mode', () async {
              final ok = await _confirm(
                'Confirm',
                'Put the device into firmware update mode?',
              );
              if (ok) await _write(MsBleDataAnalysis.enterOTA());
            }),
          ]),
          const Divider(height: 24),
          SwitchListTile(
            title: const Text('Sport mode flash'),
            value: sport,
            onChanged: (v) => setState(() => sport = v),
          ),
          SwitchListTile(
            title: const Text('High heart rate flash'),
            value: heart,
            onChanged: (v) => setState(() => heart = v),
          ),
          SwitchListTile(
            title: const Text('All-day heart rate'),
            value: heartDay,
            onChanged: (v) => setState(() => heartDay = v),
          ),
          _buttonRow([
            _Action(
              'Set device info',
              () => _write(MsBleDataAnalysis.setDeviceInfo(heart, sport, heartDay)),
            ),
            _Action(
              'Get device info',
              () => _write(MsBleDataAnalysis.getDeviceInfo()),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buttonRow(List<_Action> actions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          for (final a in actions) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: a.onPressed,
                child: Text(a.label, textAlign: TextAlign.center),
              ),
            ),
            if (a != actions.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _Action {
  const _Action(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}