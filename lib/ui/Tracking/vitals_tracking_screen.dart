// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
//
// class VitalsTrackingScreen extends StatefulWidget {
//   const VitalsTrackingScreen({super.key});
//
//   @override
//   State<VitalsTrackingScreen> createState() => _VitalsTrackingScreenState();
// }
//
// class _VitalsTrackingScreenState extends State<VitalsTrackingScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   // List of vital trackers to display
//   final List<String> vitalTrackers = [
//     'Blood Pressure',
//     'Blood Sugar',s
//     'Weight',
//     'Heart Rate',
//     'Temperature',
//     'Oxygen Saturation'
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Vitals Tracking'),
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: _firestore
//             .collection('trackingHistory')
//             .where('uid', isEqualTo: _auth.currentUser?.uid)
//             // .orderBy('addedTime', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           print('current user id ${_auth.currentUser?.uid}');
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text('No vital readings available'));
//           }
//
//           // Group data by tracker name
//           final Map<String, List<Map<String, dynamic>>> groupedData = {};
//           for (var doc in snapshot.data!.docs) {
//             final data = doc.data() as Map<String, dynamic>;
//             final trackerName = data['trackerName'] as String;
//             if (!groupedData.containsKey(trackerName)) {
//               groupedData[trackerName] = [];
//             }
//             groupedData[trackerName]!.add(data);
//           }
//
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: vitalTrackers.length,
//             itemBuilder: (context, index) {
//               final trackerName = vitalTrackers[index];
//               final trackerData = groupedData[trackerName] ?? [];
//
//               if (trackerData.isEmpty) {
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   child: ListTile(
//                     title: Text(trackerName),
//                     subtitle: const Text('No readings available'),
//                   ),
//                 );
//               }
//
//               final latestReading = trackerData.first;
//               final history = trackerData
//                   .map((data) => {
//                         'date': DateTime.fromMillisecondsSinceEpoch(
//                             data['addedTime'] as int),
//                         'value': data['value'] as String,
//                       })
//                   .toList();
//
//               return Card(
//                 margin: const EdgeInsets.only(bottom: 16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             trackerName,
//                             style: const TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Latest Reading: ${latestReading['value']}',
//                             style: const TextStyle(
//                               fontSize: 16,
//                               color: Colors.grey,
//                             ),
//                           ),
//                           Text(
//                             'Organization: ${latestReading['dia']}',
//                             style: const TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey,
//                             ),
//                           ),
//                           Text(
//                             'Last Updated: ${DateTime.fromMillisecondsSinceEpoch(latestReading['addedTime'] as int).toString().split('.')[0]}',
//                             style: const TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(
//                       height: 200,
//                       child: SfCartesianChart(
//                         margin: const EdgeInsets.all(16),
//                         primaryXAxis: DateTimeAxis(
//                           dateFormat: DateFormat('MM/dd'),
//                           intervalType: DateTimeIntervalType.days,
//                           interval: 1,
//                         ),
//                         primaryYAxis: NumericAxis(
//                           title: AxisTitle(text: trackerName),
//                         ),
//                         series: <CartesianSeries<Map<String, dynamic>,
//                             DateTime>>[
//                           LineSeries<Map<String, dynamic>, DateTime>(
//                             dataSource: history,
//                             xValueMapper: (data, _) => data['date'] as DateTime,
//                             yValueMapper: (data, _) =>  double.parse(data['value'].toString().isEmpty?"0":data['value']),
//                             name: trackerName,
//                             markerSettings:
//                                 const MarkerSettings(isVisible: true),
//                             dataLabelSettings:
//                                 const DataLabelSettings(isVisible: true),
//                           ),
//                         ],
//                         tooltipBehavior: TooltipBehavior(enable: true),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
