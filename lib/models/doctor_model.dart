import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String docId;
  final String name;
  final String email;
  final String hospital;
  final bool isBlocked;
  final String orgId;
  final String orgName;
  final Timestamp date;
  final double fee;

  Doctor({
    required this.docId,
    required this.name,
    required this.email,
    required this.hospital,
    required this.isBlocked,
    required this.orgId,
    required this.orgName,
    required this.date,
    required this.fee,
  });

  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Doctor(
      docId: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      hospital: data['hospital'] ?? '',
      isBlocked: data['isBlocked'] ?? false,
      orgId: data['orgID'] ?? '',
      orgName: data['orgName'] ?? '',
      date: data['date'] ?? Timestamp.now(),
      fee: (data['fee'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'hospital': hospital,
      'isBlocked': isBlocked,
      'orgID': orgId,
      'orgName': orgName,
      'date': date,
      'fee': fee,
    };
  }
}
