import 'dart:math';
import '../models/game.dart';
import '../models/tournament.dart';
import '../models/court.dart';
import '../models/team.dart';
import 'game_service.dart';
import 'team_service.dart';
import 'package:flutter/material.dart';

class BreakSlot {
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String description;
  final bool blocksAllCourts;
  
  BreakSlot({
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description = '',
    this.blocksAllCourts = true,
  });
}

class SchedulingResult {
  final bool success;
  final int scheduledGames;
  final int unscheduledGames;
  final int fieldsUsed;
  final String? errorMessage;
  final List<String> warnings;

  SchedulingResult({
    required this.success,
    required this.scheduledGames,
    required this.unscheduledGames,
    required this.fieldsUsed,
    this.errorMessage,
    this.warnings = const [],
  });
}

class GameSlot {
  final String courtId;
  final DateTime startTime;
  final DateTime endTime;
  Game? game;
  bool isBlocked; // For ceremonies, breaks, etc.
  String? blockReason; // Description of why it's blocked
  
  GameSlot({
    required this.courtId,
    required this.startTime,
    required this.endTime,
    this.game,
    this.isBlocked = false,
    this.blockReason,
  });

  bool isAvailable() => game == null && !isBlocked;
  
  bool hasConflict(Game newGame) {
    if (game == null) return false;
    
    // Check if either team is already playing at this time
    return game!.teamAId == newGame.teamAId || 
           game!.teamBId == newGame.teamBId ||
           game!.teamAId == newGame.teamBId || 
           game!.teamBId == newGame.teamAId;
  }
  
  /// Check for same-time conflicts (teams playing simultaneously on different courts)
  bool hasSameTimeConflict(Game newGame) {
    return hasConflict(newGame);
  }
}

class GameScheduler {
  static const int MIN_REST_MINUTES = 30;
  static const int PREFERRED_REST_MINUTES = 60;

