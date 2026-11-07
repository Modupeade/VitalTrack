import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/services/alert_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tracking_history_model.dart';
import '../../navigation/navigation_helper.dart';
import '../Consultation/consultation_info_screen.dart';
import 'alert_widgets.dart';

class AlertPager extends StatefulWidget {
  final String userId;

  const AlertPager({
    super.key,
    required this.userId,
  });

  @override
  State<AlertPager> createState() => _AlertPagerState();
}

class _AlertPagerState extends State<AlertPager> {
  int _currentPage = 0;
  final AlertService _alertService = AlertService();
  // late List<Widget> alertScreens;
  bool _isLoading = true;
  StreamSubscription? _alertSubscription;

  DateTimeRange selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now().add(const Duration(days: 1)),
  );

  void _updateDateRange(DateTimeRange newRange) {
    setState(() {
      selectedDateRange = newRange;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize alertScreens with empty screens
    // alertScreens = List.generate(4, (index) => _buildEmptyScreen());
    _initializeAlerts();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  List<TrackingHistory> trackingHistory = [];
  Future<void> _initializeAlerts() async {
    setState(() {
      _isLoading = true;
    });
    // await deleteAllTrackingHistoryForCurrentUser();
    trackingHistory = await getTrackingHistoryList();

    log('this is history ${trackingHistory.length}');
    setState(() {
      _isLoading = false;
    });
  }

  void _nextAlert() {
    if (_currentPage < 3) {
      setState(() => _currentPage++);
    }
  }

  void _backAlert() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
            onTap: _backAlert, child: const Icon(Icons.arrow_back)),
        title: const Text("Vitals101 Alerts"),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < 0) {
              // Swiped Left
              _nextAlert();
            } else if (details.primaryVelocity! > 0) {
              // Swiped Right
              if (_currentPage > 0) {
                _backAlert();
              }
              // Do nothing if on first alert
            }
          }
        },
        child: _currentPage == 0
            ? AverageBloodPressure(
                nextTap: _nextAlert,
                trackingHistory: trackingHistory,
                selectedDateRange: selectedDateRange,
                onDateRangeChanged: _updateDateRange,
              )
            : _currentPage == 1
                ? TimeInTargetWidget(
                    nextTap: _nextAlert,
                    trackingHistory: trackingHistory,
                    selectedDateRange: selectedDateRange,
                    onDateRangeChanged: _updateDateRange,
                  )
                : _currentPage == 2
                    ? MeanArterialPressure(
                        nextTap: _nextAlert,
                        trackingHistory: trackingHistory,
                        selectedDateRange: selectedDateRange,
                        onDateRangeChanged: _updateDateRange,
                      )
                    : BPTrendIndicator(
                        nextTap: _nextAlert,
                        trackingHistory: trackingHistory,
                        selectedDateRange: selectedDateRange,
                        onDateRangeChanged: _updateDateRange,
                      ),
      ),
    );
  }
}

class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const LineChartWidget({super.key, required this.data, required this.labels});

  List<FlSpot> _convertToFlSpots() {
    return data.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final value = entry.value;
      return FlSpot(index, value);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: data.length * 40.0, // Adjust width based on number of points
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false, drawHorizontalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 10,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(0), // Display Y-axis values
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    // Calculate interval to avoid overlapping labels
                    int interval = 1;
                    if (labels.length > 15) {
                      interval = (labels.length / 8).ceil();
                    } else if (labels.length > 8) {
                      interval = 2;
                    }
                    // Only show labels at intervals to prevent overlap
                    if (index >= 0 && index < labels.length && index % interval == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[index], // Display X-axis labels
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: _convertToFlSpots(),
                isCurved: true,
                barWidth: 4,
                color: Colors.blueAccent,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            minX: 0,
            maxX: data.length.toDouble() - 1,
            minY: data.reduce((a, b) => a < b ? a : b) - 10,
            maxY: data.reduce((a, b) => a > b ? a : b) + 5,
          ),
        ),
      ),
    );
  }
}

class PieChartWidget extends StatelessWidget {
  final double percentage;

  const PieChartWidget({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            value: percentage,
            color: Colors.green,
            title: '${percentage.toInt()}%',
            titleStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            radius: 60,
          ),
          PieChartSectionData(
            value: 100 - percentage,
            color: Colors.grey[300],
            title: '',
            radius: 60,
          ),
        ],
      ),
    );
  }
}

class SpecialistCard extends StatelessWidget {
  const SpecialistCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      color: Colors.white,
      shadowColor: Colors.grey,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Speak to a Specialist",
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.black,
                    fontWeight: FontWeight.w700)),
            10.height,
            Center(
              child: Container(
                width: 100,
                height: 100,
                child: Image.asset(
                  'assets/icons/doctor_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            20.height,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(
                        context, const ConsultationInfoScreen());
                  },
                  icon: const Icon(Icons.schedule, color: Colors.white),
                  label: const Text("Book Appointment",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff00b048),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BpTrendIndicatorChart extends StatelessWidget {
  final List<double> systolicData;
  final List<double> diastolicData;

  const BpTrendIndicatorChart({
    Key? key,
    required this.systolicData,
    required this.diastolicData,
  }) : super(key: key);

  List<FlSpot> _convertToFlSpots(List<double> data) {
    return data.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final value = entry.value;
      return FlSpot(index, value);
    }).toList();
  }

  double calculateSlope(List<double> data) {
    if (data.isEmpty) return 0.0;

    double n = data.length.toDouble();
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;

    for (int i = 0; i < data.length; i++) {
      double x = i + 1.0; // Using 1-based index
      double y = data[i];

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('these are value \nsys:$systolicData\n dia:$diastolicData');
    double systolicSlope = calculateSlope(systolicData);
    double diastolicSlope = calculateSlope(diastolicData);

    return Stack(
      children: [
        LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: _convertToFlSpots(systolicData),
                isCurved: true,
                barWidth: 3,
                color: Colors.blue,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: _convertToFlSpots(diastolicData),
                isCurved: true,
                barWidth: 3,
                color: Colors.red,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Systolic is trending up by ${systolicSlope.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              Text(
                'Diastolic is trending up by ${diastolicSlope.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<List<TrackingHistory>> getTrackingHistoryList() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('trackingHistory')
      .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? "")
      .orderBy('addedTime', descending: true)
      .get();

  return snapshot.docs
      .map((doc) => TrackingHistory.fromFirestore(doc))
      .toList();
}

Future<void> deleteAllTrackingHistoryForCurrentUser() async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    throw Exception("User not logged in");
  }

  final collection = FirebaseFirestore.instance.collection('trackingHistory');

  final querySnapshot = await collection.where('uid', isEqualTo: userId).get();

  final batch = FirebaseFirestore.instance.batch();

  for (var doc in querySnapshot.docs) {
    batch.delete(doc.reference);
  }

  await batch.commit();
}
