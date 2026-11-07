import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitals_10/models/tracking_history_model.dart';
import 'package:vitals_10/services/email_service.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/Alerts/ai_insights_card.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/utils/record_time.dart';
import 'alerts_pages.dart';

int sysThreshold = 120;
int diaThreshold = 80;

// Helper function to send report email
Future<void> _sendReportEmail(
    BuildContext context,
    String reportType,
    String reportData,
    ) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
      return;
    }

    // Get user data from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'User';
      final userEmail = userData['email'] ?? user.email;

      if (userEmail != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
          const Center(child: CircularProgressIndicator()),
        );

        // Send report email
        final emailSent = await EmailService.sendReportEmail(
          recipientEmail: userEmail,
          reportType: reportType,
          reportData: reportData,
          recipientName: userName,
        );

        // Hide loading indicator
        Navigator.of(context).pop();

        if (emailSent) {
          // Track report email with Facebook Analytics
          await FacebookAnalyticsService.logReportEmailed(
            reportType: reportType,
            success: true,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Report sent successfully to your email!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Track failed email attempt
          await FacebookAnalyticsService.logReportEmailed(
            reportType: reportType,
            success: false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to send report. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email not found")));
      }
    }
  } catch (e) {
    print('Error sending report email: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Error sending report. Please try again."),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Helper function to send BP records report with table format
Future<void> _sendBPRecordsReport(
    BuildContext context,
    DateTimeRange dateRange,
    ) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
      return;
    }

    // Get user data from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'User';
      final userEmail = userData['email'] ?? user.email;

      if (userEmail != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
          const Center(child: CircularProgressIndicator()),
        );

        // Fetch BP records for the date range
        final bpRecords = await _fetchBPRecords(user.uid, dateRange);
        final dateRangeText =
            '${dateRange.start.day}/${dateRange.start.month}/${dateRange.start.year} - ${dateRange.end.day}/${dateRange.end.month}/${dateRange.end.year}';

        // Send BP records report email
        final emailSent = await EmailService.sendBPRecordsReport(
          recipientEmail: userEmail,
          recipientName: userName,
          bpRecords: bpRecords,
          dateRange: dateRangeText,
        );

        // Hide loading indicator
        Navigator.of(context).pop();

        if (emailSent) {
          // Track report email with Facebook Analytics
          await FacebookAnalyticsService.logReportEmailed(
            reportType: 'bp_records',
            success: true,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "BP Records report sent successfully to your email!",
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Track failed email attempt
          await FacebookAnalyticsService.logReportEmailed(
            reportType: 'bp_records',
            success: false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to send report. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email not found")));
      }
    }
  } catch (e) {
    print('Error sending BP records report: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Error sending report. Please try again."),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Helper function to fetch BP records from Firestore
Future<List<Map<String, dynamic>>> _fetchBPRecords(
    String userId,
    DateTimeRange dateRange,
    ) async {
  try {
    // Get all tracking history for the user (no date filtering to avoid index issues)
    final snapshot = await FirebaseFirestore.instance
        .collection('trackingHistory')
        .where('uid', isEqualTo: userId)
        .orderBy('addedTime', descending: true)
        .limit(100) // Limit to last 100 records to avoid performance issues
        .get();

    // Fix date range filtering to include the full end day
    // Set start time to beginning of start day
    final startTime = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
    ).millisecondsSinceEpoch;

    // Set end time to end of end day (23:59:59.999)
    final endTime = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    print(
      'Date range filter: ${DateTime.fromMillisecondsSinceEpoch(startTime)} to ${DateTime.fromMillisecondsSinceEpoch(endTime)}',
    );

    // Filter for Blood Pressure records in memory and apply date range
    final bpRecords = snapshot.docs
        .where((doc) {
      final data = doc.data();

      return data['trackerName'] == 'Blood Pressure' &&
          data['sys'] != null &&
          data['dia'] != null &&
          data['sys'].toString().trim().isNotEmpty &&
          data['dia'].toString().trim().isNotEmpty &&
          data['sys'] != '0' &&
          data['dia'] != '0' &&
          RecordTime.isInRange(dateRange, RecordTime.resolveMap(data));
    })
        .map((doc) {
      final data = doc.data();
      return {
        'addedTime': data['addedTime'],
        'time': data['time'],
        'sys': data['sys'],
        'dia': data['dia'],
        'pul': data['pulse'] ?? data['pul'] ?? '0',
        'trackerName': data['trackerName'],
      };
    })
        .toList();

    print('Found ${bpRecords.length} BP records in date range');
    return bpRecords;
  } catch (e) {
    print('Error fetching BP records: $e');
    return [];
  }
}

// Helper function to fetch Glucose records from Firestore
Future<List<Map<String, dynamic>>> _fetchGlucoseRecords(
    String userId,
    DateTimeRange dateRange,
    ) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('trackingHistory')
        .where('uid', isEqualTo: userId)
        .orderBy('addedTime', descending: true)
        .limit(100)
        .get();

    final glucoseRecords = snapshot.docs
        .where((doc) {
      final data = doc.data();

      return data['trackerName'] == 'Blood Glucose' &&
          data['value'] != null &&
          data['value'].toString().trim().isNotEmpty &&
          data['value'] != '0' &&
          RecordTime.isInRange(dateRange, RecordTime.resolveMap(data));
    })
        .map((doc) {
      final data = doc.data();
      return {
        'addedTime': data['addedTime'],
        'time': data['time'],
        'glucose': data['value'],
        'value': data['value'],
        'type': data['type'] ?? 'N/A',
      };
    })
        .toList();

    print('Found ${glucoseRecords.length} glucose records in date range');
    return glucoseRecords;
  } catch (e) {
    print('Error fetching glucose records: $e');
    return [];
  }
}

