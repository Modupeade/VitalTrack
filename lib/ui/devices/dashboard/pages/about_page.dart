import 'package:flutter/material.dart';

import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.model,
    required this.onScan,
  });

  final BluetoothScanModel model;
  final VoidCallback       onScan;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device',
              style: TextStyle(
                  color: cWhite, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cBorder),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label:      'Status',
                  value:      model.isConnected ? 'Connected' : 'Disconnected',
                  valueColor: model.isConnected ? cGreen : cRed,
                ),
                const Divider(color: cBorder, height: 24),
                _InfoRow(
                  label:      'Battery',
                  value:      model.batteryLevel != null
                      ? '${model.batteryLevel}%'
                      : '--',
                  valueColor: cWhite,
                ),
                const Divider(color: cBorder, height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Scan for device',
                          style: TextStyle(color: cWhite, fontSize: 14)),
                    ),
                    ElevatedButton(
                      onPressed: onScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cTeal,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Scan', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color  valueColor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: cGray, fontSize: 14)),
          ),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      );
}
