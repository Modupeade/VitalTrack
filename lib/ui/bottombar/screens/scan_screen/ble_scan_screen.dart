import 'package:flutter/material.dart';
// import 'package:flutter_blue_elves/flutter_blue_elves.dart';
// import 'package:permission_handler/permission_handler.dart';

class BleScanPage extends StatefulWidget {
  const BleScanPage({Key? key}) : super(key: key);

  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  /// Whether a scan is currently in progress
  bool isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scan'),
      ),
      body: const Center(
        child: Text('BLE scan via flutter_blue_elves is disabled'),
      ),
    );
  }
}

/*
Original flutter_blue_elves implementation — kept for reference.

import 'package:flutter_blue_elves/flutter_blue_elves.dart';

class _BleScanPageState extends State<BleScanPage> {
  /// List of devices found during scanning
  List<ScanResult> devices = [];

  /// Whether a scan is currently in progress
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    initPermission();
  }

  // ---------------------------------------------------------------------
  // Permission handling
  // ---------------------------------------------------------------------

  Future<void> initPermission() async {
    await initLocationPermission();
  }

  Future<void> initLocationPermission() async {
    FlutterBlueElves.instance.androidApplyLocationPermission((isOk) async {
      if (!isOk) {
        final status = await Permission.location.status;
        if (status.isDenied) {
          if (await Permission.location.request().isGranted) {
            initBluetoothPermission();
          }
        }
      } else {
        initBluetoothPermission();
      }
    });
  }

  Future<void> initBluetoothPermission() async {
    FlutterBlueElves.instance.androidApplyBluetoothPermission((isOk) async {
      if (!isOk) {
        if ((await Permission.bluetooth.status).isDenied) {
          await Permission.bluetooth.request();
        }
        if ((await Permission.bluetoothConnect.status).isDenied) {
          await Permission.bluetoothConnect.request();
        }
        if ((await Permission.bluetoothScan.status).isDenied) {
          await Permission.bluetoothScan.request();
        }
      }
      initBlueUtil();
    });
  }

  void initBlueUtil() {
    FlutterBlueElves.instance.androidCheckBlueLackWhat().then((values) {
      if (values.contains(AndroidBluetoothLack.bluetoothPermission) ||
          values.contains(AndroidBluetoothLack.locationPermission)) {
        debugPrint('Missing required permission — cannot scan');
        return;
      }
      if (values.contains(AndroidBluetoothLack.locationFunction)) {
        FlutterBlueElves.instance.androidOpenLocationService((isOk) {});
      }
      if (values.contains(AndroidBluetoothLack.bluetoothFunction)) {
        FlutterBlueElves.instance.androidOpenBluetoothService((isOk) {});
      }
      startScan();
    });
  }

  // ---------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------

  void startScan() {
    if (isScanning) return;

    setState(() {
      devices.clear();
      isScanning = true;
    });

    FlutterBlueElves.instance.startScan(10000).listen(
      (scanItem) {
        _addOrUpdateDevice(scanItem);
      },
      onDone: () {
        setState(() {
          isScanning = false;
        });
      },
      onError: (e) {
        debugPrint('Scan error: $e');
        setState(() {
          isScanning = false;
        });
      },
      cancelOnError: false,
    );
  }

  void stopScan() {
    FlutterBlueElves.instance.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  void _addOrUpdateDevice(ScanResult scanItem) {
    final mac = scanItem.macAddress;
    final index = devices.indexWhere((d) => d.macAddress == mac);

    setState(() {
      if (index >= 0) {
        devices[index] = scanItem;
      } else {
        devices.add(scanItem);
      }
      devices.sort((a, b) => b.rssi.compareTo(a.rssi));
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  void dispose() {
    FlutterBlueElves.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scan'),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.search),
            onPressed: isScanning ? stopScan : startScan,
          ),
        ],
      ),
      body: devices.isEmpty
          ? Center(
              child: Text(isScanning ? 'Scanning...' : 'No devices found'),
            )
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final name = device.name ?? 'No Name';
                final mac = device.macAddress ?? 'No Mac';
                final rssi = device.rssi;

                return ListTile(
                  title: Text(name),
                  subtitle: Text('mac: $mac'),
                  trailing: Text('rssi: $rssi'),
                  onTap: () {
                    stopScan();
                    // Connect to the selected device
                    final connectedDevice =
                        device.connect(connectTimeout: 5000);
                    // TODO: navigate to a page passing `connectedDevice`,
                    // or store it in shared state (e.g. a controller/service)
                  },
                );
              },
            ),
    );
  }
}
*/
