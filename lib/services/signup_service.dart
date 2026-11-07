import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupData {
  final String email;
  final String password;
  final String name;
  final List<String> selectedAchievement;
  final String gender;
  final String dob;
  final int dobTimeStamp;
  final String organizationID;
  final String organizationName;

  SignupData({
    required this.email,
    required this.password,
    required this.name,
    required this.selectedAchievement,
    required this.gender,
    required this.dob,
    required this.dobTimeStamp,
    required this.organizationID,
    required this.organizationName,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'toAchieve': selectedAchievement,
      'gender': gender,
      'dob': dob,
      'dobTimeStamp': dobTimeStamp,
      'organizationID': organizationID,
      'organizationName': organizationName,
    };
  }

  factory SignupData.fromMap(Map<String, dynamic> map) {
    return SignupData(
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      name: map['name'] ?? '',
      selectedAchievement: List<String>.from(map['toAchieve'] ?? []),
      gender: map['gender'] ?? '',
      dob: map['dob'] ?? '',
      dobTimeStamp: map['dobTimeStamp'] ?? 0,
      organizationID: map['organizationID'] ?? '',
      organizationName: map['organizationName'] ?? '',
    );
  }
}

class SignupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collectionName = 'pending_signups';

  /// Generate a 4-digit verification code
  static String generateVerificationCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Store signup data temporarily before account creation
  static Future<bool> storePendingSignup(
    SignupData data,
    String verificationCode,
  ) async {
    try {
      final codeExpiry = DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch;

      await _firestore.collection(_collectionName).doc(data.email).set({
        ...data.toMap(),
        'verificationCode': verificationCode,
        'codeExpiry': codeExpiry,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('Error storing pending signup: $e');
      return false;
    }
  }

  /// Retrieve pending signup by email
  static Future<SignupData?> getPendingSignup(String email) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(email).get();

      if (!doc.exists) {
        return null;
      }

      return SignupData.fromMap(doc.data()!);
    } catch (e) {
      print('Error getting pending signup: $e');
      return null;
    }
  }

  /// Get verification code and expiry for an email
  static Future<Map<String, dynamic>?> getVerificationData(
      String email) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(email).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return {
        'verificationCode': data['verificationCode'],
        'codeExpiry': data['codeExpiry'],
      };
    } catch (e) {
      print('Error getting verification data: $e');
      return null;
    }
  }

  /// Update verification code and expiry (for resend)
  static Future<bool> updateVerificationCode(
    String email,
    String newCode,
  ) async {
    try {
      final codeExpiry = DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch;

      await _firestore.collection(_collectionName).doc(email).update({
        'verificationCode': newCode,
        'codeExpiry': codeExpiry,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating verification code: $e');
      return false;
    }
  }

  /// Create Firebase account and user documents from pending signup
  static Future<UserCredential?> createAccountFromPendingSignup(
    String email,
    String password,
  ) async {
    try {
      // Get pending signup data
      final pendingData = await getPendingSignup(email);
      if (pendingData == null) {
        throw Exception('No pending signup found for this email');
      }

      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create user document
      await _firestore.collection('users').doc(uid).set({
        'email': pendingData.email,
        'name': pendingData.name,
        'toAchieve': pendingData.selectedAchievement,
        'gender': pendingData.gender,
        'dob': pendingData.dob,
        'dobTimeStamp': pendingData.dobTimeStamp,
        'uid': uid,
        'organizationID': pendingData.organizationID,
        'organizationName': pendingData.organizationName,
        'userID': DateTime.now().millisecondsSinceEpoch,
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create bp-threshold document
      await _firestore.collection('bp-threshold').doc(uid).set({
        'createdAt': FieldValue.serverTimestamp(),
        'diastolic': 80,
        'patientId': uid,
        'systolic': 120,
        'takenBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      print('Error creating account from pending signup: $e');
      rethrow;
    }
  }

  /// Complete pending signup (delete the pending document)
  static Future<bool> completePendingSignup(String email) async {
    try {
      await _firestore.collection(_collectionName).doc(email).delete();
      return true;
    } catch (e) {
      print('Error completing pending signup: $e');
      return false;
    }
  }

  /// Cleanup expired pending signups (older than 24 hours)
  static Future<void> cleanupExpiredPendingSignups() async {
    try {
      final cutoffTime = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;

      final expiredDocs = await _firestore
          .collection(_collectionName)
          .where('createdAt', isLessThan: cutoffTime)
          .get();

      for (var doc in expiredDocs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up expired pending signups: $e');
    }
  }
}
