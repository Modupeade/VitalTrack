import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitals_10/models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userCollection = 'usersAlerts';
  final String _dummyCollection = 'dummyAlert';
  final String _dummyDocId = 'global_alerts';

  // Add or update alerts for a specific user
  Future<void> updateUserAlerts(
      String userId, Map<String, dynamic> alertsData) async {
    try {
      // Get current document to preserve subscription status
      final currentDoc =
      await _firestore.collection(_userCollection).doc(userId).get();
      if (currentDoc.exists) {
        // Preserve existing subscription status
        alertsData['subscription'] = currentDoc['subscription'] ?? false;
      }

      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .set(alertsData, SetOptions(merge: true));

      print('DEBUG: Updated user alerts for $userId');
      print(
          'DEBUG: Preserved subscription status: ${alertsData['subscription']}');
    } catch (e) {
      print('Error updating user alerts: $e');
      rethrow;
    }
  }

  // Get alerts based on subscription status
  Stream<Map<String, dynamic>?> getAlerts(String userId) async* {
    try {
      // First check subscription status
      final userDoc =
      await _firestore.collection(_userCollection).doc(userId).get();
      final bool isSubscribed =
      userDoc.exists ? userDoc['subscription'] ?? false : false;

      print('\n=== USER DATA DEBUG ===');
      print('User ID: $userId');
      print('Document exists: ${userDoc.exists}');
      print('Raw document data:');
      if (userDoc.exists) {
        final data = userDoc.data();
        print('{');
        data?.forEach((key, value) {
          print('  "$key": $value,');
        });
        print('}');
      }
      print('Subscription status: $isSubscribed');
      print('=====================\n');

      if (isSubscribed) {
        print('Using user-specific alerts from usersAlerts collection');
        // If subscribed, stream user's own alerts
        yield* _firestore
            .collection(_userCollection)
            .doc(userId)
            .snapshots()
            .map((doc) {
          if (doc.exists) {
            print('\n=== USER ALERTS DATA ===');
            final data = doc.data();
            log('{');
            data?.forEach((key, value) {
              log('  "$key": $value,');
            });
            log('}');
            print('=====================\n');
          }
          return doc.data();
        });
      } else {
        print('Using dummy alerts from dummyAlert collection');
        // If not subscribed, stream dummy alerts
        yield* _firestore
            .collection(_dummyCollection)
            .doc(_dummyDocId)
            .snapshots()
            .map((doc) {
          if (doc.exists) {
            print('\n=== DUMMY ALERTS DATA ===');
            final data = doc.data();
            print('{');
            data?.forEach((key, value) {
              log('  "$key": $value,');
            });
            print('}');
            print('=====================\n');
          }
          return doc.data();
        });
      }
    } catch (e) {
      print('Error getting alerts: $e');
      yield null;
    }
  }

  // Create user document with initial alerts data
  Future<void> createUserAlerts(String userId) async {
    try {
      // Check if document already exists
      final doc =
      await _firestore.collection(_userCollection).doc(userId).get();

      if (!doc.exists) {
        // Only create new document with initial data if it doesn't exist
        final initialData = {
          'subscription': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await updateUserAlerts(userId, initialData);
        print('DEBUG: Created new user document for user: $userId');
      } else {
        print('DEBUG: User document already exists for user: $userId');
        print('DEBUG: Current subscription status: ${doc['subscription']}');
      }
    } catch (e) {
      print('Error creating user alerts: $e');
      rethrow;
    }
  }

  // Create dummy alerts collection with initial data
  Future<void> createDummyAlerts() async {
    try {
      final dummyData = {
        'bp_alert': BloodPressureAlert(
          systolic: 119,
          diastolic: 77,
          trend: 'lower',
        ).toMap(),
        'time_in_target_alert': TimeInTargetAlert(
          percentage: 85.0,
          period: '11 - 17 Oct',
        ).toMap(),
        'map_alert': MAPAlert(
          value: 91.0,
          history: [
            {
              'date':
              DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
              'value': 80.0
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
              'value': 85.0
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
              'value': 90.0
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 4)).toIso8601String(),
              'value': 92.0
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 5)).toIso8601String(),
              'value': 95.0
            },
          ],
        ).toMap(),
        'bp_trend_alert': BPTrendAlert(
          trend: 'stable',
          history: [
            {
              'date':
              DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
              'systolic': 120,
              'diastolic': 80
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
              'systolic': 122,
              'diastolic': 82
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
              'systolic': 118,
              'diastolic': 78
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 4)).toIso8601String(),
              'systolic': 121,
              'diastolic': 79
            },
            {
              'date':
              DateTime.now().subtract(Duration(days: 5)).toIso8601String(),
              'systolic': 119,
              'diastolic': 77
            },
          ],
        ).toMap(),
      };

      await _firestore
          .collection(_dummyCollection)
          .doc(_dummyDocId)
          .set(dummyData);
      print('Dummy alerts created');
    } catch (e) {
      print('Error creating dummy alerts: $e');
      rethrow;
    }
  }

  // Update subscription status with duration
  Future<void> updateSubscription(String userId, bool status,
      {String? duration, String? subscriptionType, double? amount}) async {
    try {
      print('DEBUG: Updating subscription for $userId to $status');
      Map<String, dynamic> updateData = {'subscription': status};

      if (duration != null) {
        updateData['subscriptionDuration'] = duration;
      }
      if (subscriptionType != null) {
        updateData['subscriptionType'] = subscriptionType;
      }
      if (amount != null) {
        updateData['amount'] = amount;
      }

      await _firestore
          .collection(_userCollection)
          .doc(userId)
          .update(updateData);
      print('DEBUG: Subscription updated successfully');
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }

  // Get subscription status
  Future<bool> getSubscriptionStatus(String userId) async {
    try {
      final doc =
      await _firestore.collection(_userCollection).doc(userId).get();
      final status = doc.exists ? doc['subscription'] ?? false : false;
      print('DEBUG: Getting subscription status for $userId: $status');
      return status;
    } catch (e) {
      print('Error getting subscription status: $e');
      return false;
    }
  }

  // Get subscription details including duration
  Future<Map<String, dynamic>?> getSubscriptionDetails(String userId) async {
    try {
      final doc =
      await _firestore.collection(_userCollection).doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'subscription': data['subscription'] ?? false,
          'subscriptionDuration': data['subscriptionDuration'] ?? 'monthly',
          'subscriptionType': data['subscriptionType'] ?? 'monthly',
          'amount': data['amount'] ?? 4.99,
          'subscriptionDate': data['subscriptionDate'],
          'status': data['status'] ?? 'inactive',
        };
      }
      return null;
    } catch (e) {
      print('Error getting subscription details: $e');
      return null;
    }
  }
}