  /// Main scheduling function that distributes all games across available fields
  Future<SchedulingResult> scheduleAllGames({
    required Tournament tournament,
    required GameService gameService,
    required TimeOfDay scheduleStartTime,
    required TimeOfDay scheduleEndTime,
    required int timeSlotDuration,
  }) async {
    try {
      final warnings = <String>[];
      
      // Get all unscheduled games
      final allGames = gameService.getGamesForTournamentSync(tournament.id);
      final unscheduledGames = allGames.where((game) => 
        game.scheduledTime == null || game.courtId == null
      ).toList();

      if (unscheduledGames.isEmpty) {
        return SchedulingResult(
          success: true,
          scheduledGames: 0,
          unscheduledGames: 0,
          fieldsUsed: 0,
          warnings: ['Keine unverteilten Spiele gefunden'],
        );
      }

      // Get available courts/fields
      final courts = tournament.courts;
      if (courts.isEmpty) {
        return SchedulingResult(
          success: false,
          scheduledGames: 0,
          unscheduledGames: unscheduledGames.length,
          fieldsUsed: 0,
          errorMessage: 'Keine Felder verfügbar. Bitte Felder hinzufügen.',
        );
      }

      // Get tournament days
      final tournamentDays = _getTournamentDays(tournament);
      
      // Create time slots for all days and courts
      final timeSlots = _generateTimeSlots(
        courts: courts,
        days: tournamentDays,
        startTime: scheduleStartTime,
        endTime: scheduleEndTime,
        slotDuration: timeSlotDuration,
      );

      // Prioritize games (pool games first, then elimination by round)
      final prioritizedGames = _prioritizeGames(unscheduledGames);

      // Schedule games using intelligent allocation
      final schedulingResults = await _performScheduling(
        games: prioritizedGames,
        timeSlots: timeSlots,
        gameService: gameService,
      );

      return SchedulingResult(
        success: true,
        scheduledGames: schedulingResults['scheduled'] ?? 0,
        unscheduledGames: schedulingResults['unscheduled'] ?? 0,
        fieldsUsed: schedulingResults['fieldsUsed'] ?? 0,
        warnings: warnings,
      );

    } catch (e) {
      return SchedulingResult(
        success: false,
        scheduledGames: 0,
        unscheduledGames: 0,
        fieldsUsed: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Generate all available time slots across courts and days
  List<GameSlot> _generateTimeSlots({
    required List<Court> courts,
    required List<DateTime> days,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required int slotDuration,
    List<BreakSlot> breakSlots = const [],
  }) {
    final slots = <GameSlot>[];

    for (final day in days) {
      for (final court in courts) {
        // Generate time slots for this court on this day
        DateTime currentTime = DateTime(
          day.year, day.month, day.day, 
          startTime.hour, startTime.minute
        );
        
        final dayEnd = DateTime(
          day.year, day.month, day.day, 
          endTime.hour, endTime.minute
        );

        while (currentTime.add(Duration(minutes: slotDuration)).isBefore(dayEnd) ||
               currentTime.add(Duration(minutes: slotDuration)).isAtSameMomentAs(dayEnd)) {
          
          final slotEnd = currentTime.add(Duration(minutes: slotDuration));
          
          // Check if this slot overlaps with any break slots
          bool isBlocked = false;
          String? blockReason;
          
          for (final breakSlot in breakSlots) {
            if (breakSlot.blocksAllCourts && 
                _slotsOverlap(currentTime, slotEnd, breakSlot.startTime, breakSlot.endTime)) {
              isBlocked = true;
              blockReason = breakSlot.title;
              break;
            }
          }
          
          slots.add(GameSlot(
            courtId: court.id,
            startTime: currentTime,
            endTime: slotEnd,
            isBlocked: isBlocked,
            blockReason: blockReason,
          ));

          currentTime = currentTime.add(Duration(minutes: slotDuration));
        }
      }
    }

    return slots;
  }

  /// Check if two time periods overlap
  bool _slotsOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && start2.isBefore(end1);
  }

  /// Prioritize games for scheduling (pool games first, then elimination by round)
  List<Game> _prioritizeGames(List<Game> games) {
    final prioritized = <Game>[];
    
    // 1. Pool games (highest priority)
    final poolGames = games.where((g) => g.gameType == GameType.pool).toList();
    poolGames.sort((a, b) => (a.poolId ?? '').compareTo(b.poolId ?? ''));
    prioritized.addAll(poolGames);
    
    // 2. Elimination games (by round - later rounds have lower numbers)
    final elimGames = games.where((g) => g.gameType == GameType.elimination).toList();
    elimGames.sort((a, b) {
      final roundA = a.bracketRound ?? 99;
      final roundB = b.bracketRound ?? 99;
      if (roundA != roundB) return roundA.compareTo(roundB);
      return (a.bracketPosition ?? 0).compareTo(b.bracketPosition ?? 0);
    });
    prioritized.addAll(elimGames);
    
    return prioritized;
  }

  /// Perform the actual scheduling with conflict resolution
  Future<Map<String, int>> _performScheduling({
    required List<Game> games,
    required List<GameSlot> timeSlots,
    required GameService gameService,
  }) async {
    int scheduledCount = 0;
    int unscheduledCount = 0;
    final Set<String> usedCourts = {};

    for (final game in games) {
      bool scheduled = false;

      // Try to find the best slot for this game
      for (int i = 0; i < timeSlots.length && !scheduled; i++) {
        final slot = timeSlots[i];
        
        if (slot.isAvailable() && !slot.hasConflict(game)) {
          // Check if teams have adequate rest time
          if (_hasAdequateRestTime(game, timeSlots, slot.startTime)) {
            // Assign game to this slot
            slot.game = game;
            usedCourts.add(slot.courtId);
            
            // Update game in database
            final updatedGame = game.copyWith(
              scheduledTime: slot.startTime,
              courtId: slot.courtId,
              updatedAt: DateTime.now(),
            );
            
            await gameService.updateGame(updatedGame);
            scheduledCount++;
            scheduled = true;
          }
        }
      }

      if (!scheduled) {
        unscheduledCount++;
      }
    }

    return {
      'scheduled': scheduledCount,
      'unscheduled': unscheduledCount,
      'fieldsUsed': usedCourts.length,
    };
  }

  /// Check if teams have adequate rest time before next game
  bool _hasAdequateRestTime(Game game, List<GameSlot> timeSlots, DateTime proposedTime) {
    // Find any previous games for these teams
    for (final slot in timeSlots) {
      if (slot.game == null) continue;
      
      final existingGame = slot.game!;
      if (existingGame.teamAId == game.teamAId || 
          existingGame.teamBId == game.teamBId ||
          existingGame.teamAId == game.teamBId || 
          existingGame.teamBId == game.teamAId) {
        
        // Calculate time difference
        final timeDiff = proposedTime.difference(slot.endTime).inMinutes.abs();
        
        // If this would be too close to another game, reject
        if (timeDiff < MIN_REST_MINUTES && proposedTime.isAfter(slot.endTime)) {
          return false;
        }
        if (timeDiff < MIN_REST_MINUTES && proposedTime.isBefore(slot.startTime)) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Get tournament days from tournament dates
  List<DateTime> _getTournamentDays(Tournament tournament) {
    final days = <DateTime>[];
    final startDate = tournament.startDate;
    final endDate = tournament.endDate;
    
    if (endDate == null) {
      days.add(DateTime(startDate.year, startDate.month, startDate.day));
    } else {
      DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        days.add(current);
        current = current.add(const Duration(days: 1));
      }
    }
    
    return days;
  }

  /// Advanced scheduling with field optimization
  Future<SchedulingResult> scheduleWithOptimization({
    required Tournament tournament,
    required GameService gameService,
    required TimeOfDay scheduleStartTime,
    required TimeOfDay scheduleEndTime,
    required int timeSlotDuration,
    int maxFieldsToUse = 10,
    bool optimizeForMinimalFields = false,
    bool allowSameTimeConflicts = false,
    bool allowBackToBackGames = false,
    int minimumRestMinutes = 15,
    Map<String, String> divisionPriorities = const {},
    TeamService? teamService,
    List<BreakSlot> breakSlots = const [],
    bool allowGapsForConflicts = true,
  }) async {
    try {
      final warnings = <String>[];
      
      // Get all unscheduled games
      final allGames = gameService.getGamesForTournamentSync(tournament.id);
      final unscheduledGames = allGames.where((game) => 
        game.scheduledTime == null || game.courtId == null
      ).toList();

      if (unscheduledGames.isEmpty) {
        return SchedulingResult(
          success: true,
          scheduledGames: 0,
          unscheduledGames: 0,
          fieldsUsed: 0,
          warnings: ['Keine unverteilten Spiele gefunden'],
        );
      }

      // Get available courts/fields (limited by maxFieldsToUse)
      final allCourts = tournament.courts;
      final courts = allCourts.take(maxFieldsToUse).toList();
      
      if (courts.isEmpty) {
        return SchedulingResult(
          success: false,
          scheduledGames: 0,
          unscheduledGames: unscheduledGames.length,
          fieldsUsed: 0,
          errorMessage: 'Keine Felder verfügbar. Bitte Felder hinzufügen.',
        );
      }

      // Get tournament days
      final tournamentDays = _getTournamentDays(tournament);
      
      // Adjust days based on division priorities
      final adjustedDays = _adjustDaysForPriorities(tournamentDays, divisionPriorities);
      
      // Create time slots for all days and courts
      final timeSlots = _generateTimeSlots(
        courts: courts,
        days: adjustedDays,
        startTime: scheduleStartTime,
        endTime: scheduleEndTime,
        slotDuration: timeSlotDuration,
        breakSlots: breakSlots,
      );

      // Prioritize games based on division priorities and game types
      final prioritizedGames = await _prioritizeGamesWithDivisions(
        unscheduledGames, 
        divisionPriorities, 
        teamService,
      );

      // Schedule games with enhanced conflict handling
      final schedulingResults = await _performAdvancedScheduling(
        games: prioritizedGames,
        timeSlots: timeSlots,
        gameService: gameService,
        allowSameTimeConflicts: allowSameTimeConflicts,
        allowBackToBackGames: allowBackToBackGames,
        minimumRestMinutes: minimumRestMinutes,
        divisionPriorities: divisionPriorities,
        teamService: teamService,
        allowGapsForConflicts: allowGapsForConflicts,
      );

      // Add conflict information to warnings
      if (schedulingResults['unscheduled'] != null && schedulingResults['unscheduled']! > 0) {
        if (!allowSameTimeConflicts) {
          warnings.add('Gleichzeitige Spiele sind deaktiviert - einige Spiele konnten nicht geplant werden');
        }
        if (!allowBackToBackGames) {
          warnings.add('Direkt aufeinanderfolgende Spiele sind deaktiviert (${minimumRestMinutes}min Pause erforderlich)');
        }
      }

      return SchedulingResult(
        success: true,
        scheduledGames: schedulingResults['scheduled'] ?? 0,
        unscheduledGames: schedulingResults['unscheduled'] ?? 0,
        fieldsUsed: schedulingResults['fieldsUsed'] ?? 0,
        warnings: warnings,
      );

    } catch (e) {
      return SchedulingResult(
        success: false,
        scheduledGames: 0,
        unscheduledGames: 0,
        fieldsUsed: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Adjust tournament days based on division priorities
  List<DateTime> _adjustDaysForPriorities(List<DateTime> tournamentDays, Map<String, String> divisionPriorities) {
    // For "today only" priorities, we might want to prioritize first day
    // For "time" priorities, we want all days available
    // This is a simple implementation - can be enhanced
    return tournamentDays;
  }

  /// Get divisions that have games in this tournament
  Future<Set<String>> getDivisionsWithGames(Tournament tournament, GameService gameService, TeamService? teamService) async {
    final divisions = <String>{};
    
    if (teamService == null) {
      // Fallback to tournament categories if no team service
      return tournament.categories.toSet();
    }
    
    try {
      final allGames = gameService.getGamesForTournamentSync(tournament.id);
      
      // Get all team IDs from games
      final teamIds = <String>{};
      for (final game in allGames) {
        if (game.teamAId != null) teamIds.add(game.teamAId!);
        if (game.teamBId != null) teamIds.add(game.teamBId!);
      }
      
      // Get teams by ID and collect their divisions
      for (final teamId in teamIds) {
        final team = await teamService.getTeamById(teamId);
        if (team != null) {
          divisions.add(team.division);
        }
      }
      
      return divisions;
    } catch (e) {
      // Fallback to tournament categories if anything fails
      return tournament.categories.toSet();
    }
  }

  /// Prioritize games based on division priorities and game types
  Future<List<Game>> _prioritizeGamesWithDivisions(
    List<Game> games, 
    Map<String, String> divisionPriorities,
    TeamService? teamService,
  ) async {
    final prioritized = <Game>[];
    
    // Group games by priority level
    final todayOnlyGames = <Game>[];
    final asapGames = <Game>[];
    final timeGames = <Game>[];
    
    // Get team information if available
    Map<String, Team> teamMap = {};
    if (teamService != null && games.isNotEmpty) {
      // Get all team IDs from games
      final teamIds = <String>{};
      for (final game in games) {
        if (game.teamAId != null) teamIds.add(game.teamAId!);
        if (game.teamBId != null) teamIds.add(game.teamBId!);
      }
      
      // Get teams by ID
      for (final teamId in teamIds) {
        final team = await teamService.getTeamById(teamId);
        if (team != null) {
          teamMap[team.id] = team;
        }
      }
    }
    
    // Separate games by division priority
    for (final game in games) {
      String division = 'default';
      
      // Try to get division from teams
      if (teamService != null && game.teamAId != null && teamMap.containsKey(game.teamAId)) {
        division = teamMap[game.teamAId]!.division;
      } else if (teamService != null && game.teamBId != null && teamMap.containsKey(game.teamBId)) {
        division = teamMap[game.teamBId]!.division;
      }
      
      final priority = divisionPriorities[division] ?? 'asap';
      
      switch (priority) {
        case 'today':
          todayOnlyGames.add(game);
          break;
        case 'asap':
          asapGames.add(game);
          break;
        case 'time':
          timeGames.add(game);
          break;
        default:
          asapGames.add(game);
      }
    }
    
    // Prioritize within each group (pool games first, then elimination by round)
    _prioritizeGamesByType(todayOnlyGames);
    _prioritizeGamesByType(asapGames);
    _prioritizeGamesByType(timeGames);
    
    // Add to final list in priority order
    prioritized.addAll(todayOnlyGames);
    prioritized.addAll(asapGames);
    prioritized.addAll(timeGames);
    
    return prioritized;
  }

  /// Helper to prioritize games by type within a list
  void _prioritizeGamesByType(List<Game> games) {
    games.sort((a, b) {
      // Pool games first
      if (a.gameType == GameType.pool && b.gameType != GameType.pool) return -1;
      if (b.gameType == GameType.pool && a.gameType != GameType.pool) return 1;
      
      // Within pool games, sort by pool
      if (a.gameType == GameType.pool && b.gameType == GameType.pool) {
        return (a.poolId ?? '').compareTo(b.poolId ?? '');
      }
      
      // Within elimination games, sort by round
      if (a.gameType == GameType.elimination && b.gameType == GameType.elimination) {
        final roundA = a.bracketRound ?? 99;
        final roundB = b.bracketRound ?? 99;
        if (roundA != roundB) return roundA.compareTo(roundB);
        return (a.bracketPosition ?? 0).compareTo(b.bracketPosition ?? 0);
      }
      
      return 0;
    });
  }

  /// Advanced scheduling with conflict handling options
  Future<Map<String, int>> _performAdvancedScheduling({
    required List<Game> games,
    required List<GameSlot> timeSlots,
    required GameService gameService,
    required bool allowSameTimeConflicts,
    required bool allowBackToBackGames,
    required int minimumRestMinutes,
    required Map<String, String> divisionPriorities,
    TeamService? teamService,
    bool allowGapsForConflicts = true,
  }) async {
    int scheduledCount = 0;
    int unscheduledCount = 0;
    final Set<String> usedCourts = {};

    // Get team information if available
    Map<String, Team> teamMap = {};
    if (teamService != null && games.isNotEmpty) {
      // Get all team IDs from games
      final teamIds = <String>{};
      for (final game in games) {
        if (game.teamAId != null) teamIds.add(game.teamAId!);
        if (game.teamBId != null) teamIds.add(game.teamBId!);
      }
      
      // Get teams by ID
      for (final teamId in teamIds) {
        final team = await teamService.getTeamById(teamId);
        if (team != null) {
          teamMap[team.id] = team;
        }
      }
    }

    for (final game in games) {
      bool scheduled = false;
      int conflictSkips = 0;
      const maxConflictSkips = 3; // Maximum gaps to leave for conflicts

      // Try to find the best slot for this game
      for (int i = 0; i < timeSlots.length && !scheduled; i++) {
        final slot = timeSlots[i];
        
        if (slot.isAvailable()) {
          bool canSchedule = true;
          bool hasConflict = false;
          
          // Check same-time conflicts if not allowed
          if (!allowSameTimeConflicts) {
            if (_hasSameTimeConflict(game, timeSlots, slot.startTime)) {
              canSchedule = false;
              hasConflict = true;
            }
          }
          
          // Check back-to-back conflicts if not allowed
          if (canSchedule && !allowBackToBackGames) {
            if (!_hasAdequateRestTimeAdvanced(game, timeSlots, slot.startTime, minimumRestMinutes)) {
              canSchedule = false;
              hasConflict = true;
            }
          }
          
          // Additional priority-based checks (e.g., "today only" games should be on first day)
          if (canSchedule) {
            canSchedule = await _respectsDivisionPriority(game, slot, divisionPriorities, teamService, teamMap);
          }
          
          if (canSchedule) {
            // Assign game to this slot
            slot.game = game;
            usedCourts.add(slot.courtId);
            
            // Update game in database
            final updatedGame = game.copyWith(
              scheduledTime: slot.startTime,
              courtId: slot.courtId,
              updatedAt: DateTime.now(),
            );
            
            await gameService.updateGame(updatedGame);
            scheduledCount++;
            scheduled = true;
          } else if (hasConflict && allowGapsForConflicts && conflictSkips < maxConflictSkips) {
            // Skip this slot due to conflict, leave it as a gap
            conflictSkips++;
            continue;
          }
        }
      }

      if (!scheduled) {
        unscheduledCount++;
      }
    }

    return {
      'scheduled': scheduledCount,
      'unscheduled': unscheduledCount,
      'fieldsUsed': usedCourts.length,
    };
  }

  /// Check for same-time conflicts across all time slots
  bool _hasSameTimeConflict(Game game, List<GameSlot> timeSlots, DateTime proposedTime) {
    for (final slot in timeSlots) {
      if (slot.game == null) continue;
      
      // Check if this is the same time slot (same start time)
      if (slot.startTime.isAtSameMomentAs(proposedTime)) {
        final existingGame = slot.game!;
        // Check if any team is involved in both games
        if (existingGame.teamAId == game.teamAId || 
            existingGame.teamBId == game.teamBId ||
            existingGame.teamAId == game.teamBId || 
            existingGame.teamBId == game.teamAId) {
          return true; // Same team playing at same time = conflict
        }
      }
    }
    return false;
  }

  /// Enhanced rest time checking with configurable minimum
  bool _hasAdequateRestTimeAdvanced(Game game, List<GameSlot> timeSlots, DateTime proposedTime, int minimumRestMinutes) {
    // Find any existing games for these teams
    for (final slot in timeSlots) {
      if (slot.game == null) continue;
      
      final existingGame = slot.game!;
      // Check if any team is involved in both games
      if (existingGame.teamAId == game.teamAId || 
          existingGame.teamBId == game.teamBId ||
          existingGame.teamAId == game.teamBId || 
          existingGame.teamBId == game.teamAId) {
        
        // Calculate time differences
        final timeBetweenStart = proposedTime.difference(slot.startTime).inMinutes;
        final timeBetweenEnd = proposedTime.difference(slot.endTime).inMinutes;
        
        // Check if proposed game is too close after existing game
        if (timeBetweenEnd > 0 && timeBetweenEnd < minimumRestMinutes) {
          return false; // Not enough rest after existing game
        }
        
        // Check if proposed game is too close before existing game
        if (timeBetweenStart < 0 && timeBetweenStart.abs() < minimumRestMinutes) {
          return false; // Not enough rest before existing game
        }
        
        // Check for overlapping games (should not happen but safety check)
        if (timeBetweenStart < 0 && timeBetweenEnd > 0) {
          return false; // Games would overlap
        }
      }
    }
    
    return true;
  }

  /// Check if game placement respects division priority settings
  Future<bool> _respectsDivisionPriority(
    Game game, 
    GameSlot slot, 
    Map<String, String> divisionPriorities,
    TeamService? teamService,
    Map<String, Team> teamMap,
  ) async {
    String division = 'default';
    
    // Try to get division from teams
    if (teamService != null && game.teamAId != null && teamMap.containsKey(game.teamAId)) {
      division = teamMap[game.teamAId]!.division;
    } else if (teamService != null && game.teamBId != null && teamMap.containsKey(game.teamBId)) {
      division = teamMap[game.teamBId]!.division;
    }
    
    final priority = divisionPriorities[division] ?? 'asap';
    
    switch (priority) {
      case 'today':
        // Game should be scheduled on the first day only
        // This is a simplified check - could be enhanced to track the actual first day
        return true; // For now, allow all - can be enhanced later
      case 'asap':
        // Game should be scheduled as early as possible
        return true; // Priority is already handled in sorting
      case 'time':
        // Game can be scheduled later, spread over multiple days
        return true;
      default:
        return true;
    }
  }

  /// Get scheduling statistics
  Map<String, dynamic> getSchedulingStats(Tournament tournament, GameService gameService) {
    final allGames = gameService.getGamesForTournamentSync(tournament.id);
    final scheduledGames = allGames.where((g) => g.scheduledTime != null && g.courtId != null).toList();
    final unscheduledGames = allGames.where((g) => g.scheduledTime == null || g.courtId == null).toList();
    
    final usedCourts = scheduledGames.map((g) => g.courtId).where((id) => id != null).toSet();
    
    return {
      'totalGames': allGames.length,
      'scheduledGames': scheduledGames.length,
      'unscheduledGames': unscheduledGames.length,
      'fieldsUsed': usedCourts.length,
      'totalFields': tournament.courts.length,
      'utilizationPercent': tournament.courts.isEmpty ? 0 : (usedCourts.length / tournament.courts.length * 100).round(),
    };
  }
} 