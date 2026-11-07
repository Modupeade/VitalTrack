import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/devices/bluetooth_scan_screen.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';

import 'package:ms_ble_data_analysis/ms_ble_data_analysis.dart';
import 'package:ms_ble_data_analysis/ble_const.dart';
import 'package:ms_ble_data_analysis/device_key.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
    
    BluetoothScanModel get _model => context.read<BluetoothScanModel>();
    BluetoothDevice? get _device => _model.connectedDevice;


  

  

  @override
  Widget build(BuildContext context) {

    final model = context.watch<BluetoothScanModel>();
    final device = model.connectedDevice;

    

    if (device == null) {
      return const Scaffold(
        body: Center(child: Text('No device connected.')),
      );
    }

    final name = device.platformName.isNotEmpty
        ? device.platformName
        : 'Unknown device';

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connected to ${device.remoteId}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async{
                  await context.read<BluetoothScanModel>().disconnectDevice();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const BluetoothScanScreen()),
                    (route) => route.isFirst,
                  );
              },
                  
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ),
    );
  }
}