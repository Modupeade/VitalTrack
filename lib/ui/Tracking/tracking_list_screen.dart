// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// class TrackingListScreen extends StatefulWidget {
//   const TrackingListScreen({super.key});
//
//   @override
//   State<TrackingListScreen> createState() => _TrackingListScreenState();
// }
//
// class _TrackingListScreenState extends State<TrackingListScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   String _selectedTracker = '';
//
//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Tracking History'),
//           bottom: const TabBar(
//             tabs: [
//               Tab(text: 'All Data'),
//               Tab(text: 'By Tracker'),
//             ],
//           ),
//         ),
//         body: TabBarView(
//           children: [
//             // Tab 1: All Tracking History
//             StreamBuilder<QuerySnapshot>(
//               stream: _firestore
//                   .collection('trackingHistory')
//                   .where('uid', isEqualTo: _auth.currentUser?.uid)
//                   .orderBy('addedTime', descending: true)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//
//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                   return const Center(
//                       child: Text('No tracking data available'));
//                 }
//
//                 return ListView.builder(
//                   itemCount: snapshot.data!.docs.length,
//                   itemBuilder: (context, index) {
//                     final doc = snapshot.data!.docs[index];
//                     final data = doc.data() as Map<String, dynamic>;
//                     return Card(
//                       margin: const EdgeInsets.all(8),
//                       child: ListTile(
//                         title: Text(data['trackerName'] ?? 'Unknown'),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Value: ${data['value']}'),
//                             Text('Organization: ${data['organizationName']}'),
//                           ],
//                         ),
//                         trailing: Text(
//                           DateTime.fromMillisecondsSinceEpoch(
//                                   data['addedTime'] as int)
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
//             // Tab 2: By Tracker
//             Column(
//               children: [
//                 // Tracker Selection Dropdown
//                 StreamBuilder<QuerySnapshot>(
//                   stream: _firestore
//                       .collection('trackingHistory')
//                       .where('uid', isEqualTo: _auth.currentUser?.uid)
//                       .snapshots(),
//                   builder: (context, snapshot) {
//                     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                       return const Center(
//                           child: Text('No tracking data available'));
//                     }
//
//                     // Get unique tracker names
//                     final trackers = snapshot.data!.docs
//                         .map((doc) => (doc.data()
//                             as Map<String, dynamic>)['trackerName'] as String)
//                         .toSet()
//                         .toList();
//
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
//                   child: StreamBuilder<QuerySnapshot>(
//                     stream: _firestore
//                         .collection('trackingHistory')
//                         .where('uid', isEqualTo: _auth.currentUser?.uid)
//                         .where('trackerName', isEqualTo: _selectedTracker)
//                         .orderBy('addedTime', descending: false)
//                         .snapshots(),
//                     builder: (context, snapshot) {
//                       if (snapshot.connectionState == ConnectionState.waiting) {
//                         return const Center(child: CircularProgressIndicator());
//                       }
//
//                       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                         return const Center(
//                             child: Text('No data for selected tracker'));
//                       }
//
//                       final history = snapshot.data!.docs.map((doc) {
//                         final data = doc.data() as Map<String, dynamic>;
//                         return {
//                           'date': DateTime.fromMillisecondsSinceEpoch(
//                               data['addedTime'] as int),
//                           'value': data['value'] as num,
//                         };
//                       }).toList();
//
//                       return SfCartesianChart(
//                         primaryXAxis: DateTimeAxis(),
//                         series: <CartesianSeries<Map<String, dynamic>,
//                             DateTime>>[
//                           LineSeries<Map<String, dynamic>, DateTime>(
//                             dataSource: history,
//                             xValueMapper: (data, _) => data['date'] as DateTime,
//                             yValueMapper: (data, _) => data['value'] as num,
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
