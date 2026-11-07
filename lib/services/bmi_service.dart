import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Stores BMI for AI analysis.
///
/// Height comes from signup (`users.height` in metres).
/// BMI is calculated automatically whenever a weight reading is logged:
/// BMI = weight(kg) / height(m)^2
class BmiService {
  static const collection = 'bmi';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collection);

  static double? toKg(num weight, String unit) {
    final u = unit.toLowerCase().trim();
    if (u.contains('lb')) return weight.toDouble() * 0.453592;
    return weight.toDouble();
  }

  static double? calculate({
    required double heightMetres,
    required num weight,
    String weightUnit = 'kg',
  }) {
    if (heightMetres <= 0) return null;
    final kg = toKg(weight, weightUnit);
    if (kg == null || kg <= 0) return null;
    return kg / (heightMetres * heightMetres);
  }

  static String category(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  /// Called when height is saved at signup or from profile.
  /// Prepares BMI storage for the user (BMI fills when weight is logged).
  static Future<void> createOnSignup({
    required String uid,
    required double heightMetres,
  }) async {
    if (heightMetres <= 0) return;
    try {
      final id = _col.doc().id;
      await _col.doc(id).set({
        'id': id,
        'uid': uid,
        'userId': uid,
        'height': heightMetres,
        'heightUnit': 'metres',
        'weight': null,
        'weightUnit': 'kg',
        'bmi': null,
        'category': null,
        'status': 'awaiting_weight',
        'source': 'profile_or_signup',
        'date': DateTime.now().toIso8601String(),
        'addedTime': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'height': heightMetres,
        'heightUnit': 'metres',
        'bmiEnabled': true,
        'latestBmi': null,
      }, SetOptions(merge: true));

      debugPrint('bmi: height saved for $uid (height=$heightMetres m)');
    } catch (e) {
      debugPrint('bmi height save failed: $e');
    }
  }

  /// Recalculate and store BMI when the user logs a weight reading.
  static Future<void> recordFromWeight({
    required num weight,
    String weightUnit = 'kg',
    DateTime? measuredAt,
    String? trackingHistoryId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};
      final rawHeight = data['height'];
      final height = rawHeight is num
          ? rawHeight.toDouble()
          : double.tryParse(rawHeight?.toString() ?? '');
      if (height == null || height <= 0) {
        debugPrint('bmi: skipped — no signup height for $uid');
        return;
      }

      final bmi = calculate(
        heightMetres: height,
        weight: weight,
        weightUnit: weightUnit,
      );
      if (bmi == null) return;

      final when = measuredAt ?? DateTime.now();
      final id = _col.doc().id;
      final rounded = double.parse(bmi.toStringAsFixed(1));
      final cat = category(rounded);

      await _col.doc(id).set({
        'id': id,
        'uid': uid,
        'userId': uid,
        'height': height,
        'heightUnit': 'metres',
        'weight': weight,
        'weightUnit': weightUnit,
        'bmi': rounded,
        'category': cat,
        'status': 'calculated',
        'source': 'weight_log',
        if (trackingHistoryId != null) 'trackingHistoryId': trackingHistoryId,
        'date': when.toIso8601String(),
        'addedTime': when.millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'latestBmi': rounded,
        'latestBmiCategory': cat,
        'latestBmiAt': when.millisecondsSinceEpoch,
        'bmiEnabled': true,
      }, SetOptions(merge: true));

      debugPrint('bmi: stored $rounded ($cat) for $uid');
    } catch (e) {
      debugPrint('bmi recordFromWeight failed: $e');
    }
  }

  /// BMI records for AI analysis in the selected period.
  static Future<List<Map<String, dynamic>>> queryForRange(
    DateTimeRange range, {
    String? uid,
  }) async {
    final userId = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snap =
          await _col.where('uid', isEqualTo: userId).limit(2500).get();

      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      );

      final out = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['bmi'] == null) continue;

        final ms = (data['addedTime'] as num?)?.toInt();
        DateTime? dt;
        if (ms != null && ms > 0) {
          dt = DateTime.fromMillisecondsSinceEpoch(ms);
        } else {
          dt = DateTime.tryParse((data['date'] ?? '').toString());
        }
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(end)) continue;

        out.add({
          'id': doc.id,
          'date': data['date'],
          'height': data['height'],
          'heightUnit': data['heightUnit'] ?? 'metres',
          'weight': data['weight'],
          'weightUnit': data['weightUnit'] ?? 'kg',
          'bmi': data['bmi'],
          'category': data['category'],
        });
      }

      out.sort((a, b) {
        final da = DateTime.tryParse((a['date'] ?? '').toString());
        final db = DateTime.tryParse((b['date'] ?? '').toString());
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      debugPrint('bmi: ${out.length} records in period for $userId');
      if (out.length > 80) return out.take(80).toList();
      return out;
    } catch (e) {
      debugPrint('bmi query failed: $e');
      return [];
    }
  }
}
