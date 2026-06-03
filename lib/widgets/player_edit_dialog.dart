import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/player_service.dart';

/// Shared player edit dialog used from both team-level and global player
/// management. Replaces the previous duplicated `_showEditPlayerDialog`
/// (team_edit_screen) and `_showPlayerDialog` (player_management_screen)
/// implementations.
///
/// Photo upload UI is shown only for users with [app_user.UserRole.admin] or
/// [app_user.UserRole.teamManager]; other roles see a read-only avatar.
class PlayerEditDialog extends StatefulWidget {
  /// Existing player when editing, `null` when creating a new player.
  final Player? player;

  /// `true` when invoked from a team roster: hides
  /// `spielerpassNummer` and the secondary-photo controls. When `false`
  /// (global Kaderverwaltung) all fields are exposed.
  final bool teamContext;

  const PlayerEditDialog({
    super.key,
    this.player,
    this.teamContext = false,
  });

  /// Convenience helper. Returns the saved/created [Player] on success or
  /// `null` if the user cancelled.
  static Future<Player?> show(
    BuildContext context, {
    Player? player,
    bool teamContext = false,
  }) {
    return showDialog<Player>(
      context: context,
      builder: (_) => PlayerEditDialog(
        player: player,
        teamContext: teamContext,
      ),
    );
  }

  @override
  State<PlayerEditDialog> createState() => _PlayerEditDialogState();
}

class _PlayerEditDialogState extends State<PlayerEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _playerService = PlayerService();
  final _authService = AuthService();

  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _jerseyNumber;
  late TextEditingController _spielerpass;

  String _gender = 'männlich';
  String? _classification;
  DateTime? _birthDate;
  String? _photoUrl;

  bool _isSaving = false;
  bool _isUploading = false;
  bool _canUploadPhoto = false;

  bool get _isEdit => widget.player != null;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _firstName = TextEditingController(text: p?.firstName ?? '');
    _lastName = TextEditingController(text: p?.lastName ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _jerseyNumber = TextEditingController(text: p?.jerseyNumber ?? '');
    _spielerpass = TextEditingController(text: p?.spielerpassNummer ?? '');
    _gender = p?.gender ?? 'männlich';
    _classification = p?.classification;
    _birthDate = p?.birthDate;
    _photoUrl = p?.photoUrl;
    _resolvePhotoPermission();
  }

  Future<void> _resolvePhotoPermission() async {
    final user = await _authService.getCurrentUser();
    final allowed = user != null &&
        user.roles.any((r) =>
            r == app_user.UserRole.admin ||
            r == app_user.UserRole.teamManager);
    if (mounted) setState(() => _canUploadPhoto = allowed);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _jerseyNumber.dispose();
    _spielerpass.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    if (!_isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bitte zuerst Spieler speichern, dann kann ein Bild hochgeladen werden.'),
        ),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();

    setState(() => _isUploading = true);
    try {
      final url = await _playerService.uploadPlayerPhoto(
        playerId: widget.player!.id,
        bytes: bytes,
        extension: ext,
      );
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bild-Upload fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final base = widget.player ??
          Player(
            id: '',
            firstName: '',
            lastName: '',
            gender: 'männlich',
            createdAt: DateTime.now(),
          );
      final updated = base.copyWith(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        birthDate: _birthDate,
        classification: _classification,
        spielerpassNummer:
            _spielerpass.text.trim().isEmpty ? null : _spielerpass.text.trim(),
        jerseyNumber:
            _jerseyNumber.text.trim().isEmpty ? null : _jerseyNumber.text.trim(),
        gender: _gender,
        photoUrl: _photoUrl,
      );

      Player? saved;
      if (_isEdit) {
        final ok = await _playerService.updatePlayer(updated);
        saved = ok ? updated : null;
      } else {
        final newId = await _playerService.addPlayer(updated);
        if (newId != null) {
          saved = Player(
            id: newId,
            firstName: updated.firstName,
            lastName: updated.lastName,
            email: updated.email,
            phone: updated.phone,
            birthDate: updated.birthDate,
            classification: updated.classification,
            spielerpassNummer: updated.spielerpassNummer,
            jerseyNumber: updated.jerseyNumber,
            gender: updated.gender,
            isActive: updated.isActive,
            photoUrl: updated.photoUrl,
            createdAt: updated.createdAt,
          );
        }
      }

      if (!mounted) return;
      if (saved != null) {
        Navigator.of(context).pop(saved);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speichern fehlgeschlagen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
              (_photoUrl != null && _photoUrl!.isNotEmpty)
                  ? NetworkImage(_photoUrl!)
                  : null,
          child: (_photoUrl == null || _photoUrl!.isEmpty)
              ? const Icon(Icons.person, size: 44, color: Colors.grey)
              : null,
        ),
        if (_canUploadPhoto)
          Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isUploading ? null : _pickAndUploadPhoto,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Spieler bearbeiten' : 'Neuer Spieler'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: _buildAvatar()),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(
                          labelText: 'Vorname *', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(
                          labelText: 'Nachname *',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                      labelText: 'E-Mail', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                      labelText: 'Telefon', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _jerseyNumber,
                      decoration: const InputDecoration(
                          labelText: 'Trikot-Nr.',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: Player.genderOptions.contains(_gender)
                          ? _gender
                          : 'männlich',
                      decoration: const InputDecoration(
                          labelText: 'Geschlecht',
                          border: OutlineInputBorder()),
                      items: Player.genderOptions
                          .map((g) =>
                              DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _gender = v ?? 'männlich'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: Player.classificationTypes.contains(_classification)
                      ? _classification
                      : null,
                  decoration: const InputDecoration(
                      labelText: 'Klassifizierung',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('— keine —')),
                    ...Player.classificationTypes.map(
                      (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _classification = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Geburtsdatum',
                        border: OutlineInputBorder()),
                    child: Text(
                      _birthDate == null
                          ? '—'
                          : '${_birthDate!.day.toString().padLeft(2, '0')}.'
                              '${_birthDate!.month.toString().padLeft(2, '0')}.'
                              '${_birthDate!.year}',
                    ),
                  ),
                ),
                if (!widget.teamContext) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _spielerpass,
                    decoration: const InputDecoration(
                        labelText: 'Spielerpass-Nummer (RHD)',
                        border: OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Speichern' : 'Anlegen'),
        ),
      ],
    );
  }
}
