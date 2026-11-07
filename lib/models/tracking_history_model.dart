import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitals_10/utils/record_time.dart';

class TrackingHistory {
  final int addedTime;
  final String dia;
  final List<String> disease;
  final String dob;
  final String email;
  final String gender;
  final String name;
  final String organizationID;
  final String organizationName;
  final String sys;
  final String pulse;
  final String trackerID;
  final String trackerName;
  final String trackingHistoryID;
  final String uid;
  final String value;
  final String recordedTime;

  TrackingHistory({
    required this.addedTime,
    required this.dia,
    required this.disease,
    required this.dob,
    required this.email,
    required this.gender,
    required this.name,
    required this.organizationID,
    required this.organizationName,
    required this.sys,
    this.pulse = '',
    required this.trackerID,
    required this.trackerName,
    required this.trackingHistoryID,
    required this.uid,
    required this.value,
    this.recordedTime = '',
  });

  int? get measuredAtMs => RecordTime.resolve(
        time: recordedTime,
        addedTime: addedTime,
      );

  factory TrackingHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrackingHistory(
      addedTime: RecordTime.toEpochMs(data['addedTime']) ?? 0,
      recordedTime: (data['time'] ?? data['date'] ?? '').toString(),
      dia: (data['dia'] ?? '0').toString(),
      disease: List<String>.from(data['disease'] ?? []),
      dob: data['dob'] ?? '',
      email: data['email'] ?? '',
      gender: data['gender'] ?? '',
      name: data['name'] ?? '',
      organizationID: data['organizationID'] ?? '',
      organizationName: data['organizationName'] ?? '',
      sys: (data['sys'] ?? '0').toString(),
      pulse: (data['pulse'] ?? '').toString(),
      trackerID: data['trackerID'] ?? '',
      trackerName: data['trackerName'] ?? '',
      trackingHistoryID: data['trackingHistoryID'] ?? '',
      uid: data['uid'] ?? '',
      value: (data['value'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addedTime': addedTime,
      'dia': dia,
      'disease': disease,
      'dob': dob,
      'email': email,
      'gender': gender,
      'name': name,
      'organizationID': organizationID,
      'organizationName': organizationName,
      'sys': sys,
      'pulse': pulse,
      'trackerID': trackerID,
      'trackerName': trackerName,
      'trackingHistoryID': trackingHistoryID,
      'uid': uid,
      'value': value,
      if (recordedTime.isNotEmpty) 'time': recordedTime,
    };
  }
}
