import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';

const kDeviceModels = ['2208A', 'V4', 'V5', 'V8', 'Aura V10'];

class DevicePickerSheet extends StatefulWidget {
  const DevicePickerSheet({
    super.key,
    required this.initialFilter,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onRescan,
    required this.onStopScan,
    this.initialModel = 'V8',
    this.onModelSelected,
  });

  final String initialFilter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(ScanResult) onSelect;
  final VoidCallback onRescan;
  final VoidCallback onStopScan;
  final String initialModel;
  final ValueChanged<String>? onModelSelected;

  @override
  State<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<DevicePickerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialFilter);
  late String _query = widget.initialFilter;
  late String _model = widget.initialModel;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _nameOf(ScanResult r) => r.device.platformName.isNotEmpty
      ? r.device.platformName
      : r.advertisementData.advName;

  List<ScanResult> _visible(List<ScanResult> raw) {
    return raw
        .where((r) {
          final name = _nameOf(r);
          if (name.isEmpty) return false;
          if (_query.isEmpty) return true;
          return name.toLowerCase().contains(_query.toLowerCase());
        })
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  IconData _signalIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_alt;
    if (rssi >= -75) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: cHealthTile,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Consumer<BluetoothScanModel>(
            builder: (ctx, model, _) {
              final results  = _visible(model.scanResults);
              final scanning = model.status == BleStatus.scanning;

              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cDimGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'SELECT A DEVICE',
                            style: TextStyle(
                                color: cWhite,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1),
                          ),
                        ),
                        if (scanning)
                          TextButton.icon(
                            onPressed: widget.onStopScan,
                            icon: const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: cTeal),
                            ),
                            label: const Text('Stop',
                                style: TextStyle(color: cTeal)),
                          )
                        else
                          TextButton.icon(
                            onPressed: widget.onRescan,
                            icon: const Icon(Icons.refresh,
                                size: 18, color: cTeal),
                            label: const Text('Rescan',
                                style: TextStyle(color: cTeal)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        const Text(
                          'Device model',
                          style: TextStyle(color: cGray, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cDimGray),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _model,
                                dropdownColor: const Color(0xFF222222),
                                style: const TextStyle(
                                    color: cWhite, fontSize: 14),
                                iconEnabledColor: cGray,
                                isDense: true,
                                items: kDeviceModels
                                    .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _model = v);
                                  widget.onModelSelected?.call(v);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: cWhite),
                      onChanged: (v) {
                        setState(() => _query = v);
                        widget.onFilterChanged(v);
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter by name',
                        hintStyle: const TextStyle(color: cGray),
                        prefixIcon:
                            const Icon(Icons.search, size: 20, color: cGray),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18, color: cGray),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                  widget.onFilterChanged('');
                                },
                              ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: cDimGray)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: cDimGray)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: cTeal)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: results.isEmpty
                        ? _EmptyState(
                            scanning: scanning,
                            filtered: _query.isNotEmpty,
                            onRescan: widget.onRescan,
                          )
                        : ListView.separated(
                            controller: scroll,
                            padding:
                                const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: cDimGray),
                            itemBuilder: (ctx, i) {
                              final r = results[i];
                              return ListTile(
                                leading: Icon(_signalIcon(r.rssi),
                                    color: cGray),
                                title: Text(_nameOf(r),
                                    style: const TextStyle(color: cWhite),
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  '${r.device.remoteId.str}  •  ${r.rssi} dBm',
                                  style: const TextStyle(
                                      fontSize: 12, color: cGray),
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    color: cGray),
                                onTap: () => widget.onSelect(r),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.scanning,
    required this.filtered,
    required this.onRescan,
  });

  final bool scanning;
  final bool filtered;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scanning
                  ? Icons.bluetooth_searching
                  : Icons.bluetooth_disabled,
              size: 40,
              color: cDimGray,
            ),
            const SizedBox(height: 12),
            Text(
              scanning
                  ? 'Scanning…'
                  : filtered
                      ? 'No devices match that filter'
                      : 'No devices found',
              textAlign: TextAlign.center,
              style: const TextStyle(color: cGray),
            ),
            if (!scanning) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRescan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cTeal,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Scan again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
