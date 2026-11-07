import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';

class MeasureLoadingDialog extends StatefulWidget {
  const MeasureLoadingDialog({super.key, required this.label});
  final String label;

  @override
  State<MeasureLoadingDialog> createState() => _MeasureLoadingDialogState();
}

class _MeasureLoadingDialogState extends State<MeasureLoadingDialog> {
  static const _total = 35;
  int _remaining = _total;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / _total;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: cHealthTile,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: cDimGray,
                        valueColor: const AlwaysStoppedAnimation<Color>(cTeal),
                      ),
                    ),
                    Text(
                      '$_remaining',
                      style: const TextStyle(
                        color: cWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Measuring ${widget.label}',
                style: const TextStyle(
                  color: cWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please keep the device still…',
                style: TextStyle(color: cGray, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
