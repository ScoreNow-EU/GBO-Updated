import 'package:cloud_firestore/cloud_firestore.dart';

enum CoachAuthStatus {
  pending,
  approved,
  declined,
  expired,
}

class CoachAuthRequest {
  final String id;
  final String gameId;
  final String teamId;
  final String squadId;
  final String teamName;
  final String gameTitle; // e.g., "Team A vs Team B"
  final DateTime gameDate;
  final String requestedByUserId; // Team manager who made the request
  final String requestedByName;
  final DateTime requestTime;
  final String coachEmail; // Coach who should receive the request
  final String coachName;
  final CoachAuthStatus status;
  final DateTime? responseTime;
  final String? responseByUserId; // Coach who responded
  final String? responseByName;
  final String? responseMethod; // 'biometric', 'manual', etc.
  final DateTime expiresAt; // Request expires after certain time

  CoachAuthRequest({
    required this.id,
    required this.gameId,
    required this.teamId,
    required this.squadId,
    required this.teamName,
    required this.gameTitle,
    required this.gameDate,
    required this.requestedByUserId,
    required this.requestedByName,
    required this.requestTime,
    required this.coachEmail,
    required this.coachName,
    this.status = CoachAuthStatus.pending,
    this.responseTime,
    this.responseByUserId,
    this.responseByName,
    this.responseMethod,
    required this.expiresAt,
  });

  bool get isPending => status == CoachAuthStatus.pending;
  bool get isApproved => status == CoachAuthStatus.approved;
  bool get isDeclined => status == CoachAuthStatus.declined;
  bool get isExpired => status == CoachAuthStatus.expired || DateTime.now().isAfter(expiresAt);
  bool get isTimeCritical => isPending && expiresAt.difference(DateTime.now()).inMinutes <= 15;

  String get statusDisplayName {
    switch (status) {
      case CoachAuthStatus.pending:
        return 'Ausstehend';
      case CoachAuthStatus.approved:
        return 'Genehmigt';
      case CoachAuthStatus.declined:
        return 'Abgelehnt';
      case CoachAuthStatus.expired:
        return 'Abgelaufen';
    }
  }

  CoachAuthRequest copyWith({
    String? id,
    String? gameId,
    String? teamId,
    String? squadId,
    String? teamName,
    String? gameTitle,
    DateTime? gameDate,
    String? requestedByUserId,
    String? requestedByName,
    DateTime? requestTime,
    String? coachEmail,
    String? coachName,
    CoachAuthStatus? status,
    DateTime? responseTime,
    String? responseByUserId,
    String? responseByName,
    String? responseMethod,
    DateTime? expiresAt,
  }) {
    return CoachAuthRequest(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      teamId: teamId ?? this.teamId,
      squadId: squadId ?? this.squadId,
      teamName: teamName ?? this.teamName,
      gameTitle: gameTitle ?? this.gameTitle,
      gameDate: gameDate ?? this.gameDate,
      requestedByUserId: requestedByUserId ?? this.requestedByUserId,
      requestedByName: requestedByName ?? this.requestedByName,
      requestTime: requestTime ?? this.requestTime,
      coachEmail: coachEmail ?? this.coachEmail,
      coachName: coachName ?? this.coachName,
      status: status ?? this.status,
      responseTime: responseTime ?? this.responseTime,
      responseByUserId: responseByUserId ?? this.responseByUserId,
      responseByName: responseByName ?? this.responseByName,
      responseMethod: responseMethod ?? this.responseMethod,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameId': gameId,
      'teamId': teamId,
      'squadId': squadId,
      'teamName': teamName,
      'gameTitle': gameTitle,
      'gameDate': Timestamp.fromDate(gameDate),
      'requestedByUserId': requestedByUserId,
      'requestedByName': requestedByName,
      'requestTime': Timestamp.fromDate(requestTime),
      'coachEmail': coachEmail,
      'coachName': coachName,
      'status': status.toString().split('.').last,
      'responseTime': responseTime != null ? Timestamp.fromDate(responseTime!) : null,
      'responseByUserId': responseByUserId,
      'responseByName': responseByName,
      'responseMethod': responseMethod,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  static CoachAuthRequest fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return CoachAuthRequest(
      id: doc.id,
      gameId: data['gameId'] ?? '',
      teamId: data['teamId'] ?? '',
      squadId: data['squadId'] ?? '',
      teamName: data['teamName'] ?? '',
      gameTitle: data['gameTitle'] ?? '',
      gameDate: (data['gameDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestedByUserId: data['requestedByUserId'] ?? '',
      requestedByName: data['requestedByName'] ?? '',
      requestTime: (data['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      coachEmail: data['coachEmail'] ?? '',
      coachName: data['coachName'] ?? '',
      status: CoachAuthStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => CoachAuthStatus.pending,
      ),
      responseTime: (data['responseTime'] as Timestamp?)?.toDate(),
      responseByUserId: data['responseByUserId'],
      responseByName: data['responseByName'],
      responseMethod: data['responseMethod'],
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 2)),
    );
  }
} 