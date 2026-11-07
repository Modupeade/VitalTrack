import 'package:facebook_app_events/facebook_app_events.dart';

/// Service for tracking Facebook Analytics events
class FacebookAnalyticsService {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  // Initialize Facebook Analytics
  static Future<void> initialize() async {
    try {
      await _facebookAppEvents.setAutoLogAppEventsEnabled(true);
      await _facebookAppEvents.setAdvertiserTracking(enabled: true);
      print('✅ Facebook Analytics initialized successfully');
    } catch (e) {
      print('❌ Error initializing Facebook Analytics: $e');
    }
  }

  // ========== Authentication Events ==========

  /// Track user registration/signup
  static Future<void> logSignUp({String? method}) async {
    try {
      await _facebookAppEvents.logCompletedRegistration(
        registrationMethod: method ?? 'email',
      );
      print('📊 Facebook Analytics: Sign Up tracked');
    } catch (e) {
      print('❌ Error logging sign up: $e');
    }
  }

  /// Track user login
  static Future<void> logLogin({String? method}) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'login',
        parameters: {
          'method': method ?? 'email',
        },
      );
      print('📊 Facebook Analytics: Login tracked');
    } catch (e) {
      print('❌ Error logging login: $e');
    }
  }

  /// Track email verification
  static Future<void> logEmailVerification({required bool success}) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'email_verification',
        parameters: {
          'success': success,
        },
      );
      print('📊 Facebook Analytics: Email verification tracked');
    } catch (e) {
      print('❌ Error logging email verification: $e');
    }
  }

  // ========== Health Tracking Events ==========

  /// Track BP (Blood Pressure) measurement added
  static Future<void> logBPMeasurementAdded({
    int? systolic,
    int? diastolic,
    int? pulse,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'bp_measurement_added',
        parameters: {
          if (systolic != null) 'systolic': systolic,
          if (diastolic != null) 'diastolic': diastolic,
          if (pulse != null) 'pulse': pulse,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: BP measurement tracked');
    } catch (e) {
      print('❌ Error logging BP measurement: $e');
    }
  }

  /// Track weight measurement added
  static Future<void> logWeightMeasurementAdded({
    required double weight,
    String? unit,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'weight_measurement_added',
        parameters: {
          'weight': weight,
          'unit': unit ?? 'kg',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Weight measurement tracked');
    } catch (e) {
      print('❌ Error logging weight measurement: $e');
    }
  }

  /// Track blood sugar measurement added
  static Future<void> logBloodSugarMeasurementAdded({
    required double glucose,
    String? unit,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'blood_sugar_measurement_added',
        parameters: {
          'glucose': glucose,
          'unit': unit ?? 'mg/dL',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Blood sugar measurement tracked');
    } catch (e) {
      print('❌ Error logging blood sugar measurement: $e');
    }
  }

  /// Track health tracker added
  static Future<void> logHealthTrackerAdded({required String trackerType}) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'health_tracker_added',
        parameters: {
          'tracker_type': trackerType,
        },
      );
      print('📊 Facebook Analytics: Health tracker added tracked');
    } catch (e) {
      print('❌ Error logging health tracker: $e');
    }
  }

  // ========== Medicine Events ==========

  /// Track medicine added
  static Future<void> logMedicineAdded({
    required String medicineName,
    String? medicineType,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'medicine_added',
        parameters: {
          'medicine_name': medicineName,
          if (medicineType != null) 'medicine_type': medicineType,
        },
      );
      print('📊 Facebook Analytics: Medicine added tracked');
    } catch (e) {
      print('❌ Error logging medicine added: $e');
    }
  }

  /// Track medicine taken
  static Future<void> logMedicineTaken({required String medicineName}) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'medicine_taken',
        parameters: {
          'medicine_name': medicineName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Medicine taken tracked');
    } catch (e) {
      print('❌ Error logging medicine taken: $e');
    }
  }

  // ========== Report Events ==========

  /// Track report generation
  static Future<void> logReportGenerated({
    required String reportType,
    String? dateRange,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'report_generated',
        parameters: {
          'report_type': reportType,
          if (dateRange != null) 'date_range': dateRange,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Report generated tracked');
    } catch (e) {
      print('❌ Error logging report generation: $e');
    }
  }

  /// Track report sent via email
  static Future<void> logReportEmailed({
    required String reportType,
    required bool success,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'report_emailed',
        parameters: {
          'report_type': reportType,
          'success': success,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Report emailed tracked');
    } catch (e) {
      print('❌ Error logging report email: $e');
    }
  }

  // ========== Alert Events ==========

  /// Track BP alert created
  static Future<void> logBPAlertCreated({
    String? alertType,
    int? threshold,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'bp_alert_created',
        parameters: {
          if (alertType != null) 'alert_type': alertType,
          if (threshold != null) 'threshold': threshold,
        },
      );
      print('📊 Facebook Analytics: BP alert created tracked');
    } catch (e) {
      print('❌ Error logging BP alert: $e');
    }
  }

  /// Track alert triggered
  static Future<void> logAlertTriggered({
    required String alertType,
    String? reason,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'alert_triggered',
        parameters: {
          'alert_type': alertType,
          if (reason != null) 'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Alert triggered tracked');
    } catch (e) {
      print('❌ Error logging alert triggered: $e');
    }
  }

  // ========== Consultation Events ==========

  /// Track consultation request
  static Future<void> logConsultationRequested() async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'consultation_requested',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: Consultation requested tracked');
    } catch (e) {
      print('❌ Error logging consultation request: $e');
    }
  }

  // ========== Navigation Events ==========

  /// Track screen view
  static Future<void> logScreenView({required String screenName}) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'screen_view',
        parameters: {
          'screen_name': screenName,
        },
      );
      print('📊 Facebook Analytics: Screen view tracked - $screenName');
    } catch (e) {
      print('❌ Error logging screen view: $e');
    }
  }

  /// Track profile view
  static Future<void> logProfileView() async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'profile_view',
      );
      print('📊 Facebook Analytics: Profile view tracked');
    } catch (e) {
      print('❌ Error logging profile view: $e');
    }
  }

  // ========== In-App Purchase Events ==========

  /// Track in-app purchase
  static Future<void> logPurchase({
    required double amount,
    required String currency,
    String? productId,
  }) async {
    try {
      await _facebookAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: {
          if (productId != null) 'product_id': productId,
        },
      );
      print('📊 Facebook Analytics: Purchase tracked');
    } catch (e) {
      print('❌ Error logging purchase: $e');
    }
  }

  /// Track subscription
  static Future<void> logSubscribe({
    required String subscriptionType,
    required double amount,
    String? currency,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'subscribe',
        parameters: {
          'subscription_type': subscriptionType,
          'amount': amount,
          'currency': currency ?? 'USD',
        },
      );
      print('📊 Facebook Analytics: Subscription tracked');
    } catch (e) {
      print('❌ Error logging subscription: $e');
    }
  }

  // ========== App Lifecycle Events ==========

  /// Track app open
  static Future<void> logAppOpen() async {
    try {
      await _facebookAppEvents.logEvent(
        name: 'app_open',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('📊 Facebook Analytics: App open tracked');
    } catch (e) {
      print('❌ Error logging app open: $e');
    }
  }

  // ========== Custom Events ==========

  /// Log a custom event with custom parameters
  static Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: eventName,
        parameters: parameters,
      );
      print('📊 Facebook Analytics: Custom event tracked - $eventName');
    } catch (e) {
      print('❌ Error logging custom event: $e');
    }
  }

  // ========== User Properties ==========

  /// Set user ID for tracking
  static Future<void> setUserId(String userId) async {
    try {
      await _facebookAppEvents.setUserID(userId);
      print('📊 Facebook Analytics: User ID set');
    } catch (e) {
      print('❌ Error setting user ID: $e');
    }
  }

  /// Clear user data
  static Future<void> clearUserData() async {
    try {
      await _facebookAppEvents.clearUserID();
      print('📊 Facebook Analytics: User data cleared');
    } catch (e) {
      print('❌ Error clearing user data: $e');
    }
  }

  /// Set user properties
  static Future<void> setUserData({
    String? email,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? city,
    String? state,
    String? country,
  }) async {
    try {
      await _facebookAppEvents.setUserData(
        email: email,
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        city: city,
        state: state,
        country: country,
      );
      print('📊 Facebook Analytics: User data set');
    } catch (e) {
      print('❌ Error setting user data: $e');
    }
  }

  // ========== Utility Methods ==========

  /// Flush pending events (force send to Facebook)
  static Future<void> flush() async {
    try {
      await _facebookAppEvents.flush();
      print('📊 Facebook Analytics: Events flushed');
    } catch (e) {
      print('❌ Error flushing events: $e');
    }
  }
}
