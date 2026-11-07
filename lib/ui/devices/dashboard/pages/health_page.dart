import 'package:flutter/material.dart';

import 'package:vitals_10/ui/devices/dashboard/components/health_tiles_list.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/measure_type.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({
    super.key,
    required this.model,
    required this.heartRate,
    required this.oxygenLevel,
    required this.temperature,
    required this.duration,
    required this.spo2Zone,
    required this.tempZone,
    required this.onMeasure,
    required this.heartRateTime,
    required this.oxygenTime,
    required this.temperatureTime,
    required this.sleepTime,
    required this.sleepTimeDate,
    required this.sleepDayKey,
    required this.stress,
    required this.lowBp,
    required this.highBp,
  });

  final BluetoothScanModel          model;
  final int                         heartRate;
  final int                         oxygenLevel;
  final int                         stress;
  final int                         lowBp;
  final int                         highBp;
  final double                      temperature;
  final String                      heartRateTime;
  final String                      oxygenTime;
  final String                      temperatureTime;
  final double                      sleepTime;
  final String                      sleepTimeDate;
  final String                      sleepDayKey;
  final String Function(int?)       duration;
  final String Function(int)        spo2Zone;
  final String Function(double)     tempZone;
  final void Function(MeasureType)  onMeasure;


  @override
  Widget build(BuildContext context) {
    final now     = TimeOfDay.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final tiles = HealthTilesList(
      model:       model,
      heartRate:   heartRate,
      oxygenLevel: oxygenLevel,
      temperature: temperature,
      duration:    duration,
      spo2Zone:    spo2Zone,
      tempZone:    tempZone,
      onMeasure:   onMeasure,
      heartRateTime: heartRateTime,
      oxygenTime:  oxygenTime,
      sleepTime:   sleepTime,
      sleepTimeDate: sleepTimeDate,
      sleepDayKey:   sleepDayKey,
      temperatureTime: temperatureTime,
      stress: stress,
      lowBp: lowBp,
      highBp: highBp,
      timeStr:     timeStr,
    ).tiles(context);

    return Container(
      color: cHealthBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: const [
                Text('Health',
                    style: TextStyle(
                        color: cWhite,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                Spacer(),
                Icon(Icons.calendar_month, color: cGray, size: 22),
              ],
            ),
          ),
          const Center(
            child: Text('Track your health goals',
                style: TextStyle(
                    color: cTeal, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              children: tiles,
            ),
          ),
        ],
      ),
    );
  }
}
