// import 'package:flutter/material.dart';
// import 'package:vitals_10/controllers/tracking_history_controller.dart';
// import 'package:vitals_10/models/tracking_history_model.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// class TrackingHistoryScreen extends StatefulWidget {
//   const TrackingHistoryScreen({super.key});
//
//   @override
//   State<TrackingHistoryScreen> createState() => _TrackingHistoryScreenState();
// }
//
// class _TrackingHistoryScreenState extends State<TrackingHistoryScreen> {
//   // final TrackingHistoryController _controller = TrackingHistoryController();
//   String _selectedTracker = '';
//
//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 3,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Tracking History'),
//           bottom: const TabBar(
//             tabs: [
//               Tab(text: 'All Data'),
//               Tab(text: 'Latest Values'),
//               Tab(text: 'By Tracker'),
//             ],
//           ),
//         ),
//         body: TabBarView(
//           children: [
//             // Tab 1: All Tracking History
//             StreamBuilder<List<TrackingHistory>>(
//               stream: _controller.getTrackingHistory(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//
//                 if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(
//                       child: Text('No tracking data available'));
//                 }
//
//                 return ListView.builder(
//                   itemCount: snapshot.data!.length,
//                   itemBuilder: (context, index) {
//                     final entry = snapshot.data![index];
//                     return ListTile(
//                       title: Text(entry.trackerName),
//                       subtitle: Text('Value: ${entry.value}'),
//                       trailing: Text(
//                         DateTime.fromMillisecondsSinceEpoch(entry.addedTime)
//                             .toString()
//                             .split('.')[0],
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//
//             // Tab 2: Latest Values
//             StreamBuilder<Map<String, TrackingHistory>>(
//               stream: _controller.getLatestTrackingData(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//
//                 if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(
//                       child: Text('No tracking data available'));
//                 }
//
//                 return ListView.builder(
//                   itemCount: snapshot.data!.length,
//                   itemBuilder: (context, index) {
//                     final trackerName = snapshot.data!.keys.elementAt(index);
//                     final entry = snapshot.data![trackerName]!;
//                     return Card(
//                       margin: const EdgeInsets.all(8),
//                       child: ListTile(
//                         title: Text(trackerName),
//                         subtitle: Text('Latest Value: ${entry.value}'),
//                         trailing: Text(
//                           DateTime.fromMillisecondsSinceEpoch(entry.addedTime)
//                               .toString()
//                               .split('.')[0],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//
//             // Tab 3: By Tracker
//             Column(
//               children: [
//                 // Tracker Selection Dropdown
//                 StreamBuilder<Map<String, List<TrackingHistory>>>(
//                   stream: _controller.getGroupedTrackingHistory(),
//                   builder: (context, snapshot) {
//                     if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                       return const Center(
//                           child: Text('No tracking data available'));
//                     }
//
//                     final trackers = snapshot.data!.keys.toList();
//                     if (_selectedTracker.isEmpty && trackers.isNotEmpty) {
//                       _selectedTracker = trackers.first;
//                     }
//
//                     return Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: DropdownButton<String>(
//                         value: _selectedTracker,
//                         isExpanded: true,
//                         items: trackers.map((tracker) {
//                           return DropdownMenuItem(
//                             value: tracker,
//                             child: Text(tracker),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           if (value != null) {
//                             setState(() => _selectedTracker = value);
//                           }
//                         },
//                       ),
//                     );
//                   },
//                 ),
//
//                 // Selected Tracker History
//                 Expanded(
//                   child: StreamBuilder<List<TrackingHistory>>(
//                     stream: _controller.getTrackerHistory(_selectedTracker),
//                     builder: (context, snapshot) {
//                       if (snapshot.connectionState == ConnectionState.waiting) {
//                         return const Center(child: CircularProgressIndicator());
//                       }
//
//                       if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                         return const Center(
//                             child: Text('No data for selected tracker'));
//                       }
//
//                       final history = snapshot.data!;
//                       return SfCartesianChart(
//                         primaryXAxis: DateTimeAxis(),
//                         series: <CartesianSeries<TrackingHistory, DateTime>>[
//                           LineSeries<TrackingHistory, DateTime>(
//                             dataSource: history,
//                             xValueMapper: (data, _) =>
//                                 DateTime.fromMillisecondsSinceEpoch(
//                                     data.addedTime),
//                             yValueMapper: (data, _) => double.parse(data.value),
//                             name: _selectedTracker,
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