// Helper function to fetch Weight records from Firestore
Future<List<Map<String, dynamic>>> _fetchWeightRecords(
    String userId,
    DateTimeRange dateRange,
    ) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('trackingHistory')
        .where('uid', isEqualTo: userId)
        .orderBy('addedTime', descending: true)
        .limit(100)
        .get();

    final weightRecords = snapshot.docs
        .where((doc) {
      final data = doc.data();

      return data['trackerName'] == 'Weight' &&
          data['value'] != null &&
          data['value'].toString().trim().isNotEmpty &&
          data['value'] != '0' &&
          RecordTime.isInRange(dateRange, RecordTime.resolveMap(data));
    })
        .map((doc) {
      final data = doc.data();
      return {
        'addedTime': data['addedTime'],
        'time': data['time'],
        'weight': data['value'],
        'value': data['value'],
        'unit': data['unit'] ?? 'kg',
      };
    })
        .toList();

    print('Found ${weightRecords.length} weight records in date range');
    return weightRecords;
  } catch (e) {
    print('Error fetching weight records: $e');
    return [];
  }
}

// Helper function to calculate slope (same logic as screen UI)
double _calculateSlope(List<double> data) {
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

// Helper function to send comprehensive BP insights report
Future<void> _sendComprehensiveBPReport(
    BuildContext context,
    DateTimeRange dateRange,
    ) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
      return;
    }

    // Get user data from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'User';
      final userEmail = userData['email'] ?? user.email;

      if (userEmail != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
          const Center(child: CircularProgressIndicator()),
        );

        // Fetch BP records for the date range
        final bpRecords = await _fetchBPRecords(user.uid, dateRange);

        // Fetch glucose and weight records for the date range
        final glucoseRecords = await _fetchGlucoseRecords(user.uid, dateRange);
        final weightRecords = await _fetchWeightRecords(user.uid, dateRange);

        final dateRangeText =
            '${dateRange.start.day}/${dateRange.start.month}/${dateRange.start.year} - ${dateRange.end.day}/${dateRange.end.month}/${dateRange.end.year}';

        // Calculate trend values using the same logic as the screen UI
        double systolicTrend = 0.0;
        double diastolicTrend = 0.0;

        if (bpRecords.isNotEmpty) {
          // Extract systolic and diastolic values and calculate slopes
          final systolicValues = bpRecords
              .map((r) => (int.tryParse(r['sys'] ?? '0') ?? 0).toDouble())
              .toList();
          final diastolicValues = bpRecords
              .map((r) => (int.tryParse(r['dia'] ?? '0') ?? 0).toDouble())
              .toList();

          // Calculate slopes using the same method as the screen
          systolicTrend = _calculateSlope(systolicValues.reversed.toList());
          diastolicTrend = _calculateSlope(diastolicValues.reversed.toList());
        }

        // Send comprehensive BP insights report email with PDF
        final emailSent = await EmailService.sendComprehensiveBPReport(
          recipientEmail: userEmail,
          recipientName: userName,
          bpRecords: bpRecords,
          glucoseRecords: glucoseRecords.isNotEmpty ? glucoseRecords : null,
          weightRecords: weightRecords.isNotEmpty ? weightRecords : null,
          dateRange: dateRangeText,
          totalMeasurements: bpRecords.length,
          systolicTrend: systolicTrend,
          diastolicTrend: diastolicTrend,
          systolicThreshold: sysThreshold,
          diastolicThreshold: diaThreshold,
        );

        // Hide loading indicator
        Navigator.of(context).pop();

        if (emailSent) {
          // Track comprehensive report email with Facebook Analytics
          await FacebookAnalyticsService.logReportEmailed(
            reportType: 'comprehensive_bp',
            success: true,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Comprehensive BP report sent successfully to your email!",
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Track failed email attempt
          await FacebookAnalyticsService.logReportEmailed(
            reportType: 'comprehensive_bp',
            success: false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to send report. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Email not found")));
      }
    }
  } catch (e) {
    print('Error sending comprehensive BP report: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Error sending report. Please try again."),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Example function to demonstrate the new BP records table email functionality
// This can be called from anywhere in the app to send a BP records report
Future<void> sendBPRecordsTableExample(BuildContext context) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user data
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? user.email;

      if (userEmail != null) {
        // Create a date range for the last 7 days
        final dateRange = DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

        // Send the comprehensive BP report
        await _sendComprehensiveBPReport(context, dateRange);
      }
    }
  } catch (e) {
    print('Error in BP records example: $e');
  }
}

