import 'package:cloud_firestore/cloud_firestore.dart';
import 'tournament_criteria.dart';
import 'court.dart';
import 'tournament_link.dart';

class RefereeInvitation {
  final String refereeId;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime invitedAt;
  final DateTime? respondedAt;
  final String? notes; // Optional notes from referee

  RefereeInvitation({
    required this.refereeId,
    required this.status,
    required this.invitedAt,
    this.respondedAt,
    this.notes,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  RefereeInvitation copyWith({
    String? refereeId,
    String? status,
    DateTime? invitedAt,
    DateTime? respondedAt,
    String? notes,
  }) {
    return RefereeInvitation(
      refereeId: refereeId ?? this.refereeId,
      status: status ?? this.status,
      invitedAt: invitedAt ?? this.invitedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'refereeId': refereeId,
      'status': status,
      'invitedAt': Timestamp.fromDate(invitedAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'notes': notes,
    };
  }

  factory RefereeInvitation.fromMap(Map<String, dynamic> map) {
    return RefereeInvitation(
      refereeId: map['refereeId'] ?? '',
      status: map['status'] ?? 'pending',
      invitedAt: (map['invitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory RefereeInvitation.fromJson(Map<String, dynamic> json) => RefereeInvitation.fromMap(json);
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
  final List<String> categories;
  final String season; // e.g., "2025", "2026"
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  // Add category-specific dates for separate tournament scheduling
  final Map<String, DateTime>? categoryStartDates; // category -> specific start date
  final Map<String, DateTime>? categoryEndDates; // category -> specific end date
  final int points;
  final String status; // 'upcoming', 'ongoing', 'completed'
  final String? description;
  final String? imageUrl; // Tournament image URL
  final List<String> teamIds; // Team IDs
  final List<RefereeInvitation> refereeInvitations; // Referee invitations with status
  final List<String> delegateIds; // Delegate IDs
  final List<Map<String, dynamic>> refereeGespanne; // Referee pairs
  final Map<String, TournamentBracket> divisionBrackets; // division -> bracket structure
  final Map<String, CustomBracketStructure> customBrackets; // division -> custom bracket structure
  final TournamentCriteria? criteria; // Tournament criteria for Seniors Cup
  final List<Court> courts; // Courts available for this tournament
  final List<String> divisions; // Available divisions for this tournament
  final Map<String, List<String>> divisionTeams; // division -> list of team IDs
  final Map<String, int> divisionMaxTeams; // division -> max teams allowed
  final bool isRegistrationOpen; // Whether team registration is open
  final DateTime? registrationDeadline; // When registration closes
  // Changed pools to store more data per pool
  final Map<String, List<String>> pools;
  final Map<String, Map<String, dynamic>> poolMetadata; // Store additional pool data
  // Tournament results by division
  final Map<String, List<Map<String, dynamic>>>? results; // division -> list of team results
  final String? tournamentOrganizerId; // ID of the tournament organizer
  final List<TournamentLink> links; // Custom links for Ausschreibungen/AGBs and social media
  // Approval workflow fields
  final String approvalStatus; // 'pending_approval', 'approved', 'rejected'
  final String? approvedBy; // User ID who approved/rejected
  final DateTime? approvedAt; // When it was approved/rejected
  final String? rejectionReason; // Reason for rejection if rejected

  // Static method to determine season
  static String determineSeason(DateTime startDate) {
    // If tournament starts between January and December of a year, 
    // assign it to that year's season
    return startDate.year.toString();
  }

  Tournament({
    required this.id,
    required this.name,
    required this.categories,
    String? season, // Make season optional
    required this.location,
    required this.startDate,
    this.endDate,
    this.categoryStartDates,
    this.categoryEndDates,
    required this.points,
    required this.status,
    this.description,
    this.imageUrl,
    this.teamIds = const [],
    this.refereeInvitations = const [],
    this.delegateIds = const [],
    this.refereeGespanne = const [],
    this.divisionBrackets = const {},
    this.customBrackets = const {},
    this.criteria,
    this.courts = const [],
    this.divisions = const [],
    this.divisionTeams = const {},
    this.divisionMaxTeams = const {},
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
  }) : 
    pools = pools ?? {},
    poolMetadata = poolMetadata ?? {},
    season = season ?? determineSeason(startDate);

  String get category => categories.isNotEmpty ? categories.first : '';
  
  String get categoryDisplayNames => categories.join(', ');
  
  bool hasCategory(String category) {
    return categories.contains(category);
  }

  // Helper getter for backward compatibility
  List<String> get refereeIds => refereeInvitations.map((invitation) => invitation.refereeId).toList();
  
  bool get isJuniors => categories.contains('GBO Juniors Cup');
  
  bool get isSeniors => categories.contains('GBO Seniors Cup');
  
  // Approval status helpers
  bool get isPendingApproval => approvalStatus == 'pending_approval';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  // Get start date for specific category or fallback to main startDate
  DateTime getStartDateForCategory(String category) {
    return categoryStartDates?[category] ?? startDate;
  }

  // Get end date for specific category or fallback to main endDate
  DateTime? getEndDateForCategory(String category) {
    return categoryEndDates?[category] ?? endDate;
  }

  // Get playing days for specific category
  int getPlayingDaysForCategory(String category) {
    final startDate = getStartDateForCategory(category);
    final endDate = getEndDateForCategory(category);
    if (endDate == null) return 1;
    return endDate.difference(startDate).inDays + 1;
  }

  // Get playing days points for specific category (20 points for multi-day tournaments)
  int getPlayingDaysPointsForCategory(String category) {
    return getPlayingDaysForCategory(category) > 1 ? 20 : 0;
  }

  String get dateString {
    if (categoryStartDates != null && categoryStartDates!.isNotEmpty) {
      // If we have category-specific dates, show them
      List<String> dateStrings = [];
      for (String category in categories) {
        final catStart = getStartDateForCategory(category);
        final catEnd = getEndDateForCategory(category);
        String categoryShort = category.contains('Juniors') ? 'Jugend' : 'Senioren';
        if (catEnd != null) {
          dateStrings.add('$categoryShort: ${catStart.day}.${catStart.month} - ${catEnd.day}.${catEnd.month}.${catEnd.year}');
        } else {
          dateStrings.add('$categoryShort: ${catStart.day}.${catStart.month}.${catStart.year}');
        }
      }
      return dateStrings.join(' / ');
    } else {
      // Fallback to main dates
      if (endDate != null) {
        return '${startDate.day}.${startDate.month} - ${endDate!.day}.${endDate!.month}.${endDate!.year}';
      } else {
        return '${startDate.day}.${startDate.month}.${startDate.year}';
      }
    }
  }

  // Get total playing days across all categories
  int get totalPlayingDays {
    if (categoryStartDates != null && categoryStartDates!.isNotEmpty) {
      int maxDays = 0;
      for (String category in categories) {
        maxDays = maxDays > getPlayingDaysForCategory(category) ? maxDays : getPlayingDaysForCategory(category);
      }
      return maxDays;
    } else {
      if (endDate == null) return 1;
      return endDate!.difference(startDate).inDays + 1;
    }
  }

  // Calculate total points including criteria if it's a Seniors Cup
  int get totalPointsWithCriteria {
    if (isSeniors && criteria != null) {
      return criteria!.totalPoints + criteria!.supercupBonus;
    }
    return points;
  }

  // Check if a team can register for a specific division
  bool canRegisterForDivision(String division, String teamDivision) {
    if (!divisions.contains(division)) return false;
    if (!isRegistrationOpen) return false;
    if (registrationDeadline != null && DateTime.now().isAfter(registrationDeadline!)) return false;
    
    // For seniors teams, allow registration in either their regular division or FUN division
    bool canRegister = false;
    if (teamDivision.contains('Seniors')) {
      // Seniors team can register for their division or corresponding FUN division
      String funDivision = teamDivision.replaceAll('Seniors', 'FUN');
      canRegister = (division == teamDivision) || (division == funDivision);
    } else {
      // Non-seniors teams must match exactly
      canRegister = (division == teamDivision);
    }
    
    if (!canRegister) return false;
    
    // Check if division has space
    final currentTeams = divisionTeams[division] ?? [];
    final maxTeams = divisionMaxTeams[division] ?? 32; // Default max
    
    return currentTeams.length < maxTeams;
  }

  // Get registered teams count for a division
  int getRegisteredTeamsCount(String division) {
    return divisionTeams[division]?.length ?? 0;
  }

  // Get max teams allowed for a division
  int getMaxTeamsForDivision(String division) {
    return divisionMaxTeams[division] ?? 32;
  }

  // Check if team is already registered for any division
  bool isTeamRegistered(String teamId) {
    for (final teams in divisionTeams.values) {
      if (teams.contains(teamId)) return true;
    }
    return false;
  }

  // Get division that a team is registered for
  String? getTeamDivision(String teamId) {
    for (final entry in divisionTeams.entries) {
      if (entry.value.contains(teamId)) return entry.key;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categories': categories,
      'season': determineSeason(startDate), // Always use dynamic season determination
      'location': location,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'categoryStartDates': categoryStartDates?.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
      'categoryEndDates': categoryEndDates?.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
      'points': points,
      'status': status,
      'description': description,
      'imageUrl': imageUrl,
      'teamIds': teamIds,
      'refereeInvitations': refereeInvitations.map((invitation) => invitation.toMap()).toList(),
      'delegateIds': delegateIds,
      'refereeGespanne': refereeGespanne,
      'divisionBrackets': divisionBrackets.map((key, value) => MapEntry(key, value.toMap())),
      'customBrackets': customBrackets.map((key, value) => MapEntry(key, value.toMap())),
      'criteria': criteria?.toMap(),
      'courts': courts.map((court) => court.toMap()).toList(),
      'divisions': divisions,
      'divisionTeams': divisionTeams,
      'divisionMaxTeams': divisionMaxTeams,
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
    };
  }

  // Factory method to update season dynamically during deserialization
  factory Tournament.fromMap(Map<String, dynamic> map, [String? documentId]) {
    // Helper method to convert Timestamp or int to DateTime
    DateTime _convertToDateTime(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
      if (dateValue is DateTime) return dateValue;
      return DateTime.now(); // Fallback
    }

    // Helper method to convert Timestamp or int maps
    Map<String, DateTime>? _convertDateMap(Map<String, dynamic>? inputMap) {
      if (inputMap == null) return null;
      
      return inputMap.map((key, value) {
        return MapEntry(key, _convertToDateTime(value));
      });
    }

    // Determine start date with robust conversion
    final startDate = _convertToDateTime(map['startDate']);
    
    // Override season with dynamically determined season if not explicitly set
    final season = map['season'] ?? determineSeason(startDate);

    // Parse category-specific dates
    final categoryStartDates = _convertDateMap(map['categoryStartDates'] is Map 
        ? Map<String, dynamic>.from(map['categoryStartDates']) 
        : null);
    
    final categoryEndDates = _convertDateMap(map['categoryEndDates'] is Map 
        ? Map<String, dynamic>.from(map['categoryEndDates']) 
        : null);

    return Tournament(
      id: documentId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      season: season,
      location: map['location'] ?? '',
      startDate: startDate,
      endDate: map['endDate'] != null 
        ? _convertToDateTime(map['endDate'])
        : null,
      categoryStartDates: categoryStartDates,
      categoryEndDates: categoryEndDates,
      points: (map['points'] is int) 
        ? map['points'] 
        : (map['points'] is double) 
          ? (map['points'] as double).toInt() 
          : 0,
      status: map['status'] ?? 'upcoming',
      description: map['description'],
      imageUrl: map['imageUrl'],
      teamIds: List<String>.from(map['teamIds'] ?? []),
      refereeInvitations: map['refereeInvitations'] != null
        ? (map['refereeInvitations'] as List)
            .map((invitation) => RefereeInvitation.fromMap(invitation))
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
      criteria: map['criteria'] != null 
        ? TournamentCriteria.fromMap(map['criteria']) 
        : null,
      courts: map['courts'] != null
        ? (map['courts'] as List).map((court) => Court.fromMap(court)).toList()
        : [],
      divisions: List<String>.from(map['divisions'] ?? []),
      divisionTeams: map['divisionTeams'] != null
        ? Map<String, List<String>>.from(map['divisionTeams'])
        : {},
      divisionMaxTeams: map['divisionMaxTeams'] != null
        ? Map<String, int>.from(map['divisionMaxTeams'])
        : {},
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
      links: map['links'] != null
        ? (map['links'] as List).map((link) => TournamentLink.fromFirestore(link)).toList()
        : [],
    );
  }

  // Helper method to parse results from Firestore
  static Map<String, List<Map<String, dynamic>>>? _parseResults(dynamic resultsData) {
    if (resultsData == null) return null;
    
    final Map<String, List<Map<String, dynamic>>> results = {};
    
    if (resultsData is Map) {
      for (final entry in resultsData.entries) {
        final String key = entry.key.toString();
        final dynamic value = entry.value;
        
        if (value is List) {
          final List<Map<String, dynamic>> divisionResults = [];
          for (final item in value) {
            if (item is Map) {
              divisionResults.add(Map<String, dynamic>.from(item));
            }
          }
          results[key] = divisionResults;
        }
      }
    }
    
    return results;
  }

  // Add copyWith method
  Tournament copyWith({
    String? id,
    String? name,
    List<String>? categories,
    String? season,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, DateTime>? categoryStartDates,
    Map<String, DateTime>? categoryEndDates,
    int? points,
    String? status,
    String? description,
    String? imageUrl,
    List<String>? teamIds,
    List<RefereeInvitation>? refereeInvitations,
    List<String>? delegateIds,
    List<Map<String, dynamic>>? refereeGespanne,
    Map<String, TournamentBracket>? divisionBrackets,
    Map<String, CustomBracketStructure>? customBrackets,
    TournamentCriteria? criteria,
    List<Court>? courts,
    List<String>? divisions,
    Map<String, List<String>>? divisionTeams,
    Map<String, int>? divisionMaxTeams,
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
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      categories: categories ?? List.from(this.categories),
      season: season ?? this.season,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryStartDates: categoryStartDates ?? Map.from(this.categoryStartDates ?? {}),
      categoryEndDates: categoryEndDates ?? Map.from(this.categoryEndDates ?? {}),
      points: points ?? this.points,
      status: status ?? this.status,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      teamIds: teamIds ?? List.from(this.teamIds),
      refereeInvitations: refereeInvitations ?? List.from(this.refereeInvitations),
      delegateIds: delegateIds ?? List.from(this.delegateIds),
      refereeGespanne: refereeGespanne ?? List.from(this.refereeGespanne),
      divisionBrackets: divisionBrackets ?? Map.from(this.divisionBrackets),
      customBrackets: customBrackets ?? Map.from(this.customBrackets),
      criteria: criteria ?? this.criteria,
      courts: courts ?? List.from(this.courts),
      divisions: divisions ?? List.from(this.divisions),
      divisionTeams: divisionTeams ?? Map.from(this.divisionTeams),
      divisionMaxTeams: divisionMaxTeams ?? Map.from(this.divisionMaxTeams),
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
    );
  }
} 