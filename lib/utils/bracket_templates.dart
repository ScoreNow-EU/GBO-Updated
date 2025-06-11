import '../models/tournament.dart';
import 'bracket_id_helper.dart';

class BracketTemplates {
  /// Template for Women's U18, U16, and Fun - Group phase then direct 3rd vs 4th and 1st vs 2nd
  static List<CustomBracketNode> getSimpleBracketTemplate(String divisionName) {
    final gender = BracketIdHelper.getDivisionCode(divisionName);
    final cup = BracketIdHelper.getCupCode(divisionName);
    
    return [
      // Pool Stage
      CustomBracketNode(
        id: 'pool_stage',
        nodeType: 'pool',
        title: 'Group Phase',
        x: 100,
        y: 200,
        properties: {
          'pools': ['A', 'B'],
          'teamsPerPool': 4,
          'description': 'Pool stage with groups A and B',
        },
      ),
      
      // 3rd vs 4th Place Match
      CustomBracketNode(
        id: 'placement_3rd',
        nodeType: 'placement',
        title: '3rd Place Match',
        matchId: BracketIdHelper.generatePlacementId(gender, cup, 3),
        x: 400,
        y: 150,
        inputConnections: ['pool_stage'],
        properties: {
          'description': '4th from Pool A vs 3rd from Pool B',
        },
      ),
      
      // 1st vs 2nd Place Match (Final)
      CustomBracketNode(
        id: 'final',
        nodeType: 'match',
        title: 'Final',
        matchId: BracketIdHelper.generateMatchId(gender, cup, BracketIdHelper.FINALS, 1),
        x: 400,
        y: 250,
        inputConnections: ['pool_stage'],
        properties: {
          'description': '1st from Pool A vs 2nd from Pool B',
        },
      ),
    ];
  }
  
