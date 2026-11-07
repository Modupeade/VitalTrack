import 'package:flutter/material.dart';

import 'package:vitals_10/ui/devices/dashboard/components/activity_card.dart';
import 'package:vitals_10/ui/devices/dashboard/components/balance_card.dart';
import 'package:vitals_10/ui/devices/dashboard/components/health_tiles_list.dart';
import 'package:vitals_10/ui/devices/dashboard/components/sleep_card.dart';
import 'package:vitals_10/ui/devices/dashboard/components/vital_chart_card.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/measure_type.dart';
import 'package:vitals_10/ui/devices/dashboard/constants/page_colors.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.model,
    required this.heartRate,
    required this.oxygenLevel,
    required this.stepsTaken,
    required this.temperature,
    required this.bloodSugar,
    required this.stepsGoal,
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
    required this.hrv,
    required this.calories,
    required this.readinessScore,
  });

  final BluetoothScanModel          model;
  final int                         heartRate;
  final int                         oxygenLevel;
  final int                         stress;
  final int                         lowBp;
  final int                         highBp;
  final int                         stepsTaken;
  final double                      temperature;
  final double                      bloodSugar;
  final int                         stepsGoal;
  final double                      sleepTime;
  final String                      sleepTimeDate;
  final String                      sleepDayKey;
  final int                         hrv;
  final double                      calories;
  final int                         readinessScore;
  final String Function(int?)       duration;
  final String Function(int)        spo2Zone;
  final String Function(double)     tempZone;
  final void Function(MeasureType)  onMeasure;

  final String heartRateTime;
  final String oxygenTime;
  final String temperatureTime;

  static const _dash = '--';

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
      heartRateTime: heartRateTime,
      oxygenTime:    oxygenTime,
      temperatureTime: temperatureTime,
      tempZone:    tempZone,
      sleepTime:   sleepTime,
      sleepTimeDate: sleepTimeDate,
      sleepDayKey:   sleepDayKey,
      onMeasure:   onMeasure,
      timeStr:     timeStr,
      lowBp: lowBp,
      highBp: highBp,
      stress: stress,
    ).tiles(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SleepCard(
            readinessScore:     readinessScore,
            sleepTotalMinutes:  sleepTime.toInt(),
            deepSleepMinutes:   model.deepSleepMinutes   ?? 0,
            remSleepMinutes:    model.remSleepMinutes    ?? 0,
            awakeMinutes:       model.awakeMinutes        ?? 0,
            heartRateLabel:     heartRate   > 0 ? '${heartRate}bpm' : _dash,
            spo2Label:          oxygenLevel > 0 ? '$oxygenLevel%'   : '0%',
            sleepDurationLabel: duration(sleepTime.toInt()),
          ),
          const SizedBox(height: 10),
          ActivityCard(stepsTaken: stepsTaken, stepsGoal: stepsGoal),
          const SizedBox(height: 10),
          //const BalanceCard(),
          const SizedBox(height: 10),
          VitalChartCard(
            title:      'Heart Rate',
            value:      heartRate > 0 ? '$heartRate' : _dash,
            unit:       'bpm',
            stat1Label: 'RHR',
            stat1Value: heartRate > 0 ? '${heartRate}bpm' : _dash,
            stat2Label: 'Avg',
            stat2Value: heartRate > 0 ? '${(heartRate * 1.15).round()}bpm' : _dash,
            dataDate: heartRateTime,
          ),
          const SizedBox(height: 10),
          VitalChartCard(
            title:      'SpO2',
            value:      oxygenLevel > 0 ? '$oxygenLevel' : _dash,
            unit:       '%',
            stat1Label: 'Lowest',
            stat1Value: oxygenLevel > 0 ? '$oxygenLevel%' : _dash,
            stat2Label: 'Avg',
            stat2Value: oxygenLevel > 0 ? '$oxygenLevel%' : _dash,
            dataDate: oxygenTime,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: const [
                Text('Health',
                    style: TextStyle(
                        color: cWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Spacer(),
                Icon(Icons.calendar_month, color: cGray, size: 20),
              ],
            ),
          ),
          const Center(
            child: Text('Track your health goals',
                style: TextStyle(
                    color: cTeal, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: tiles),
          ),
        ],
      ),
    );
  }
}
