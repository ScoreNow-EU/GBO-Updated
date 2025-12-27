enum TabletConnectionStatus {
  connected,
  disconnected,
  unknown,
}

class TabletStatus {
  final String courtId;
  final String? tabletId;
  final TabletConnectionStatus connectionStatus;
  final int? batteryPercentage; // 0-100, null if unknown
  final DateTime lastSeen;
  final String? deviceName;

  TabletStatus({
    required this.courtId,
    this.tabletId,
    required this.connectionStatus,
    this.batteryPercentage,
    required this.lastSeen,
    this.deviceName,
  });

  bool get isConnected => connectionStatus == TabletConnectionStatus.connected;
  
  bool get hasLowBattery => batteryPercentage != null && batteryPercentage! < 20;
  
  bool get hasCriticalBattery => batteryPercentage != null && batteryPercentage! < 10;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'courtId': courtId,
      'tabletId': tabletId,
      'connectionStatus': connectionStatus.name,
      'batteryPercentage': batteryPercentage,
      'lastSeen': lastSeen.toIso8601String(),
      'deviceName': deviceName,
    };
  }

  // Create from Map
  factory TabletStatus.fromMap(Map<String, dynamic> map) {
    return TabletStatus(
      courtId: map['courtId'] ?? '',
      tabletId: map['tabletId'],
      connectionStatus: TabletConnectionStatus.values.firstWhere(
        (status) => status.name == map['connectionStatus'],
        orElse: () => TabletConnectionStatus.unknown,
      ),
      batteryPercentage: map['batteryPercentage']?.toInt(),
      lastSeen: DateTime.parse(map['lastSeen'] ?? DateTime.now().toIso8601String()),
      deviceName: map['deviceName'],
    );
  }

  // Copy with new values
  TabletStatus copyWith({
    String? courtId,
    String? tabletId,
    TabletConnectionStatus? connectionStatus,
    int? batteryPercentage,
    DateTime? lastSeen,
    String? deviceName,
  }) {
    return TabletStatus(
      courtId: courtId ?? this.courtId,
      tabletId: tabletId ?? this.tabletId,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      lastSeen: lastSeen ?? this.lastSeen,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TabletStatus && 
           other.courtId == courtId && 
           other.tabletId == tabletId;
  }

  @override
  int get hashCode => courtId.hashCode ^ (tabletId?.hashCode ?? 0);

  @override
  String toString() {
    return 'TabletStatus(courtId: $courtId, tabletId: $tabletId, connectionStatus: $connectionStatus, batteryPercentage: $batteryPercentage)';
  }
}
