class TournamentCriteria {
  // MUST Criteria (all 30 pts each)
  final bool officialBeachhandballRules;
  final bool twoRefereesPerGame;
  final bool cleanZone;
  final bool ausspielenPlatz1To8;

  // CAN Criteria - Referees (max 250 pts)
  final int ehfKaderReferees;        // 25 pts each
  final int dhbEliteKaderReferees;   // 20 pts each
  final int dhbStammKaderReferees;   // 15 pts each
  final int perspektivKaderReferees; // 10 pts each
  final int basisLizenzReferees;     // 5 pts each (max 50 pts total)

  // CAN Criteria - Officials (max 180 pts)
  final bool ebtDelegate;            // 100 pts
  final bool dhbNationalDelegate;    // 80 pts

  // CAN Criteria - Other
  final bool technicalMeeting;       // 20 pts (mandatory for Supercup)
  final int ebtStatus;               // EBT points (see _getEbtPoints)
  final String livestreamOption;     // Option 1-4 (see _getLivestreamPoints)
  final bool fangneatzeZaeune;       // 30 pts
  final bool sanitaeterdienst;       // 20 pts
  final bool sitztribuene;           // 60 pts
  final bool spielfeldumrandung;     // 30 pts
  final bool alleBeachplaetzeOffiziellesMasse; // 20 pts
  final bool gboOnlineSchedule;      // 100 pts
  final bool gboScoringSystem;       // 50 pts
  final bool elektronischeAnzeigetafeln; // 40 pts
  final bool zeitnehmerGestellt;     // 20 pts
  final bool gboJuniorsCup;          // 30 pts (automatic)
  final bool waterForPlayers;        // 20 pts
  final bool arenaCommentator;       // 20 pts
  final bool tournierauszeichnungen; // 20 pts
  final bool tournamentInTownCenter; // 250 pts
  final int tournamentDays;          // Number of tournament days (20 pts if > 1 day)

  TournamentCriteria({
    // MUST Criteria
    this.officialBeachhandballRules = false,
    this.twoRefereesPerGame = false,
    this.cleanZone = false,
    this.ausspielenPlatz1To8 = false,
    
    // CAN Criteria - Referees
    this.ehfKaderReferees = 0,
    this.dhbEliteKaderReferees = 0,
    this.dhbStammKaderReferees = 0,
    this.perspektivKaderReferees = 0,
    this.basisLizenzReferees = 0,
    
    // CAN Criteria - Officials
    this.ebtDelegate = false,
    this.dhbNationalDelegate = false,
    
    // CAN Criteria - Other
    this.technicalMeeting = false,
    this.ebtStatus = 0,
    this.livestreamOption = 'none',
    this.fangneatzeZaeune = false,
    this.sanitaeterdienst = false,
    this.sitztribuene = false,
    this.spielfeldumrandung = false,
    this.alleBeachplaetzeOffiziellesMasse = false,
    this.gboOnlineSchedule = false,
    this.gboScoringSystem = false,
    this.elektronischeAnzeigetafeln = false,
    this.zeitnehmerGestellt = false,
    this.gboJuniorsCup = false,
    this.waterForPlayers = false,
    this.arenaCommentator = false,
    this.tournierauszeichnungen = false,
    this.tournamentInTownCenter = false,
    this.tournamentDays = 1,
  });

