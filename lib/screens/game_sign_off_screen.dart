import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toastification/toastification.dart';

/// Screen for a team manager to sign off (Unterschrift) on the game protocol.
/// Reached via notification tap or manual navigation.
class GameSignOffScreen extends StatefulWidget {
  final String gameId;
  final String teamId;
  final String teamName;

  const GameSignOffScreen({
    super.key,
    required this.gameId,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<GameSignOffScreen> createState() => _GameSignOffScreenState();
}

class _GameSignOffScreenState extends State<GameSignOffScreen> {
  bool _isLoading = true;
  bool _isSigning = false;
  bool _isSigned = false;
  bool _isTeamA = true;

  // Game summary data
  String _teamAName = '';
  String _teamBName = '';
  int _teamAScore = 0;
  int _teamBScore = 0;
  String _managerName = '';

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    try {
      // Try to determine team side and scores from game and gameStates
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .get();

      if (gameDoc.exists) {
        final gameData = gameDoc.data()!;
        _teamAName = gameData['teamAName'] ?? 'Team A';
        _teamBName = gameData['teamBName'] ?? 'Team B';
        _isTeamA = gameData['teamAId'] == widget.teamId;
      }

      final stateDoc = await FirebaseFirestore.instance
          .collection('gameStates')
          .doc(widget.gameId)
          .get();

      if (stateDoc.exists) {
        final data = stateDoc.data()!;
        _teamAScore = data['teamAScore'] ?? 0;
        _teamBScore = data['teamBScore'] ?? 0;
        _managerName = _isTeamA
            ? (data['teamAManagerName'] ?? '')
            : (data['teamBManagerName'] ?? '');
      }

      // Check sign-off state from unified gameReports
      final reportDoc = await FirebaseFirestore.instance
          .collection('gameReports')
          .doc(widget.gameId)
          .get();

      if (reportDoc.exists) {
        final data = reportDoc.data()!;
        final coachField = _isTeamA ? 'teamACoach' : 'teamBCoach';
        _isSigned = data['${coachField}Signed'] ?? false;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOff() async {
    // Use slider confirmation
    double sliderValue = 0;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Spielprotokoll bestätigen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spielverantwortlicher:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(_managerName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Ergebnis:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text('$_teamAName  $_teamAScore : $_teamBScore  $_teamBName',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Schieben Sie den Regler ganz nach rechts, um den Spielbericht zu bestätigen.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: sliderValue >= 0.95 ? Colors.green.shade50 : Colors.grey.shade100,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      sliderValue >= 0.95 ? Icons.check_circle : Icons.arrow_forward,
                      color: sliderValue >= 0.95 ? Colors.green : Colors.grey,
                    ),
                    Expanded(
                      child: Slider(
                        value: sliderValue,
                        onChanged: (v) => setDialogState(() => sliderValue = v),
                        activeColor: sliderValue >= 0.95 ? Colors.green : Colors.blue,
                      ),
                    ),
                    Icon(Icons.lock_open,
                        color: sliderValue >= 0.95 ? Colors.green : Colors.grey.shade400),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: sliderValue >= 0.95 ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a237e),
                  foregroundColor: Colors.white),
              child: const Text('Bestätigen'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSigning = true);

    try {
      final coachField = _isTeamA ? 'teamACoach' : 'teamBCoach';
      final now = DateTime.now();

      await FirebaseFirestore.instance
          .collection('gameReports')
          .doc(widget.gameId)
          .set({
        '${coachField}Signed': true,
        '${coachField}SignedAt': now.toIso8601String(),
        '${coachField}Name': _managerName.isNotEmpty ? _managerName : widget.teamName,
        '${coachField}Method': 'slider',
      }, SetOptions(merge: true));

      // Also write to legacy gameStates for backward compatibility
      final legacyField = _isTeamA ? 'teamAManagerSigned' : 'teamBManagerSigned';
      await FirebaseFirestore.instance
          .collection('gameStates')
          .doc(widget.gameId)
          .set({
        legacyField: true,
        '${legacyField}At': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isSigned = true;
          _isSigning = false;
        });
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Unterschrift gespeichert'),
          description: Text(
              '${widget.teamName} – Spielprotokoll wurde erfolgreich bestätigt.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigning = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Fehler'),
          description: Text('Unterschrift fehlgeschlagen: $e'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielprotokoll unterschreiben'),
        backgroundColor: const Color(0xFF455A64),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          if (_isSigned)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unterschrieben',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800)),
                        const SizedBox(height: 2),
                        Text(
                            'Das Spielprotokoll wurde von $_managerName bestätigt.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.green.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Score card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1a237e), Color(0xFF283593)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                const Text('Endergebnis',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(_teamAName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('$_teamAScore',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Text(':',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 40,
                            fontWeight: FontWeight.w300)),
                    Expanded(
                      child: Column(
                        children: [
                          Text(_teamBName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('$_teamBScore',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Manager info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF455A64),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spielverantwortlicher – ${widget.teamName}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text(_managerName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sign button
          if (!_isSigned)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSigning ? null : _signOff,
                icon: _isSigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.draw_outlined, size: 22),
                label: Text(
                    _isSigning
                        ? 'Wird bestätigt…'
                        : 'Spielprotokoll unterschreiben',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF455A64),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
