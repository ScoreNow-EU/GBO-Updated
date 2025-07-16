import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String deviceId;
  final bool? faceIdEnabled; // true/false/null
  final String? deviceName; // Optional device name
  final DateTime lastUsed;

  Device({
    required this.deviceId,
    this.faceIdEnabled,
    this.deviceName,
    required this.lastUsed,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'faceIdEnabled': faceIdEnabled,
      'deviceName': deviceName,
      'lastUsed': Timestamp.fromDate(lastUsed),
    };
  }

  static Device fromFirestore(Map<String, dynamic> data) {
    return Device(
      deviceId: data['deviceId'] ?? '',
      faceIdEnabled: data['faceIdEnabled'], // Can be null
      deviceName: data['deviceName'],
      lastUsed: data['lastUsed'] != null 
          ? (data['lastUsed'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Device copyWith({
    String? deviceId,
    bool? faceIdEnabled,
    String? deviceName,
    DateTime? lastUsed,
  }) {
    return Device(
      deviceId: deviceId ?? this.deviceId,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      deviceName: deviceName ?? this.deviceName,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
} 