  // Calculate total points
  int get totalPoints {
    int total = 0;
    
    // MUST Criteria (30 pts each)
    if (officialBeachhandballRules) total += 30;
    if (twoRefereesPerGame) total += 30;
    if (cleanZone) total += 30;
    if (ausspielenPlatz1To8) total += 30;
    
    // CAN Criteria - Referees (max 250 pts)
    int refereePoints = 0;
    refereePoints += ehfKaderReferees * 25;
    refereePoints += dhbEliteKaderReferees * 20;
    refereePoints += dhbStammKaderReferees * 15;
    refereePoints += perspektivKaderReferees * 10;
    refereePoints += (basisLizenzReferees * 5).clamp(0, 50); // max 50 pts for basis lizenz
    total += refereePoints.clamp(0, 250); // max 250 pts total for referees
    
    // CAN Criteria - Officials (max 180 pts)
    int officialPoints = 0;
    if (ebtDelegate) officialPoints += 100;
    if (dhbNationalDelegate) officialPoints += 80;
    total += officialPoints.clamp(0, 180); // max 180 pts for officials
    
    // CAN Criteria - Other
    if (technicalMeeting) total += 20;
    total += getEbtPoints();
    total += getLivestreamPoints();
    if (fangneatzeZaeune) total += 30;
    if (sanitaeterdienst) total += 20;
    if (sitztribuene) total += 60;
    if (spielfeldumrandung) total += 30;
    if (alleBeachplaetzeOffiziellesMasse) total += 20;
    if (gboOnlineSchedule) total += 100;
    if (gboScoringSystem) total += 50;
    if (elektronischeAnzeigetafeln) total += 40;
    if (zeitnehmerGestellt) total += 20;
    if (gboJuniorsCup) total += 30;
    if (waterForPlayers) total += 20;
    if (arenaCommentator) total += 20;
    if (tournierauszeichnungen) total += 20;
    if (tournamentInTownCenter) total += 250;
    if (tournamentDays > 1) total += 20; // Tournament days bonus
    
    return total;
  }

  // Calculate GBO Supercup bonus (150 pts if all criteria met)
  int get supercupBonus {
    if (checkSupercupEligibility()) {
      return 150;
    }
    return 0;
  }

  // Check if tournament is eligible for Supercup bonus
  bool checkSupercupEligibility() {
    // Get referee points
    int refereePoints = 0;
    refereePoints += ehfKaderReferees * 25;
    refereePoints += dhbEliteKaderReferees * 20;
    refereePoints += dhbStammKaderReferees * 15;
    refereePoints += perspektivKaderReferees * 10;
    refereePoints += (basisLizenzReferees * 5).clamp(0, 50);
    
    bool hasMinRefereePoints = refereePoints >= 150;
    bool hasDelegate = ebtDelegate || dhbNationalDelegate;
    bool hasInternetStreaming = livestreamOption != 'none'; // Any livestream is now acceptable
    
    // Calculate base points WITHOUT supercup bonus to avoid circular dependency
    int basePoints = 0;
    
    // MUST Criteria (30 pts each)
    if (officialBeachhandballRules) basePoints += 30;
    if (twoRefereesPerGame) basePoints += 30;
    if (cleanZone) basePoints += 30;
    if (ausspielenPlatz1To8) basePoints += 30;
    
    // CAN Criteria - Referees (max 250 pts)
    basePoints += refereePoints.clamp(0, 250);
    
    // CAN Criteria - Officials (max 180 pts)
    int officialPoints = 0;
    if (ebtDelegate) officialPoints += 100;
    if (dhbNationalDelegate) officialPoints += 80;
    basePoints += officialPoints.clamp(0, 180);
    
    // CAN Criteria - Other
    if (technicalMeeting) basePoints += 20;
    basePoints += getEbtPoints();
    basePoints += getLivestreamPoints();
    if (fangneatzeZaeune) basePoints += 30;
    if (sanitaeterdienst) basePoints += 20;
    if (sitztribuene) basePoints += 60;
    if (spielfeldumrandung) basePoints += 30;
    if (alleBeachplaetzeOffiziellesMasse) basePoints += 20;
    if (gboOnlineSchedule) basePoints += 100;
    if (gboScoringSystem) basePoints += 50;
    if (elektronischeAnzeigetafeln) basePoints += 40;
    if (zeitnehmerGestellt) basePoints += 20;
    if (gboJuniorsCup) basePoints += 30;
    if (waterForPlayers) basePoints += 20;
    if (arenaCommentator) basePoints += 20;
    if (tournierauszeichnungen) basePoints += 20;
    if (tournamentInTownCenter) basePoints += 250;
    if (tournamentDays > 1) basePoints += 20; // Tournament days bonus
    
    return hasMinRefereePoints &&
           zeitnehmerGestellt &&
           hasDelegate &&
           fangneatzeZaeune &&
           waterForPlayers &&
           basePoints >= 900 &&
           alleBeachplaetzeOffiziellesMasse &&
           hasInternetStreaming &&
           technicalMeeting;
  }

  // Helper function to calculate EBT points
  int getEbtPoints() {
    if (ebtStatus >= 300) return 150;
    if (ebtStatus >= 250) return 100;
    if (ebtStatus >= 200) return 80;
    if (ebtStatus >= 150) return 60;
    if (ebtStatus >= 100) return 40;
    if (ebtStatus >= 1) return 20;
    return 0;
  }

