import 'package:cloud_firestore/cloud_firestore.dart';

class AlertData {
                                               
  final String id;
  final String type;
  final Map<String, dynamic> data; 
  final DateTime timestamp;                     
                                    
  AlertData({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });
                                                 
  factory AlertData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AlertData(
      id: doc.id,
      type: data['type'] ?? '',
      data: data['data'] ?? {},
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
  
// Specific alert types
class BloodPressureAlert {
  final int systolic;
  final int diastolic;
  final String trend;

  BloodPressureAlert({
    required this.systolic,
    required this.diastolic,
    required this.trend,
  });

  Map<String, dynamic> toMap() {
    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'trend': trend,
    };
  }

  factory BloodPressureAlert.fromMap(Map<String, dynamic> map) {
    return BloodPressureAlert(
      systolic: map['systolic'] ?? 0,
      diastolic: map['diastolic'] ?? 0,
      trend: map['trend'] ?? '',
    );
  }                                  
}
  
class TimeInTargetAlert {
  final double percentage;
  final String period;

  TimeInTargetAlert({
    required this.percentage,
    required this.period,
  });

  Map<String, dynamic> toMap() {
    return {
      'percentage': percentage,
      'period': period,
    };
  }

  factory TimeInTargetAlert.fromMap(Map<String, dynamic> map) {
    return TimeInTargetAlert(
      percentage: map['percentage']?.toDouble() ?? 0.0,
      period: map['period'] ?? '',
    );
  }
}

class MAPAlert {
  final double value;
  final List<Map<String, dynamic>> history;

  MAPAlert({
    required this.value,
    required this.history,
  });

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'history': history,
    };
  }

  factory MAPAlert.fromMap(Map<String, dynamic> map) {
    return MAPAlert(
      value: map['value']?.toDouble() ?? 0.0,
      history: List<Map<String, dynamic>>.from(map['history'] ?? []),
    );
  }
}

class BPTrendAlert {
  final String trend;
  final List<Map<String, dynamic>> history;

  BPTrendAlert({
    required this.trend,
    required this.history,
  });

  Map<String, dynamic> toMap() {
    return {
      'trend': trend,
      'history': history,
    };
  }

  factory BPTrendAlert.fromMap(Map<String, dynamic> map) {
    return BPTrendAlert(
      trend: map['trend'] ?? '',
      history: List<Map<String, dynamic>>.from(map['history'] ?? []),
    );
  }
}
