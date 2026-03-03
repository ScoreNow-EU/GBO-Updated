import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'court.dart';
import 'tournament_link.dart';

/// Tracks a referee's availability for a tournament.
/// Status is entered by the admin after contacting the referee externally (e.g. email).
class RefereeInvitation {
  final String refereeId;
  /// Status: 'not_contacted', 'contacted', 'accepted', 'declined'
  final String status;
  final DateTime? respondedAt; // When admin entered the response
  final String? notes; // Admin notes
  // Availability window for the tournament day(s)
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool isFullDay;

  RefereeInvitation({
    required this.refereeId,
    this.status = 'not_contacted',
    this.respondedAt,
    this.notes,
    this.availableFrom,
    this.availableUntil,
    this.isFullDay = true,
  });

  bool get isNotContacted => status == 'not_contacted';
  bool get isContacted => status == 'contacted';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  /// All valid status values
  static const List<String> statusValues = [
    'not_contacted',
    'contacted',
    'accepted',
    'declined',
  ];

  /// German display labels for each status
  static String statusLabel(String status) {
    switch (status) {
      case 'not_contacted': return 'Nicht kontaktiert';
      case 'contacted': return 'Kontaktiert';
      case 'accepted': return 'Zugesagt';
      case 'declined': return 'Abgesagt';
      default: return status;
    }
  }