  // Helper function to calculate livestream points
  int getLivestreamPoints() {
    switch (livestreamOption) {
      case 'swtv_crew':
      case 'swtv_remote':
        return 250;
      case 'swtv_twitch':
        return 150;
      case 'own_stream':
        return 50;
      default:
        return 0;
    }
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'officialBeachhandballRules': officialBeachhandballRules,
      'twoRefereesPerGame': twoRefereesPerGame,
      'cleanZone': cleanZone,
      'ausspielenPlatz1To8': ausspielenPlatz1To8,
      'ehfKaderReferees': ehfKaderReferees,
      'dhbEliteKaderReferees': dhbEliteKaderReferees,
      'dhbStammKaderReferees': dhbStammKaderReferees,
      'perspektivKaderReferees': perspektivKaderReferees,
      'basisLizenzReferees': basisLizenzReferees,
      'ebtDelegate': ebtDelegate,
      'dhbNationalDelegate': dhbNationalDelegate,
      'technicalMeeting': technicalMeeting,
      'ebtStatus': ebtStatus,
      'livestreamOption': livestreamOption,
      'fangneatzeZaeune': fangneatzeZaeune,
      'sanitaeterdienst': sanitaeterdienst,
      'sitztribuene': sitztribuene,
      'spielfeldumrandung': spielfeldumrandung,
      'alleBeachplaetzeOffiziellesMasse': alleBeachplaetzeOffiziellesMasse,
      'gboOnlineSchedule': gboOnlineSchedule,
      'gboScoringSystem': gboScoringSystem,
      'elektronischeAnzeigetafeln': elektronischeAnzeigetafeln,
      'zeitnehmerGestellt': zeitnehmerGestellt,
      'gboJuniorsCup': gboJuniorsCup,
      'waterForPlayers': waterForPlayers,
      'arenaCommentator': arenaCommentator,
      'tournierauszeichnungen': tournierauszeichnungen,
      'tournamentInTownCenter': tournamentInTownCenter,
      'tournamentDays': tournamentDays,
    };
  }

  // Create from map for Firestore
  factory TournamentCriteria.fromMap(Map<String, dynamic> map) {
    return TournamentCriteria(
      officialBeachhandballRules: map['officialBeachhandballRules'] ?? false,
      twoRefereesPerGame: map['twoRefereesPerGame'] ?? false,
      cleanZone: map['cleanZone'] ?? false,
      ausspielenPlatz1To8: map['ausspielenPlatz1To8'] ?? false,
      ehfKaderReferees: map['ehfKaderReferees'] ?? 0,
      dhbEliteKaderReferees: map['dhbEliteKaderReferees'] ?? 0,
      dhbStammKaderReferees: map['dhbStammKaderReferees'] ?? 0,
      perspektivKaderReferees: map['perspektivKaderReferees'] ?? 0,
      basisLizenzReferees: map['basisLizenzReferees'] ?? 0,
      ebtDelegate: map['ebtDelegate'] ?? false,
      dhbNationalDelegate: map['dhbNationalDelegate'] ?? false,
      technicalMeeting: map['technicalMeeting'] ?? false,
      ebtStatus: map['ebtStatus'] ?? 0,
      livestreamOption: map['livestreamOption'] ?? 'none',
      fangneatzeZaeune: map['fangneatzeZaeune'] ?? false,
      sanitaeterdienst: map['sanitaeterdienst'] ?? false,
      sitztribuene: map['sitztribuene'] ?? false,
      spielfeldumrandung: map['spielfeldumrandung'] ?? false,
      alleBeachplaetzeOffiziellesMasse: map['alleBeachplaetzeOffiziellesMasse'] ?? false,
      gboOnlineSchedule: map['gboOnlineSchedule'] ?? false,
      gboScoringSystem: map['gboScoringSystem'] ?? false,
      elektronischeAnzeigetafeln: map['elektronischeAnzeigetafeln'] ?? false,
      zeitnehmerGestellt: map['zeitnehmerGestellt'] ?? false,
      gboJuniorsCup: map['gboJuniorsCup'] ?? false,
      waterForPlayers: map['waterForPlayers'] ?? false,
      arenaCommentator: map['arenaCommentator'] ?? false,
      tournierauszeichnungen: map['tournierauszeichnungen'] ?? false,
      tournamentInTownCenter: map['tournamentInTownCenter'] ?? false,
      tournamentDays: map['tournamentDays'] ?? 1,
    );
  }

  // Create a copy with updated values
  TournamentCriteria copyWith({
    bool? officialBeachhandballRules,
    bool? twoRefereesPerGame,
    bool? cleanZone,
    bool? ausspielenPlatz1To8,
    int? ehfKaderReferees,
    int? dhbEliteKaderReferees,
    int? dhbStammKaderReferees,
    int? perspektivKaderReferees,
    int? basisLizenzReferees,
    bool? ebtDelegate,
    bool? dhbNationalDelegate,
    bool? technicalMeeting,
    int? ebtStatus,
    String? livestreamOption,
    bool? fangneatzeZaeune,
    bool? sanitaeterdienst,
    bool? sitztribuene,
    bool? spielfeldumrandung,
    bool? alleBeachplaetzeOffiziellesMasse,
    bool? gboOnlineSchedule,
    bool? gboScoringSystem,
    bool? elektronischeAnzeigetafeln,
    bool? zeitnehmerGestellt,
    bool? gboJuniorsCup,
    bool? waterForPlayers,
    bool? arenaCommentator,
    bool? tournierauszeichnungen,
    bool? tournamentInTownCenter,
    int? tournamentDays,
  }) {
    return TournamentCriteria(
      officialBeachhandballRules: officialBeachhandballRules ?? this.officialBeachhandballRules,
      twoRefereesPerGame: twoRefereesPerGame ?? this.twoRefereesPerGame,
      cleanZone: cleanZone ?? this.cleanZone,
      ausspielenPlatz1To8: ausspielenPlatz1To8 ?? this.ausspielenPlatz1To8,
      ehfKaderReferees: ehfKaderReferees ?? this.ehfKaderReferees,
      dhbEliteKaderReferees: dhbEliteKaderReferees ?? this.dhbEliteKaderReferees,
      dhbStammKaderReferees: dhbStammKaderReferees ?? this.dhbStammKaderReferees,
      perspektivKaderReferees: perspektivKaderReferees ?? this.perspektivKaderReferees,
      basisLizenzReferees: basisLizenzReferees ?? this.basisLizenzReferees,
      ebtDelegate: ebtDelegate ?? this.ebtDelegate,
      dhbNationalDelegate: dhbNationalDelegate ?? this.dhbNationalDelegate,
      technicalMeeting: technicalMeeting ?? this.technicalMeeting,
      ebtStatus: ebtStatus ?? this.ebtStatus,
      livestreamOption: livestreamOption ?? this.livestreamOption,
      fangneatzeZaeune: fangneatzeZaeune ?? this.fangneatzeZaeune,
      sanitaeterdienst: sanitaeterdienst ?? this.sanitaeterdienst,
      sitztribuene: sitztribuene ?? this.sitztribuene,
      spielfeldumrandung: spielfeldumrandung ?? this.spielfeldumrandung,
      alleBeachplaetzeOffiziellesMasse: alleBeachplaetzeOffiziellesMasse ?? this.alleBeachplaetzeOffiziellesMasse,
      gboOnlineSchedule: gboOnlineSchedule ?? this.gboOnlineSchedule,
      gboScoringSystem: gboScoringSystem ?? this.gboScoringSystem,
      elektronischeAnzeigetafeln: elektronischeAnzeigetafeln ?? this.elektronischeAnzeigetafeln,
      zeitnehmerGestellt: zeitnehmerGestellt ?? this.zeitnehmerGestellt,
      gboJuniorsCup: gboJuniorsCup ?? this.gboJuniorsCup,
      waterForPlayers: waterForPlayers ?? this.waterForPlayers,
      arenaCommentator: arenaCommentator ?? this.arenaCommentator,
      tournierauszeichnungen: tournierauszeichnungen ?? this.tournierauszeichnungen,
      tournamentInTownCenter: tournamentInTownCenter ?? this.tournamentInTownCenter,
      tournamentDays: tournamentDays ?? this.tournamentDays,
    );
  }
} 