  /// Template for Men's and Women's Seniors - Complex bracket with specific match IDs
  static List<CustomBracketNode> getSeniorsBracketTemplate(String divisionName) {
    final gender = BracketIdHelper.getDivisionCode(divisionName);
    final cup = BracketIdHelper.SENIORS_CUP; // Always A cup for seniors
    
    return [
      // Pool Stage
      CustomBracketNode(
        id: 'pool_stage',
        nodeType: 'pool',
        title: 'Group Phase',
        x: 100,
        y: 300,
        properties: {
          'pools': ['A', 'B', 'C'],
          'teamsPerPool': 4,
          'description': 'Pool stage with groups A, B, and C',
        },
      ),
      
      // First Round Matches (Round of 16)
      CustomBracketNode(
        id: 'first_round_1',
        nodeType: 'match',
        title: 'Round of 16 - Match 1',
        matchId: '${gender}A81', // HA81 for men, DA81 for women
        x: 350,
        y: 200,
        inputConnections: ['pool_stage'],
        properties: {
          'description': '2nd Pool B vs 4th Pool C',
        },
      ),
      
      CustomBracketNode(
        id: 'first_round_2',
        nodeType: 'match',
        title: 'Round of 16 - Match 2',
        matchId: '${gender}A82',
        x: 350,
        y: 280,
        inputConnections: ['pool_stage'],
        properties: {
          'description': '2nd Pool C vs 4th Pool A',
        },
      ),
      
      CustomBracketNode(
        id: 'first_round_3',
        nodeType: 'match',
        title: 'Round of 16 - Match 3',
        matchId: '${gender}A83',
        x: 350,
        y: 360,
        inputConnections: ['pool_stage'],
        properties: {
          'description': '3rd Pool A vs 4th Pool B',
        },
      ),
      
      CustomBracketNode(
        id: 'first_round_4',
        nodeType: 'match',
        title: 'Round of 16 - Match 4',
        matchId: '${gender}A84',
        x: 350,
        y: 440,
        inputConnections: ['pool_stage'],
        properties: {
          'description': '3rd Pool B vs 3rd Pool C',
        },
      ),
      
      // Quarter Finals
      CustomBracketNode(
        id: 'quarter_final_1',
        nodeType: 'match',
        title: 'Quarter Final 1',
        matchId: '${gender}AV1',
        x: 600,
        y: 150,
        inputConnections: ['pool_stage', 'first_round_4'],
        properties: {
          'description': '1st Pool A vs Winner of Match 4',
        },
      ),
      
      CustomBracketNode(
        id: 'quarter_final_2',
        nodeType: 'match',
        title: 'Quarter Final 2',
        matchId: '${gender}AV2',
        x: 600,
        y: 230,
        inputConnections: ['pool_stage', 'first_round_2'],
        properties: {
          'description': '1st Pool B vs Winner of Match 2',
        },
      ),
      
      CustomBracketNode(
        id: 'quarter_final_3',
        nodeType: 'match',
        title: 'Quarter Final 3',
        matchId: '${gender}AV3',
        x: 600,
        y: 310,
        inputConnections: ['pool_stage', 'first_round_3'],
        properties: {
          'description': '1st Pool C vs Winner of Match 3',
        },
      ),
      
      CustomBracketNode(
        id: 'quarter_final_4',
        nodeType: 'match',
        title: 'Quarter Final 4',
        matchId: '${gender}AV4',
        x: 600,
        y: 390,
        inputConnections: ['pool_stage', 'first_round_1'],
        properties: {
          'description': '2nd Pool A vs Winner of Match 1',
        },
      ),
      
      // Places 5-8 Bracket
      CustomBracketNode(
        id: 'places_5_8_match_1',
        nodeType: 'match',
        title: 'Places 5-8 (Match 1)',
        matchId: '${gender}AL1',
        x: 850,
        y: 100,
        inputConnections: ['quarter_final_1', 'quarter_final_3'],
        properties: {
          'description': 'Loser QF1 vs Loser QF3',
        },
      ),
      
      CustomBracketNode(
        id: 'places_5_8_match_2',
        nodeType: 'match',
        title: 'Places 5-8 (Match 2)',
        matchId: '${gender}AL2',
        x: 850,
        y: 180,
        inputConnections: ['quarter_final_2', 'quarter_final_4'],
        properties: {
          'description': 'Loser QF2 vs Loser QF4',
        },
      ),
      
      // 5th Place Match
      CustomBracketNode(
        id: 'place_5_match',
        nodeType: 'placement',
        title: '5th Place Match',
        matchId: '${gender}AP5',
        x: 1100,
        y: 100,
        inputConnections: ['places_5_8_match_1', 'places_5_8_match_2'],
        properties: {
          'description': 'Winner Places 5-8 M1 vs Winner Places 5-8 M2',
        },
      ),
      
      // 7th Place Match
      CustomBracketNode(
        id: 'place_7_match',
        nodeType: 'placement',
        title: '7th Place Match',
        matchId: '${gender}AP7',
        x: 1100,
        y: 180,
        inputConnections: ['places_5_8_match_1', 'places_5_8_match_2'],
        properties: {
          'description': 'Loser Places 5-8 M1 vs Loser Places 5-8 M2',
        },
      ),
      
      // Semi Finals
      CustomBracketNode(
        id: 'semi_final_1',
        nodeType: 'match',
        title: 'Semi Final 1',
        matchId: '${gender}AH1',
        x: 850,
        y: 300,
        inputConnections: ['quarter_final_1', 'quarter_final_3'],
        properties: {
          'description': 'Winner QF1 vs Winner QF3',
        },
      ),
      
      CustomBracketNode(
        id: 'semi_final_2',
        nodeType: 'match',
        title: 'Semi Final 2',
        matchId: '${gender}AH2',
        x: 850,
        y: 380,
        inputConnections: ['quarter_final_2', 'quarter_final_4'],
        properties: {
          'description': 'Winner QF2 vs Winner QF4',
        },
      ),
      
      // Final
      CustomBracketNode(
        id: 'final',
        nodeType: 'match',
        title: 'Final',
        matchId: '${gender}AF',
        x: 1100,
        y: 320,
        inputConnections: ['semi_final_1', 'semi_final_2'],
        properties: {
          'description': 'Winner SF1 vs Winner SF2',
        },
      ),
      
      // 3rd Place Match
      CustomBracketNode(
        id: 'place_3_match',
        nodeType: 'placement',
        title: '3rd Place Match',
        matchId: '${gender}AP3',
        x: 1100,
        y: 400,
        inputConnections: ['semi_final_1', 'semi_final_2'],
        properties: {
          'description': 'Loser SF1 vs Loser SF2',
        },
      ),
    ];
  }
  
  /// Template for Men's Fun - Only Group Phase
  static List<CustomBracketNode> getFunOnlyTemplate(String divisionName) {
    return [
      CustomBracketNode(
        id: 'pool_stage_fun',
        nodeType: 'pool',
        title: 'Group Phase Only',
        x: 300,
        y: 300,
        properties: {
          'pools': ['A', 'B'],
          'teamsPerPool': 4,
          'description': 'Fun tournament - Group stage only, no elimination rounds',
        },
      ),
    ];
  }
  
  /// Get the appropriate template based on division name
  static List<CustomBracketNode> getTemplateForDivision(String divisionName) {
    final lowerDivision = divisionName.toLowerCase();
    
    if (lowerDivision.contains('men') && lowerDivision.contains('fun')) {
      return getFunOnlyTemplate(divisionName);
    } else if (lowerDivision.contains('senior')) {
      return getSeniorsBracketTemplate(divisionName);
    } else if (lowerDivision.contains('u18') || 
               lowerDivision.contains('u16') || 
               lowerDivision.contains('fun')) {
      return getSimpleBracketTemplate(divisionName);
    }
    
    // Default to simple bracket
    return getSimpleBracketTemplate(divisionName);
  }
  
  /// Get all available templates
  static Map<String, List<CustomBracketNode> Function(String)> getAllTemplates() {
    return {
      'Simple Bracket (U18/U16/Fun)': getSimpleBracketTemplate,
      'Seniors Complex Bracket': getSeniorsBracketTemplate,
      'Fun Only (Group Stage)': getFunOnlyTemplate,
    };
  }
} 