// Helper functions to generate report data
String _generateAverageBPReport() {
  return '''
Average Blood Pressure Report
Generated on: ${DateTime.now().toString().split(' ')[0]}

This report shows your average blood pressure measurements over the selected time period.
The data helps identify trends and patterns in your blood pressure readings.

Key Insights:
• Systolic Threshold: $sysThreshold mmHg
• Diastolic Threshold: $diaThreshold mmHg
• Report includes all measurements within the selected date range

Note: This report is for informational purposes only. 
Please consult with your healthcare provider for medical advice.
  ''';
}

String _generateTimeInTargetReport() {
  return '''
Time in Target Range Report
Generated on: ${DateTime.now().toString().split(' ')[0]}

This report shows the percentage of time your blood pressure measurements 
stay within the defined healthy target range.

Key Insights:
• Target Range: Systolic < $sysThreshold mmHg, Diastolic < $diaThreshold mmHg
• Higher TTR values indicate better blood pressure control
• Report includes all measurements within the selected date range

Note: This report is for informational purposes only. 
Please consult with your healthcare provider for medical advice.
  ''';
}

String _generateMAPReport() {
  return '''
Mean Arterial Pressure (MAP) Report
Generated on: ${DateTime.now().toString().split(' ')[0]}

This report shows your Mean Arterial Pressure calculations, which help 
determine if there's enough blood flow to supply your major organs.

Key Insights:
• MAP is calculated using: MAP = (2 × Diastolic + Systolic) ÷ 3
• Normal MAP range: 70-100 mmHg
• Report includes all measurements within the selected date range

Note: This report is for informational purposes only. 
Please consult with your healthcare provider for medical advice.
  ''';
}

String _generateBPTrendReport() {
  return '''
Blood Pressure Trend Report
Generated on: ${DateTime.now().toString().split(' ')[0]}

This report shows the trend analysis of your blood pressure measurements 
over the selected time period.

Key Insights:
• Trend analysis helps identify patterns in your blood pressure
• Positive values indicate increasing trend
• Negative values indicate decreasing trend
• Report includes all measurements within the selected date range

Note: This report is for informational purposes only. 
Please consult with your healthcare provider for medical advice.
  ''';
}

