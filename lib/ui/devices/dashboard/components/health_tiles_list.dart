import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vitals_10/ui/devices/dashboard/components/health_tile.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/measure_type.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';
import 'package:vitals_10/ui/devices/dashboard/pages/sleep_detail_page.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';

/// Builds the shared list of health metric tiles used by both the Home and
/// Health pages so both always show identical content.
class HealthTilesList {
  const HealthTilesList({
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
    required this.stress,
    required this.lowBp,
    required this.highBp,
    required this.sleepTime,
    required this.sleepTimeDate,
    required this.sleepDayKey,
    required this.timeStr,
  });

  final BluetoothScanModel         model;
  final int                        heartRate;
  final int                        stress;
  final int                        highBp;
  final int                        lowBp;
  final int                        oxygenLevel;
  final double                     temperature;
  final String                     heartRateTime;
  final String                     oxygenTime;
  final String                     temperatureTime;
  final double                     sleepTime;
  final String                     sleepTimeDate;
  final String                     sleepDayKey;
  final String Function(int?)      duration;
  final String Function(int)       spo2Zone;
  final String Function(double)    tempZone;
  final void Function(MeasureType) onMeasure;
  final String                     timeStr;

  static const _dash = '--';

  Widget _measureBtn(MeasureType type) => MeasureButton(
        isConnected: model.isConnected,
        type: type,
        onMeasure: onMeasure,
      );

  String formatDate(String? date) {
    
    // 1. Return a fallback if the date is null or an empty string
    if (date == null || date.isEmpty) {
      return '--'; // Or return an empty string '' depending on your UI needs
    }

    // 2. Use tryParse to safely handle malformed strings without crashing
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      return 'Invalid Date'; 
    }

    return DateFormat('yyyy-MM-dd HH:mm').format(parsedDate);
  }

  
  List<Widget> tiles(BuildContext context) => [
        HealthTile(
          iconBg:     const Color(0xFFCC3333),
          icon:       Icons.monitor_heart_outlined,
          title:      'Heart Rate',
          titleColor: cRed,
          timestamp:  formatDate(heartRateTime),
          value:      heartRate > 0 ? '$heartRate' : _dash,
          unit:       'bpm',
          sub:        heartRate > 0
              ? 'Range $heartRate - ${(heartRate * 1.3).round()}bpm'
              : '',
          right: _measureBtn(MeasureType.heartRate),
        ),
        const SizedBox(height: 8),
        HealthTile(
          iconBg:     const Color(0xFFCC3333),
          icon:       Icons.water_drop_outlined,
          title:      'SpO2',
          titleColor: cRed,
          timestamp:  formatDate(oxygenTime),
          value:      oxygenLevel > 0 ? '$oxygenLevel' : _dash,
          unit:       '%',
          sub:        spo2Zone(oxygenLevel),
          right: _measureBtn(MeasureType.spo2),
        ),
        const SizedBox(height: 8),
        HealthTile(
          iconBg:     const Color(0xFF6644BB),
          icon:       Icons.bedtime_outlined,
          title:      'Sleep',
          titleColor: cPurple,
          timestamp:  formatDate(sleepTimeDate),
          value:      duration(sleepTime.toInt()),
          unit:       '',
          sub:        (sleepTime ?? 0) < 420
              ? 'Sleep time not enough'
              : '',
          right: const SizedBox.shrink(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SleepDetailPage(
                date:       sleepDayKey,
                sleepScore: model.sleepScore,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        HealthTile(
          iconBg:     const Color(0xFF00AA88),
          icon:       Icons.show_chart,
          title:      'HRV',
          titleColor: cTeal,
          timestamp:  formatDate(heartRateTime),
          value:      heartRate > 0 ? '${(heartRate * 0.65).round()}' : _dash,
          unit:       'ms',
          sub:        'Normal',
          right: const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        HealthTile(
          iconBg:     const Color(0xFFBB5500),
          icon:       Icons.thermostat,
          title:      'Temp Trend',
          titleColor: cOrange,
          timestamp:  formatDate(temperatureTime),
          value:      temperature > 0
              ? '${temperature.toStringAsFixed(1)}'
              : _dash,
          unit:       '°C',
          sub:        tempZone(temperature),
          right:    const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        HealthTile(
          iconBg:     const Color(0xFF228833),
          icon:       Icons.sentiment_satisfied_outlined,
          title:      'Stress',
          titleColor: cGreen,
          timestamp:  formatDate(heartRateTime),
          value:      stress.toString(),
          unit:       '',
          sub:        '',
          right: MiniBarChart(color: cGreen),
        ),
      ];
}