  /// Icon for each status
  static IconData statusIcon(String status) {
    switch (status) {
      case 'not_contacted': return Icons.person_outline;
      case 'contacted': return Icons.mail_outline;
      case 'accepted': return Icons.check_circle;
      case 'declined': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  /// Color for each status
  static Color statusColor(String status) {
    switch (status) {
      case 'not_contacted': return const Color(0xFF9E9E9E); // grey
      case 'contacted': return const Color(0xFFFFA726); // orange
      case 'accepted': return const Color(0xFF66BB6A); // green
      case 'declined': return const Color(0xFFEF5350); // red
      default: return const Color(0xFF9E9E9E);
    }
  }

  RefereeInvitation copyWith({
    String? refereeId,
    String? status,
    DateTime? respondedAt,
    String? notes,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool? isFullDay,
  }) {
    return RefereeInvitation(
      refereeId: refereeId ?? this.refereeId,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      notes: notes ?? this.notes,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      isFullDay: isFullDay ?? this.isFullDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'refereeId': refereeId,
      'status': status,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'notes': notes,
      'availableFrom': availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil': availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'isFullDay': isFullDay,
    };
  }

  factory RefereeInvitation.fromMap(Map<String, dynamic> map) {
    // Migrate old 'pending' status to 'not_contacted'
    String rawStatus = map['status'] ?? 'not_contacted';
    if (rawStatus == 'pending') rawStatus = 'not_contacted';
    return RefereeInvitation(
      refereeId: map['refereeId'] ?? '',
      status: rawStatus,
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
      availableFrom: (map['availableFrom'] as Timestamp?)?.toDate(),
      availableUntil: (map['availableUntil'] as Timestamp?)?.toDate(),
      isFullDay: map['isFullDay'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory RefereeInvitation.fromJson(Map<String, dynamic> json) => RefereeInvitation.fromMap(json);
}

/// Tracks a Kampfgericht member's availability for a tournament.
/// Kampfgericht = Zeitnehmer (Timekeeper) + Sekretär (Scorekeeper).
class KampfgerichtInvitation {
  final String memberId;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime? respondedAt;
  final String? notes;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool isFullDay;

  KampfgerichtInvitation({
    required this.memberId,
    required this.status,
    this.respondedAt,
    this.notes,
    this.availableFrom,
    this.availableUntil,
    this.isFullDay = true,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  KampfgerichtInvitation copyWith({
    String? memberId,
    String? status,
    DateTime? respondedAt,
    String? notes,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool? isFullDay,
  }) {
    return KampfgerichtInvitation(
      memberId: memberId ?? this.memberId,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      notes: notes ?? this.notes,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      isFullDay: isFullDay ?? this.isFullDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'status': status,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'notes': notes,
      'availableFrom': availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil': availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'isFullDay': isFullDay,
    };
  }

  factory KampfgerichtInvitation.fromMap(Map<String, dynamic> map) {
    return KampfgerichtInvitation(
      memberId: map['memberId'] ?? '',
      status: map['status'] ?? 'pending',
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
      availableFrom: (map['availableFrom'] as Timestamp?)?.toDate(),
      availableUntil: (map['availableUntil'] as Timestamp?)?.toDate(),
      isFullDay: map['isFullDay'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory KampfgerichtInvitation.fromJson(Map<String, dynamic> json) => KampfgerichtInvitation.fromMap(json);
}

class TournamentBracket {
  final Map<String, List<String>> pools; // poolId -> list of team IDs
  final Map<String, bool> poolIsFunBracket; // poolId -> is fun bracket
  final List<BracketRound> knockoutRounds; // Quarter, Semi, Final rounds
  
  TournamentBracket({
    this.pools = const {},
    this.poolIsFunBracket = const {},
    this.knockoutRounds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'pools': pools,
      'poolIsFunBracket': poolIsFunBracket,
      'knockoutRounds': knockoutRounds.map((round) => round.toMap()).toList(),
    };
  }

  factory TournamentBracket.fromMap(Map<String, dynamic> map) {
    // Properly handle pools conversion with nested List<String>
    Map<String, List<String>> pools = {};
    if (map['pools'] != null) {
      final poolsData = map['pools'] as Map<String, dynamic>;
      for (String key in poolsData.keys) {
        pools[key] = List<String>.from(poolsData[key] ?? []);
      }
    }
    
    return TournamentBracket(
      pools: pools,
      poolIsFunBracket: Map<String, bool>.from(map['poolIsFunBracket'] ?? {}),
      knockoutRounds: (map['knockoutRounds'] as List<dynamic>?)
          ?.map((round) => BracketRound.fromMap(round))
          .toList() ?? [],
    );
  }
}

class BracketRound {
  final String name; // "Quarter-finals", "Semi-finals", "Final", "3rd Place"
  final List<BracketMatch> matches;
  final int roundNumber; // 1 = quarters, 2 = semis, 3 = final
  
  BracketRound({
    required this.name,
    required this.matches,
    required this.roundNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'matches': matches.map((match) => match.toMap()).toList(),
      'roundNumber': roundNumber,
    };
  }

  factory BracketRound.fromMap(Map<String, dynamic> map) {
    return BracketRound(
      name: map['name'] ?? '',
      matches: (map['matches'] as List<dynamic>?)
          ?.map((match) => BracketMatch.fromMap(match))
          .toList() ?? [],
      roundNumber: map['roundNumber'] ?? 0,
    );
  }
}

class BracketMatch {
  final String id;
  final String? team1Id;
  final String? team2Id;
  final String? winnerId;
  final int? team1Score;
  final int? team2Score;
  final String status; // "pending", "in_progress", "completed"
  final DateTime? scheduledTime;
  final String bestOf; // "one", "three", "five"
  final List<Map<String, int>> subMatches; // For best of 3/5: [{team1: 2, team2: 1}, ...]
  
  BracketMatch({
    required this.id,
    this.team1Id,
    this.team2Id,
    this.winnerId,
    this.team1Score,
    this.team2Score,
    this.status = "pending",
    this.scheduledTime,
    this.bestOf = "one",
    this.subMatches = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team1Id': team1Id,
      'team2Id': team2Id,
      'winnerId': winnerId,
      'team1Score': team1Score,
      'team2Score': team2Score,
      'status': status,
      'scheduledTime': scheduledTime?.millisecondsSinceEpoch,
      'bestOf': bestOf,
      'subMatches': subMatches,
    };
  }

  factory BracketMatch.fromMap(Map<String, dynamic> map) {
    return BracketMatch(
      id: map['id'] ?? '',
      team1Id: map['team1Id'],
      team2Id: map['team2Id'],
      winnerId: map['winnerId'],
      team1Score: map['team1Score'],
      team2Score: map['team2Score'],
      status: map['status'] ?? 'pending',
      scheduledTime: map['scheduledTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduledTime'])
          : null,
      bestOf: map['bestOf'] ?? 'one',
      subMatches: List<Map<String, int>>.from(map['subMatches'] ?? []),
    );
  }
}

// New models for custom bracket builder
class CustomBracketNode {
  final String id;
  final String nodeType; // 'pool', 'match', 'placement'
  final String title;
  final String? matchId; // Custom match ID like HA81, HAV1, etc.
  final List<String> inputConnections; // IDs of nodes that feed into this one
  final List<String> outputConnections; // IDs of nodes this feeds into
  final double x; // Position on canvas
  final double y;
  final Map<String, dynamic> properties; // Additional properties like pool size, teams, etc.
  
  CustomBracketNode({
    required this.id,
    required this.nodeType,
    required this.title,
    this.matchId,
    this.inputConnections = const [],
    this.outputConnections = const [],
    required this.x,
    required this.y,
    this.properties = const {},
  });

  CustomBracketNode copyWith({
    String? id,
    String? nodeType,
    String? title,
    String? matchId,
    List<String>? inputConnections,
    List<String>? outputConnections,
    double? x,
    double? y,
    Map<String, dynamic>? properties,
  }) {
    return CustomBracketNode(
      id: id ?? this.id,
      nodeType: nodeType ?? this.nodeType,
      title: title ?? this.title,
      matchId: matchId ?? this.matchId,
      inputConnections: inputConnections ?? List.from(this.inputConnections),
      outputConnections: outputConnections ?? List.from(this.outputConnections),
      x: x ?? this.x,
      y: y ?? this.y,
      properties: properties ?? Map.from(this.properties),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nodeType': nodeType,
      'title': title,
      'matchId': matchId,
      'inputConnections': inputConnections,
      'outputConnections': outputConnections,
      'x': x,
      'y': y,
      'properties': properties,
    };
  }

  factory CustomBracketNode.fromMap(Map<String, dynamic> map) {
    return CustomBracketNode(
      id: map['id'] ?? '',
      nodeType: map['nodeType'] ?? '',
      title: map['title'] ?? '',
      matchId: map['matchId'],
      inputConnections: List<String>.from(map['inputConnections'] ?? []),
      outputConnections: List<String>.from(map['outputConnections'] ?? []),
      x: map['x']?.toDouble() ?? 0.0,
      y: map['y']?.toDouble() ?? 0.0,
      properties: Map<String, dynamic>.from(map['properties'] ?? {}),
    );
  }

  // Add JSON serialization methods for preset service
  Map<String, dynamic> toJson() => toMap();
  
  factory CustomBracketNode.fromJson(Map<String, dynamic> json) => CustomBracketNode.fromMap(json);
}

class CustomBracketStructure {
  final List<CustomBracketNode> nodes;
  final String divisionName;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  CustomBracketStructure({
    required this.nodes,
    required this.divisionName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'nodes': nodes.map((node) => node.toMap()).toList(),
      'divisionName': divisionName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CustomBracketStructure.fromMap(Map<String, dynamic> map) {
    return CustomBracketStructure(
      nodes: (map['nodes'] as List<dynamic>?)
          ?.map((node) => CustomBracketNode.fromMap(node))
          .toList() ?? [],
      divisionName: map['divisionName'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }
}

class Tournament {
  final String id;
  final String name;
  final String season; // e.g., "2025", "2026"
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'upcoming', 'ongoing', 'completed'
  final String? description;
  final String? imageUrl;
  final List<String> teamIds;
  final List<RefereeInvitation> refereeInvitations;
  final List<KampfgerichtInvitation> kampfgerichtInvitations;
  final List<String> delegateIds;
  final List<Map<String, dynamic>> refereeGespanne;
  final Map<String, TournamentBracket> divisionBrackets; // kept for bracket infra
  final Map<String, CustomBracketStructure> customBrackets;
  final List<Court> courts;
  final bool isRegistrationOpen;
  final DateTime? registrationDeadline;
  final Map<String, List<String>> pools;
  final Map<String, Map<String, dynamic>> poolMetadata;
  final Map<String, List<Map<String, dynamic>>>? results;
  final String? tournamentOrganizerId;
  final List<TournamentLink> links;
  // Approval workflow fields
  final String approvalStatus; // 'pending_approval', 'approved', 'rejected'
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  // Ausrichterverein – the team hosting the tournament (gets +3 Ligapunkte)
  final String? hostClubTeamId;
  // Venue address (for distance calculation to referee/Kampfgericht home addresses)
  final String? venueStreet;
  final String? venueHouseNumber;
  final String? venuePlz;
  final double? venueLatitude;
  final double? venueLongitude;

  static String determineSeason(DateTime startDate) {
    return startDate.year.toString();
  }

  Tournament({
    required this.id,
    required this.name,
    String? season,
    required this.location,
    required this.startDate,
    this.endDate,
    required this.status,
    this.description,
    this.imageUrl,
    this.teamIds = const [],
    this.refereeInvitations = const [],
    this.kampfgerichtInvitations = const [],
    this.delegateIds = const [],
    this.refereeGespanne = const [],
    this.divisionBrackets = const {},
    this.customBrackets = const {},
    this.courts = const [],
    this.isRegistrationOpen = true,
    this.registrationDeadline,
    Map<String, List<String>>? pools,
    Map<String, Map<String, dynamic>>? poolMetadata,
    this.results,
    this.tournamentOrganizerId,
    this.links = const [],
    this.approvalStatus = 'pending_approval',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.hostClubTeamId,
    this.venueStreet,
    this.venueHouseNumber,
    this.venuePlz,
    this.venueLatitude,
    this.venueLongitude,
  }) : 
    pools = pools ?? {},
    poolMetadata = poolMetadata ?? {},
    season = season ?? determineSeason(startDate);

  // Helper getter for backward compatibility
  List<String> get refereeIds => refereeInvitations.map((invitation) => invitation.refereeId).toList();

  /// Whether this tournament has valid venue coordinates for distance calculation
  bool get hasVenueCoordinates => venueLatitude != null && venueLongitude != null;

  /// Full formatted venue address string
  String? get venueAddress {
    final parts = <String>[];
    if (venueStreet != null && venueStreet!.isNotEmpty) {
      parts.add(venueHouseNumber != null && venueHouseNumber!.isNotEmpty
          ? '$venueStreet $venueHouseNumber'
          : venueStreet!);
    }
    if (venuePlz != null && venuePlz!.isNotEmpty || location.isNotEmpty) {
      parts.add('${venuePlz ?? ''} $location'.trim());
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  // Approval status helpers
  bool get isPendingApproval => approvalStatus == 'pending_approval';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  String get dateString {
    if (endDate != null) {
      return '${startDate.day}.${startDate.month} - ${endDate!.day}.${endDate!.month}.${endDate!.year}';
    } else {
      return '${startDate.day}.${startDate.month}.${startDate.year}';
    }
  }

  int get totalPlayingDays {
    if (endDate == null) return 1;
    return endDate!.difference(startDate).inDays + 1;
  }

  // Check if team is already registered
  bool isTeamRegistered(String teamId) {
    return teamIds.contains(teamId);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'season': determineSeason(startDate),
      'location': location,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'description': description,
      'imageUrl': imageUrl,
      'teamIds': teamIds,
      'refereeInvitations': refereeInvitations.map((invitation) => invitation.toMap()).toList(),
      'kampfgerichtInvitations': kampfgerichtInvitations.map((invitation) => invitation.toMap()).toList(),
      'delegateIds': delegateIds,
      'refereeGespanne': refereeGespanne,
      'divisionBrackets': divisionBrackets.map((key, value) => MapEntry(key, value.toMap())),
      'customBrackets': customBrackets.map((key, value) => MapEntry(key, value.toMap())),
      'courts': courts.map((court) => court.toMap()).toList(),
      'isRegistrationOpen': isRegistrationOpen,
      'registrationDeadline': registrationDeadline?.millisecondsSinceEpoch,
      'pools': pools,
      'poolMetadata': poolMetadata,
      'results': results,
      'tournamentOrganizerId': tournamentOrganizerId,
      'links': links.map((link) => link.toFirestore()).toList(),
      'approvalStatus': approvalStatus,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'rejectionReason': rejectionReason,
      'hostClubTeamId': hostClubTeamId,
      'venueStreet': venueStreet,
      'venueHouseNumber': venueHouseNumber,
      'venuePlz': venuePlz,
      'venueLatitude': venueLatitude,
      'venueLongitude': venueLongitude,
    };
  }

  factory Tournament.fromMap(Map<String, dynamic> map, [String? documentId]) {
    DateTime _convertToDateTime(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
      if (dateValue is DateTime) return dateValue;
      return DateTime.now();
    }

    final startDate = _convertToDateTime(map['startDate']);
    final season = map['season'] ?? determineSeason(startDate);

    return Tournament(
      id: documentId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      season: season,
      location: map['location'] ?? '',
      startDate: startDate,
      endDate: map['endDate'] != null 
        ? _convertToDateTime(map['endDate'])
        : null,
      status: map['status'] ?? 'upcoming',
      description: map['description'],
      imageUrl: map['imageUrl'],
      teamIds: List<String>.from(map['teamIds'] ?? []),
      refereeInvitations: map['refereeInvitations'] != null
        ? (map['refereeInvitations'] as List)
            .map((invitation) => RefereeInvitation.fromMap(invitation))
            .toList()
        : [],
      kampfgerichtInvitations: map['kampfgerichtInvitations'] != null
        ? (map['kampfgerichtInvitations'] as List)
            .map((invitation) => KampfgerichtInvitation.fromMap(invitation))
            .toList()
        : [],
      delegateIds: List<String>.from(map['delegateIds'] ?? []),
      refereeGespanne: List<Map<String, dynamic>>.from(map['refereeGespanne'] ?? []),
      divisionBrackets: map['divisionBrackets'] != null
        ? Map<String, TournamentBracket>.from(
            map['divisionBrackets'].map((key, value) => 
              MapEntry(key, TournamentBracket.fromMap(value))
            )
          )
        : {},
      customBrackets: map['customBrackets'] != null
        ? Map<String, CustomBracketStructure>.from(
            map['customBrackets'].map((key, value) => 
              MapEntry(key, CustomBracketStructure.fromMap(value))
            )
          )
        : {},
      courts: map['courts'] != null
        ? (map['courts'] as List).map((court) => Court.fromMap(court)).toList()
        : [],
      approvalStatus: map['approvalStatus'] ?? 'pending_approval',
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'])
        : null,
      rejectionReason: map['rejectionReason'],
      isRegistrationOpen: map['isRegistrationOpen'] ?? true,
      registrationDeadline: map['registrationDeadline'] != null
        ? _convertToDateTime(map['registrationDeadline'])
        : null,
      pools: map['pools'] != null
        ? Map<String, List<String>>.from(map['pools'])
        : {},
      poolMetadata: map['poolMetadata'] != null
        ? Map<String, Map<String, dynamic>>.from(map['poolMetadata'])
        : {},
      results: map['results'] != null
        ? _parseResults(map['results'])
        : null,
      tournamentOrganizerId: map['tournamentOrganizerId'],
      hostClubTeamId: map['hostClubTeamId'],
      venueStreet: map['venueStreet'],
      venueHouseNumber: map['venueHouseNumber'],
      venuePlz: map['venuePlz'],
      venueLatitude: map['venueLatitude']?.toDouble(),
      venueLongitude: map['venueLongitude']?.toDouble(),
      links: map['links'] != null
        ? (map['links'] as List).map((link) => TournamentLink.fromFirestore(link)).toList()
        : [],
    );
  }

  static Map<String, List<Map<String, dynamic>>>? _parseResults(dynamic resultsData) {
    if (resultsData == null) return null;
    
    final Map<String, List<Map<String, dynamic>>> results = {};
    
    if (resultsData is Map) {
      for (final entry in resultsData.entries) {
        final String key = entry.key.toString();
        final dynamic value = entry.value;
        
        if (value is List) {
          final List<Map<String, dynamic>> parsedResults = [];
          for (final item in value) {
            if (item is Map) {
              parsedResults.add(Map<String, dynamic>.from(item));
            }
          }
          results[key] = parsedResults;
        }
      }
    }
    
    return results;
  }

  Tournament copyWith({
    String? id,
    String? name,
    String? season,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? description,
    String? imageUrl,
    List<String>? teamIds,
    List<RefereeInvitation>? refereeInvitations,
    List<KampfgerichtInvitation>? kampfgerichtInvitations,
    List<String>? delegateIds,
    List<Map<String, dynamic>>? refereeGespanne,
    Map<String, TournamentBracket>? divisionBrackets,
    Map<String, CustomBracketStructure>? customBrackets,
    List<Court>? courts,
    bool? isRegistrationOpen,
    DateTime? registrationDeadline,
    Map<String, List<String>>? pools,
    Map<String, Map<String, dynamic>>? poolMetadata,
    Map<String, List<Map<String, dynamic>>>? results,
    String? tournamentOrganizerId,
    List<TournamentLink>? links,
    String? approvalStatus,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    String? hostClubTeamId,
    String? venueStreet,
    String? venueHouseNumber,
    String? venuePlz,
    double? venueLatitude,
    double? venueLongitude,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      season: season ?? this.season,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      teamIds: teamIds ?? List.from(this.teamIds),
      refereeInvitations: refereeInvitations ?? List.from(this.refereeInvitations),
      kampfgerichtInvitations: kampfgerichtInvitations ?? List.from(this.kampfgerichtInvitations),
      delegateIds: delegateIds ?? List.from(this.delegateIds),
      refereeGespanne: refereeGespanne ?? List.from(this.refereeGespanne),
      divisionBrackets: divisionBrackets ?? Map.from(this.divisionBrackets),
      customBrackets: customBrackets ?? Map.from(this.customBrackets),
      courts: courts ?? List.from(this.courts),
      isRegistrationOpen: isRegistrationOpen ?? this.isRegistrationOpen,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      pools: pools ?? Map.from(this.pools),
      poolMetadata: poolMetadata ?? Map.from(this.poolMetadata),
      results: results ?? this.results,
      tournamentOrganizerId: tournamentOrganizerId ?? this.tournamentOrganizerId,
      links: links ?? List.from(this.links),
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      hostClubTeamId: hostClubTeamId ?? this.hostClubTeamId,
      venueStreet: venueStreet ?? this.venueStreet,
      venueHouseNumber: venueHouseNumber ?? this.venueHouseNumber,
      venuePlz: venuePlz ?? this.venuePlz,
      venueLatitude: venueLatitude ?? this.venueLatitude,
      venueLongitude: venueLongitude ?? this.venueLongitude,
    );
  }
} 