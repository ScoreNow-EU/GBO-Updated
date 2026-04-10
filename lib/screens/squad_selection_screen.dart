import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/game.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/game_squad.dart';
import 'dart:async';
import 'dart:math';
import '../services/game_squad_service.dart';
import '../services/team_manager_service.dart';
import '../services/auth_service.dart';
import '../services/face_id_service.dart';
import '../services/suspension_service.dart';
import '../utils/responsive_helper.dart';

class SquadSelectionScreen extends StatefulWidget {
  final Game game;
  final Team team;

  const SquadSelectionScreen({
    super.key,
    required this.game,
    required this.team,
  });

  @override
  State<SquadSelectionScreen> createState() => _SquadSelectionScreenState();
}

class _SquadSelectionScreenState extends State<SquadSelectionScreen> {
  final GameSquadService _gameSquadService = GameSquadService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  final AuthService _authService = AuthService();

  List<Player> _availablePlayers = [];
  List<Player> _selectedPlayers = [];
  Set<String> _suspendedPlayerIds = {};
  Map<String, String> _suspensionReasons = {};
  GameSquad? _existingSquad;
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';
  StreamSubscription<List<GameSquad>>? _squadStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSquadStream();
  }

  @override
  void dispose() {
    _squadStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load available players from team roster
      final availablePlayers = await _gameSquadService.getAvailablePlayersForTeam(widget.team.id);
      
      // Load existing squad if any
      final existingSquad = await _gameSquadService.getSquadForGame(widget.game.id, widget.team.id);

      // Check suspensions for each player
      final suspensionService = SuspensionService();
      final suspendedIds = <String>{};
      final suspensionReasonMap = <String, String>{};
      for (final player in availablePlayers) {
        final isSuspended = await suspensionService.isPlayerSuspendedForTournament(
          player.id,
          widget.game.tournamentId,
        );
        if (isSuspended) {
          suspendedIds.add(player.id);
          final reason = await suspensionService.getSuspensionReason(
            player.id,
            widget.game.tournamentId,
          );
          if (reason != null) suspensionReasonMap[player.id] = reason;
        }
      }
      
      setState(() {
        _availablePlayers = availablePlayers;
        _existingSquad = existingSquad;
        _suspendedPlayerIds = suspendedIds;
        _suspensionReasons = suspensionReasonMap;
        
        // Pre-select existing squad players
        if (existingSquad != null) {
          _selectedPlayers = _availablePlayers
              .where((player) => existingSquad.selectedPlayers
                  .any((squadPlayer) => squadPlayer.playerId == player.id))
              .toList();
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorToast('Fehler beim Laden der Spielerdaten: $e');
    }
  }

  Future<void> _saveSquad() async {
    if (_selectedPlayers.isEmpty) {
      _showErrorToast('Bitte wählen Sie mindestens einen Spieler aus');
      return;
    }

    if (_selectedPlayers.length > 16) {
      _showErrorToast('Maximal 16 Spieler erlaubt');
      return;
    }

    // Show save options dialog
    final saveOption = await _showSaveOptionsDialog();
    if (saveOption == null) return; // User cancelled

    setState(() => _isSaving = true);

    try {
      final currentUser = _authService.currentFirebaseUser;
      if (currentUser == null) {
        _showErrorToast('Sie sind nicht angemeldet');
        return;
      }

      bool shouldSign = false;
      if (saveOption == 'sign') {
        // Try biometric authentication first
        final faceIdService = FaceIdService();
        final isAvailable = await faceIdService.isBiometricAvailable();
        
        bool authenticated = false;
        
        if (isAvailable) {
          authenticated = await faceIdService.authenticate();
        }
        
        // If biometric failed or not available, try 4-digit code
        if (!authenticated) {
          authenticated = await _showCodeAuthenticationDialog();
        }
        
        if (!authenticated) {
          _showErrorToast('Authentifizierung fehlgeschlagen');
          return;
        }
        
        shouldSign = true;
      }

      final success = await _gameSquadService.selectSquadForGame(
        gameId: widget.game.id,
        teamId: widget.team.id,
        selectedPlayers: _selectedPlayers,
        selectedByUserId: currentUser.uid,
        selectedByName: currentUser.displayName ?? 'Unbekannt',
        tournamentId: widget.game.tournamentId,
        shouldSign: shouldSign,
      );

      if (success) {
        _showSuccessToast(
          shouldSign 
            ? 'Kader erfolgreich signiert'
            : _existingSquad != null 
              ? 'Kader als Entwurf gespeichert' 
              : 'Kader als Entwurf erstellt'
        );
        Navigator.of(context).pop(true);
      } else {
        _showErrorToast('Fehler beim Speichern des Kaders');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Speichern: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _togglePlayerSelection(Player player) {
    if (_suspendedPlayerIds.contains(player.id)) {
      _showErrorToast('${player.fullName} ist gesperrt: ${_suspensionReasons[player.id] ?? 'Gesperrt'}');
      return;
    }
    setState(() {
      if (_selectedPlayers.contains(player)) {
        _selectedPlayers.remove(player);
      } else {
        if (_selectedPlayers.length >= 16) {
          _showErrorToast('Maximal 16 Spieler erlaubt');
          return;
        }
        _selectedPlayers.add(player);
      }
    });
  }

  List<Player> get _filteredPlayers {
    if (_searchQuery.isEmpty) return _availablePlayers;
    
    return _availablePlayers.where((player) {
      final searchLower = _searchQuery.toLowerCase();
      return player.fullName.toLowerCase().contains(searchLower) ||
             (player.jerseyNumber?.contains(_searchQuery) ?? false) ||
             (player.classification?.toLowerCase().contains(searchLower) ?? false);
    }).toList();
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Kader auswählen',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveSquad,
              child: Text(
                'Speichern',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildGameInfo(),
              _buildSquadCounter(),
              _buildSearchBar(),
              Expanded(child: _buildPlayersList()),
            ],
          ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.game.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Team: ${widget.team.name}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          if (widget.game.scheduledTime != null) ...[
            const SizedBox(height: 4),
            Text(
              'Anpfiff: ${_formatDateTime(widget.game.scheduledTime!)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
          if (_existingSquad?.isApproved == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✓ Von Trainer bestätigt',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (_existingSquad?.isRejected == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✗ Vom Trainer abgelehnt',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (_existingSquad != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '⏳ Warte auf Trainer-Bestätigung',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSquadCounter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _selectedPlayers.length > 16 ? Colors.red[50] : Colors.green[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ausgewählte Spieler:',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _selectedPlayers.length > 16 ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_selectedPlayers.length}/16',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Spieler suchen...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildPlayersList() {
    final filteredPlayers = _filteredPlayers;
    
    if (filteredPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                ? 'Keine Spieler im Kader verfügbar'
                : 'Keine Spieler gefunden',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPlayers.length,
      itemBuilder: (context, index) {
        final player = filteredPlayers[index];
        final isSelected = _selectedPlayers.contains(player);
        final isSuspended = _suspendedPlayerIds.contains(player.id);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isSuspended
                  ? Colors.red[300]
                  : isSelected ? Colors.green : Colors.grey[300],
              child: isSuspended
                  ? const Icon(Icons.block, color: Colors.white, size: 20)
                  : Text(
                      player.jerseyNumber ?? '?',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(
              player.fullName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSuspended ? Colors.grey : null,
                decoration: isSuspended ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: isSuspended
                ? Text(
                    'Gesperrt: ${_suspensionReasons[player.id] ?? 'Turniersperre'}',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  )
                : player.classification != null 
                    ? Text(player.classification!)
                    : null,
            trailing: isSuspended
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Text(
                      'Gesperrt',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.circle_outlined, color: Colors.grey),
            onTap: () => _togglePlayerSelection(player),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  

  void _setupSquadStream() {
    // Listen for real-time updates to the squad
    _squadStreamSubscription = _gameSquadService.streamSquadsForGame(widget.game.id)
        .listen((squads) {
      // Find our team's squad
      final ourSquad = squads
          .where((squad) => squad.teamId == widget.team.id)
          .firstOrNull;
      
      if (ourSquad != null && mounted) {
        setState(() {
          _existingSquad = ourSquad;
        });
      }
    });
  }

  Future<String?> _showSaveOptionsDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Kader speichern',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Möchten Sie den Kader als Entwurf speichern oder direkt signieren?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Abbrechen',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('draft'),
              child: const Text(
                'Als Entwurf',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('sign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Direkt signieren'),
            ),
          ],
               );
     },
   );
   }

  Future<bool> _showCodeAuthenticationDialog() async {
    // Generate a random 4-digit code
    final random = Random();
    final code = (1000 + random.nextInt(9000)).toString();
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _CodeAuthDialog(code: code);
      },
    ) ?? false;
  }
}

class _CodeAuthDialog extends StatefulWidget {
  final String code;
  
  const _CodeAuthDialog({required this.code});
  
  @override
  State<_CodeAuthDialog> createState() => _CodeAuthDialogState();
}

class _CodeAuthDialogState extends State<_CodeAuthDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidating = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
  
  void _validateCode() {
    final enteredCode = _codeController.text.trim();
    
    if (enteredCode.isEmpty) {
      setState(() {
        _errorMessage = 'Bitte geben Sie den Code ein';
      });
      return;
    }
    
    if (enteredCode == widget.code) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Falscher Code. Bitte versuchen Sie es erneut.';
        _codeController.clear();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.orange[600],
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text(
            'Authentifizierung',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biometrische Authentifizierung nicht verfügbar.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Geben Sie den folgenden Code ein:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          
          // Display the code prominently
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              widget.code,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Input field
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: '----',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
              ),
            ),
            onSubmitted: (_) => _validateCode(),
          ),
          
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Abbrechen',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _validateCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
          ),
          child: _isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Bestätigen'),
        ),
      ],
    );
  }
} 