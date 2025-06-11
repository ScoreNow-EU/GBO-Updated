class BracketIdHelper {
  // Gender codes
  static const String MENS = 'H'; // Herren
  static const String WOMENS = 'D'; // Damen
  
  // Cup type codes
  static const String SENIORS_CUP = 'A'; // A Cup (Seniors)
  static const String FUN_CUP = 'B'; // B Cup (Fun)
  
  // Round/Pool codes
  static const String POOL_A = 'A';
  static const String POOL_B = 'B';
  static const String POOL_C = 'C';
  static const String ROUND_OF_16 = '8'; // Achtelfinale
  static const String QUARTER_FINALS = 'V'; // Viertelfinale
  static const String SEMI_FINALS = 'H'; // Halbfinale
  static const String FINALS = 'F'; // Final
  static const String LOSERS_BRACKET = 'L'; // Placement 5-8
  static const String PLACEMENT = 'P'; // Specific place matches
  
  /// Generate a match ID based on the systematic convention
  /// Example: generateMatchId('H', 'A', 'V', 1) = 'HAV1'
  static String generateMatchId(String gender, String cup, String round, int number) {
    return '$gender$cup$round$number';
  }
  
  /// Generate placement match ID
  /// Example: generatePlacementId('H', 'A', 7) = 'HAP7'
  static String generatePlacementId(String gender, String cup, int place) {
    return '$gender$cup$PLACEMENT$place';
  }
  
  /// Parse a match ID and return its components
  static Map<String, dynamic> parseMatchId(String matchId) {
    if (matchId.length < 4) {
      return {'valid': false, 'error': 'ID too short'};
    }
    
    final gender = matchId[0];
    final cup = matchId[1];
    final round = matchId[2];
    final numberStr = matchId.substring(3);
    
    int? number;
    try {
      number = int.parse(numberStr);
    } catch (e) {
      return {'valid': false, 'error': 'Invalid number format'};
    }
    
    return {
      'valid': true,
      'gender': gender,
      'genderName': getGenderName(gender),
      'cup': cup,
      'cupName': getCupName(cup),
      'round': round,
      'roundName': getRoundName(round),
      'number': number,
      'isPlacement': round == PLACEMENT,
    };
  }
  
  /// Validate if a match ID follows the correct format
  static bool isValidMatchId(String matchId) {
    final parsed = parseMatchId(matchId);
    return parsed['valid'] == true;
  }
  
  /// Get human-readable gender name
  static String getGenderName(String code) {
    switch (code.toUpperCase()) {
      case MENS: return 'Men\'s';
      case WOMENS: return 'Women\'s';
      default: return 'Unknown';
    }
  }
  
  /// Get human-readable cup name
  static String getCupName(String code) {
    switch (code.toUpperCase()) {
      case SENIORS_CUP: return 'Seniors Cup';
      case FUN_CUP: return 'Fun Cup';
      default: return 'Unknown Cup';
    }
  }
  
  /// Get human-readable round name
  static String getRoundName(String code) {
    switch (code.toUpperCase()) {
      case POOL_A: return 'Pool A';
      case POOL_B: return 'Pool B';
      case POOL_C: return 'Pool C';
      case ROUND_OF_16: return 'Round of 16 (Achtelfinale)';
      case QUARTER_FINALS: return 'Quarter Finals (Viertelfinale)';
      case SEMI_FINALS: return 'Semi Finals (Halbfinale)';
      case FINALS: return 'Finals';
      case LOSERS_BRACKET: return 'Losers Bracket (Places 5-8)';
      case PLACEMENT: return 'Placement Match';
      default: return 'Unknown Round';
    }
  }
  
  /// Get division code from division name
  static String getDivisionCode(String divisionName) {
    if (divisionName.toLowerCase().contains('men') && !divisionName.toLowerCase().contains('women')) {
      return MENS;
    } else if (divisionName.toLowerCase().contains('women')) {
      return WOMENS;
    }
    return MENS; // Default fallback
  }
  
  /// Get cup code from division name
  static String getCupCode(String divisionName) {
    if (divisionName.toLowerCase().contains('fun')) {
      return FUN_CUP;
    } else if (divisionName.toLowerCase().contains('senior')) {
      return SENIORS_CUP;
    }
    return SENIORS_CUP; // Default fallback
  }
  
  /// Generate suggested match IDs for a division
  static Map<String, List<String>> generateSuggestedIds(String divisionName) {
    final gender = getDivisionCode(divisionName);
    final cup = getCupCode(divisionName);
    
    return {
      'Pool Stage': [
        generateMatchId(gender, cup, POOL_A, 1),
        generateMatchId(gender, cup, POOL_A, 2),
        generateMatchId(gender, cup, POOL_B, 1),
        generateMatchId(gender, cup, POOL_B, 2),
        generateMatchId(gender, cup, POOL_C, 1),
        generateMatchId(gender, cup, POOL_C, 2),
      ],
      'First Round': [
        generateMatchId(gender, cup, ROUND_OF_16, 1),
        generateMatchId(gender, cup, ROUND_OF_16, 2),
        generateMatchId(gender, cup, ROUND_OF_16, 3),
        generateMatchId(gender, cup, ROUND_OF_16, 4),
      ],
      'Quarter Finals': [
        generateMatchId(gender, cup, QUARTER_FINALS, 1),
        generateMatchId(gender, cup, QUARTER_FINALS, 2),
        generateMatchId(gender, cup, QUARTER_FINALS, 3),
        generateMatchId(gender, cup, QUARTER_FINALS, 4),
      ],
      'Semi Finals': [
        generateMatchId(gender, cup, SEMI_FINALS, 1),
        generateMatchId(gender, cup, SEMI_FINALS, 2),
      ],
      'Finals': [
        generateMatchId(gender, cup, FINALS, 1),
      ],
      'Losers Bracket': [
        generateMatchId(gender, cup, LOSERS_BRACKET, 1),
        generateMatchId(gender, cup, LOSERS_BRACKET, 2),
      ],
      'Placement': [
        generatePlacementId(gender, cup, 3),
        generatePlacementId(gender, cup, 5),
        generatePlacementId(gender, cup, 7),
      ],
    };
  }
} 