class AverageBloodPressure extends StatefulWidget {
  VoidCallback nextTap;
  List<TrackingHistory> trackingHistory;
  final DateTimeRange selectedDateRange;
  final ValueChanged<DateTimeRange> onDateRangeChanged;

  AverageBloodPressure({
    super.key,
    required this.nextTap,
    required this.trackingHistory,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
  });

  @override
  State<AverageBloodPressure> createState() => _AverageBloodPressureState();
}

class _AverageBloodPressureState extends State<AverageBloodPressure> {
  String userName = "Loading...";
  getThresholdMapByPatientId() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    print('this is user id in threshold $userId');
    final snapshot = await FirebaseFirestore.instance
        .collection('bp-threshold')
        .doc(userId)
        .get();

    if (snapshot.data()!.isNotEmpty) {
      Map<String, dynamic>? data = snapshot.data();
      debugPrint('these are threshold received ${data!['systolic']}::${data['diastolic']}');

      sysThreshold = data['systolic'] ?? "0";
      diaThreshold = data['diastolic'] ?? "0";
      debugPrint('these are threshold latest $sysThreshold::$diaThreshold');
    } else {
      return null;
    }
  }

  void calculateValues(List<TrackingHistory> histList) {
    systolicValue = 0;
    diastolicValue = 0;
    int systolicCount = 0;
    int diastolicCount = 0;

    for (var data in histList) {
      print('Raw values: sys = ${data.sys}, dia = ${data.dia}');

      final sysValue = int.tryParse(data.sys);
      final diaValue = int.tryParse(data.dia);

      if (sysValue != null && sysValue != 0) {
        systolicValue += sysValue;
        systolicCount++;
      }

      if (diaValue != null && diaValue != 0) {
        diastolicValue += diaValue;
        diastolicCount++;
      }
    }

    systolicValue = systolicCount > 0 ? systolicValue / systolicCount : 0;
    diastolicValue = diastolicCount > 0 ? diastolicValue / diastolicCount : 0;

    debugPrint(
      'Average systolic = ${systolicValue.toStringAsFixed(1)}, '
          'Average diastolic = ${diastolicValue.toStringAsFixed(1)}',
    );

    setState(() {});
  }

  List<TrackingHistory> filterHistoryByDateRange(
      List<TrackingHistory> list,
      DateTimeRange range,
      ) {
    return list.where((item) {
      final isInDateRange = RecordTime.isInRange(range, item.measuredAtMs);

      // ONLY include Blood Pressure records (exclude glucose and other vitals)
      if (item.trackerName == 'Blood Pressure') {
        bool hasValidValues =
            item.sys.toString().trim().isNotEmpty &&
                item.dia.toString().trim().isNotEmpty &&
                item.sys != '0' &&
                item.dia != '0';
        return isInDateRange && hasValidValues;
      }

      // Exclude all non-BP tracker types
      return false;
    }).toList();
  }

  List<TrackingHistory> selectedList = [];

  @override
  void initState() {
    super.initState();
    _getUserName();
    selectedList = filterHistoryByDateRange(
      widget.trackingHistory,
      widget.selectedDateRange,
    );
    calculateValues(selectedList);
    getThresholdMapByPatientId();
  }

  @override
  void didUpdateWidget(covariant AverageBloodPressure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDateRange != widget.selectedDateRange) {
      selectedList = filterHistoryByDateRange(
        widget.trackingHistory,
        widget.selectedDateRange,
      );
      calculateValues(selectedList);
    }
  }

  num systolicValue = 0;
  num diastolicValue = 0;

  void _getUserName() {
    FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          userName = snapshot.get("name") ?? "User";
        });
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: widget.selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
      selectedList = filterHistoryByDateRange(widget.trackingHistory, picked);
      calculateValues(selectedList);
    }
  }

  String _formatDateRange() {
    final start = widget.selectedDateRange.start;
    final end = widget.selectedDateRange.end;
    return "${start.day} ${_getMonthName(start.month)} - ${end.day} ${_getMonthName(end.month)}";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.10), Color(0xFFE8F5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello $userName',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset("assets/icons/appicon.jpg"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateRange(),
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onPressed: widget.nextTap,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  ' (${selectedList.length} measurements)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.bloodtype, color: Colors.redAccent, size: 32),
                    SizedBox(width: 10),
                    Text(
                      "Average Blood Pressure",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                BloodPressureDigitalCard(
                  isAlertOne: true,
                  sys: systolicValue.toStringAsFixed(0),
                  dia: diastolicValue.toStringAsFixed(0),
                ),
                // Container(
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(16),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.blueGrey.withOpacity(0.08),
                //         blurRadius: 12,
                //         offset: Offset(0, 4),
                //       ),
                //     ],
                //   ),
                //   padding: const EdgeInsets.all(18),
                //   child: Column(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       Row(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //         children: [
                //           Text(
                //             systolicValue.toStringAsFixed(0),
                //             style: const TextStyle(
                //                 fontSize: 48,
                //                 fontWeight: FontWeight.bold,
                //                 color: Colors.blue),
                //           ),
                //           const SizedBox(width: 15),
                //           const Text('Sys\nmmHg', textAlign: TextAlign.center),
                //         ],
                //       ),
                //       const SizedBox(height: 20),
                //       Row(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //         children: [
                //           Text(
                //             diastolicValue.toStringAsFixed(0),
                //             style: const TextStyle(
                //                 fontSize: 48,
                //                 fontWeight: FontWeight.bold,
                //                 color: Colors.deepPurple),
                //           ),
                //           const SizedBox(width: 15),
                //           const Text('Dia\nmmHg', textAlign: TextAlign.center),
                //         ],
                //       ),
                //     ],
                //   ),
                // ),
                const SizedBox(height: 18),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      // Use the actual selected date range from the parent widget
                      await _sendComprehensiveBPReport(
                        context,
                        widget.selectedDateRange,
                      );
                    },
                    icon: Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      "Send Report",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AiInsightsCard(dateRange: widget.selectedDateRange),
                const SizedBox(height: 20),
                const SpecialistCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/////Time in target widget

class TimeInTargetWidget extends StatefulWidget {
  VoidCallback nextTap;
  List<TrackingHistory> trackingHistory;
  final DateTimeRange selectedDateRange;
  final ValueChanged<DateTimeRange> onDateRangeChanged;

  TimeInTargetWidget({
    super.key,
    required this.nextTap,
    required this.trackingHistory,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
  });

  @override
  State<TimeInTargetWidget> createState() => _TimeInTargetWidgetState();
}

class _TimeInTargetWidgetState extends State<TimeInTargetWidget> {
  String userName = "Loading...";

  double percentageValue = 0.0;

  @override
  void initState() {
    super.initState();
    _getUserName();
    selectedList = filterHistoryByDateRange(
      widget.trackingHistory,
      widget.selectedDateRange,
    );
    calculateBpNormalPercentage(selectedList);
  }

  @override
  void didUpdateWidget(covariant TimeInTargetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDateRange != widget.selectedDateRange) {
      selectedList = filterHistoryByDateRange(
        widget.trackingHistory,
        widget.selectedDateRange,
      );
      calculateBpNormalPercentage(selectedList);
    }
  }

  void calculateBpNormalPercentage(List<TrackingHistory> readings) async {
    int total = 0;
    int normalCount = 0;
    for (var reading in readings) {
      final sys = int.tryParse(reading.sys) ?? 0;
      final dia = int.tryParse(reading.dia) ?? 0;
      // print('sys:::: $sys:::::$dia:::::::$sysThreshold:::::::$diaThreshold');
      // Only count valid readings
      if (sys > 0 && dia > 0) {
        total++;

        if (sys < sysThreshold && dia < diaThreshold) {
          normalCount++;
        }
      }
    }

    percentageValue = total == 0 ? 0 : (normalCount / total) * 100;
    setState(() {});
  }

  List<TrackingHistory> filterHistoryByDateRange(
      List<TrackingHistory> list,
      DateTimeRange range,
      ) {
    return list.where((item) {
      final isInDateRange = RecordTime.isInRange(range, item.measuredAtMs);

      // ONLY include Blood Pressure records (exclude glucose and other vitals)
      if (item.trackerName == 'Blood Pressure') {
        bool hasValidValues =
            item.sys.toString().trim().isNotEmpty &&
                item.dia.toString().trim().isNotEmpty &&
                item.sys != '0' &&
                item.dia != '0';
        return isInDateRange && hasValidValues;
      }

      // Exclude all non-BP tracker types
      return false;
    }).toList();
  }

  void _getUserName() {
    FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          userName = snapshot.get("name") ?? "User";
        });
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: widget.selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
      selectedList = filterHistoryByDateRange(widget.trackingHistory, picked);
      calculateBpNormalPercentage(selectedList);
    }
  }

  List<TrackingHistory> selectedList = [];

  String _formatDateRange() {
    final start = widget.selectedDateRange.start;
    final end = widget.selectedDateRange.end;
    return "${start.day} ${_getMonthName(start.month)} - ${end.day} ${_getMonthName(end.month)}";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.10), Color(0xFFE8F5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello $userName',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset("assets/icons/appicon.jpg"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateRange(),
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onPressed: widget.nextTap,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  ' (${selectedList.length} measurements)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.redAccent, size: 32),
                    SizedBox(width: 10),
                    Text(
                      "Time in Target Range",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 200,
                  child: PieChartWidget(percentage: percentageValue),
                ),
                const SizedBox(height: 18),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      // Use the actual selected date range from the parent widget
                      await _sendComprehensiveBPReport(
                        context,
                        widget.selectedDateRange,
                      );
                    },
                    icon: Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      "Send Report",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 500,
                  child: const Text(
                    "Time in target range (TTR) measures the percentage of time your blood pressure measurements stay within a defined healthy target range. A higher TTR value reflects better BP control.",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SpecialistCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/////Mean Arterial Pressure(MAP)

class MeanArterialPressure extends StatefulWidget {
  VoidCallback nextTap;
  List<TrackingHistory> trackingHistory;
  final DateTimeRange selectedDateRange;
  final ValueChanged<DateTimeRange> onDateRangeChanged;

  MeanArterialPressure({
    super.key,
    required this.nextTap,
    required this.trackingHistory,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
  });

  @override
  State<MeanArterialPressure> createState() => _MeanArterialPressureState();
}

class _MeanArterialPressureState extends State<MeanArterialPressure> {
  String userName = "Loading...";
  double avgMap = 0;

  double calculateMAP(int systolic, int diastolic) {
    var a = systolic - diastolic;
    var b = a / 3;
    var finalValue = diastolic + b;
    print('this is map value $finalValue');
    return finalValue;
  }

  List<double> mapList = [];
  List<String> mapDateLabels = [];
  var mapSum = 0.0;
  void getMapList(List<TrackingHistory> readings) {
    mapList.clear();
    for (var reading in readings) {
      final sys = int.tryParse(reading.sys) ?? 0;
      final dia = int.tryParse(reading.dia) ?? 0;
      // Only count valid readings
      if (sys > 0 && dia > 0) {
        double mapValue = calculateMAP(sys, dia);
        mapSum += mapValue;
        mapList.add(mapValue);
        final date = DateTime.fromMillisecondsSinceEpoch(reading.addedTime);
        String formattedTime =
            "${DateFormat('d').format(date)}\n${DateFormat('MMM').format(date)}";

        // String formattedTime =
        //     "${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')}\n${date.hour >= 12 ? 'PM' : 'AM'}";
        // String formattedTime = "${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')}";
        mapDateLabels.add(formattedTime);
      }
    }
    avgMap = mapSum / mapList.length;
    print('this is avg map=$avgMap');
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _getUserName();
    selectedList = filterHistoryByDateRange(
      widget.trackingHistory,
      widget.selectedDateRange,
    );
    // Sort by addedTime ascending (oldest to newest)
    selectedList.sort((a, b) => a.addedTime.compareTo(b.addedTime));
    getMapList(selectedList);
  }

  @override
  void didUpdateWidget(covariant MeanArterialPressure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDateRange != widget.selectedDateRange) {
      selectedList = filterHistoryByDateRange(
        widget.trackingHistory,
        widget.selectedDateRange,
      );
      // Sort by addedTime ascending (oldest to newest)
      selectedList.sort((a, b) => a.addedTime.compareTo(b.addedTime));
      getMapList(selectedList);
    }
  }

  List<TrackingHistory> selectedList = [];

  void _getUserName() {
    FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          userName = snapshot.get("name") ?? "User";
        });
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: widget.selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
      selectedList = filterHistoryByDateRange(widget.trackingHistory, picked);
      // Sort by addedTime ascending (oldest to newest)
      selectedList.sort((a, b) => a.addedTime.compareTo(b.addedTime));
      getMapList(selectedList);
    }
  }

  String _formatDateRange() {
    final start = widget.selectedDateRange.start;
    final end = widget.selectedDateRange.end;
    return "${start.day} ${_getMonthName(start.month)} - ${end.day} ${_getMonthName(end.month)}";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  List<TrackingHistory> filterHistoryByDateRange(
      List<TrackingHistory> list,
      DateTimeRange range,
      ) {
    return list.where((item) {
      final isInDateRange = RecordTime.isInRange(range, item.measuredAtMs);

      // ONLY include Blood Pressure records (exclude glucose and other vitals)
      if (item.trackerName == 'Blood Pressure') {
        bool hasValidValues =
            item.sys.toString().trim().isNotEmpty &&
                item.dia.toString().trim().isNotEmpty &&
                item.sys != '0' &&
                item.dia != '0';
        return isInDateRange && hasValidValues;
      }

      // Exclude all non-BP tracker types
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.10), Color(0xFFE8F5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello $userName',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset("assets/icons/appicon.jpg"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateRange(),
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onPressed: widget.nextTap,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  ' (${selectedList.length} measurements)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.bloodtype,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Average Mean Arterial\nPressure (MAP) - " +
                          avgMap.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Show graph or empty message
                mapList.isEmpty
                    ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueGrey.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text(
                    'No records',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
                    : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueGrey.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: LineChartWidget(
                      data: mapList,
                      labels: mapDateLabels,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      // Use the actual selected date range from the parent widget
                      await _sendComprehensiveBPReport(
                        context,
                        widget.selectedDateRange,
                      );
                    },
                    icon: Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      "Send Report",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 500,
                  child: Text(
                    "MAP is a calculation that doctors use to check whether there’s enough blood flow, resistance, and pressure to supply blood to all your major organs. ",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SpecialistCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/////BP Trend Indicator

class BPTrendIndicator extends StatefulWidget {
  VoidCallback nextTap;
  List<TrackingHistory> trackingHistory;
  final DateTimeRange selectedDateRange;
  final ValueChanged<DateTimeRange> onDateRangeChanged;

  BPTrendIndicator({
    super.key,
    required this.nextTap,
    required this.trackingHistory,
    required this.selectedDateRange,
    required this.onDateRangeChanged,
  });

  @override
  State<BPTrendIndicator> createState() => _BPTrendIndicatorState();
}

class _BPTrendIndicatorState extends State<BPTrendIndicator> {
  String userName = "Loading...";

  @override
  void initState() {
    super.initState();
    _getUserName();
    selectedList = filterHistoryByDateRange(
      widget.trackingHistory,
      widget.selectedDateRange,
    );
    getSysDiaValue(selectedList);
  }

  @override
  void didUpdateWidget(covariant BPTrendIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDateRange != widget.selectedDateRange) {
      selectedList = filterHistoryByDateRange(
        widget.trackingHistory,
        widget.selectedDateRange,
      );
      getSysDiaValue(selectedList);
    }
  }

  List<double> systolicListValue = [];
  List<double> diastolicListValue = [];

  void getSysDiaValue(List<TrackingHistory> readings) {
    systolicListValue.clear();
    diastolicListValue.clear();
    for (var reading in readings) {
      final sys = double.tryParse(reading.sys) ?? 0;
      final dia = double.tryParse(reading.dia) ?? 0;
      // Only count valid readings
      if (sys > 0 && dia > 0) {
        systolicListValue.add(sys);
        diastolicListValue.add(dia);
      }
    }
    setState(() {});
  }

  void _getUserName() {
    FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          userName = snapshot.get("name") ?? "User";
        });
      }
    });
  }

  List<TrackingHistory> filterHistoryByDateRange(
      List<TrackingHistory> list,
      DateTimeRange range,
      ) {
    return list.where((item) {
      final isInDateRange = RecordTime.isInRange(range, item.measuredAtMs);

      // ONLY include Blood Pressure records (exclude glucose and other vitals)
      if (item.trackerName == 'Blood Pressure') {
        bool hasValidValues =
            item.sys.toString().trim().isNotEmpty &&
                item.dia.toString().trim().isNotEmpty &&
                item.sys != '0' &&
                item.dia != '0';
        return isInDateRange && hasValidValues;
      }

      // Exclude all non-BP tracker types
      return false;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: widget.selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
      selectedList = filterHistoryByDateRange(widget.trackingHistory, picked);
      getSysDiaValue(selectedList);
    }
  }

  List<TrackingHistory> selectedList = [];

  String _formatDateRange() {
    final start = widget.selectedDateRange.start;
    final end = widget.selectedDateRange.end;
    return "${start.day} ${_getMonthName(start.month)} - ${end.day} ${_getMonthName(end.month)}";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  double calculateSlope(List<double> data) {
    debugPrint('list:::: $data');
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.10),
                  const Color(0xFFE8F5E9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello $userName',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset("assets/icons/appicon.jpg"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateRange(),
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onPressed: widget.nextTap,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  ' (${selectedList.length} measurements)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.redAccent, size: 32),
                    SizedBox(width: 10),
                    Text(
                      "BP Trend Indicator",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Builder(
                  builder: (context) {
                    // Get the latest valid SYS/DIA from selectedList
                    double sys = 0;
                    double dia = 0;

                    if (selectedList.isNotEmpty) {
                      sys = calculateSlope(systolicListValue.reversed.toList());
                      dia = calculateSlope(
                        diastolicListValue.reversed.toList(),
                      );
                    }
                    return BloodPressureDigitalCard(
                      sys: sys.toStringAsFixed(2),
                      dia: dia.toStringAsFixed(2),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      // Use the actual selected date range from the parent widget
                      await _sendComprehensiveBPReport(
                        context,
                        widget.selectedDateRange,
                      );
                    },
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      "Send Report",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 500,
                  child: const Text(
                    '''Blood Pressure Trend Indicator detects trends in your blood pressure measurements, such as if it's generally increasing or decreasing and by what amount.''',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SpecialistCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BloodPressureDigitalCard extends StatelessWidget {
  final String sys;
  final String dia;
  final bool isAlertOne;
  const BloodPressureDigitalCard({
    Key? key,
    required this.sys,
    required this.dia,
    this.isAlertOne = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 120,
      padding: const EdgeInsets.only(left: 20, top: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),

        // borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left section
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.favorite, color: Colors.black45, size: 20),
              SizedBox(height: 6),
              Text(
                'SYS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              Text(
                'mmHg',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              SizedBox(height: 12),
              Text(
                'DIA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              Text(
                'mmHg',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Right section
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white38,
                border: Border(
                  top: BorderSide(color: Colors.grey, width: 1.5),
                  left: BorderSide(color: Colors.grey, width: 1.5),
                  // No border on right and bottom
                ),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isAlertOne
                          ? const SizedBox.shrink()
                          : double.parse(sys) > 0
                          ? Icon(
                        Icons.arrow_upward,
                        size: 50,
                        color: isAlertOne ? Colors.blue : Colors.red,
                      )
                          : const Icon(
                        Icons.arrow_downward,
                        size: 50,
                        color: Colors.blue,
                      ),
                      Text(
                        sys.replaceAll('-', ''),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isAlertOne
                              ? Colors.blue
                              : double.parse(sys) > 0
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isAlertOne
                          ? const SizedBox.shrink()
                          : double.parse(dia) > 0
                          ? Icon(
                        Icons.arrow_upward,
                        size: 50,
                        color: isAlertOne ? Colors.blue : Colors.red,
                      )
                          : const Icon(
                        Icons.arrow_downward,
                        size: 50,
                        color: Colors.blue,
                      ),
                      Text(
                        dia.replaceAll('-', ''),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isAlertOne
                              ? Colors.blue
                              : double.parse(dia) > 0
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
