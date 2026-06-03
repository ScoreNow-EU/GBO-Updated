import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../utils/app_colors.dart';

/// Settings card that displays the current team logo and allows
/// authorised users to upload or remove it.
class TeamLogoSection extends StatefulWidget {
  final Team team;

  /// Whether the current user may upload / remove the logo.
  final bool canEdit;

  /// Called after a successful upload or removal so the parent can refresh.
  final VoidCallback? onLogoChanged;

  const TeamLogoSection({
    super.key,
    required this.team,
    this.canEdit = false,
    this.onLogoChanged,
  });

  @override
  State<TeamLogoSection> createState() => _TeamLogoSectionState();
}

class _TeamLogoSectionState extends State<TeamLogoSection> {
  final TeamService _teamService = TeamService();
  bool _uploading = false;
  bool _removing = false;

  // Optimistic local URL so the image updates instantly after upload.
  String? _localLogoUrl;

  String? get _effectiveLogoUrl =>
      _localLogoUrl ?? widget.team.logoUrl;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    // Guard: max 5 MB
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bild zu groß — max. 5 MB erlaubt.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final ext = (file.extension ?? 'jpg').toLowerCase();

    setState(() => _uploading = true);
    try {
      final url = await _teamService.uploadTeamLogo(
        teamId: widget.team.id,
        bytes: bytes,
        extension: ext,
      );
      if (mounted) {
        setState(() => _localLogoUrl = url);
        widget.onLogoChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo erfolgreich hochgeladen.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Hochladen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeLogo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logo entfernen?'),
        content:
            const Text('Das Team-Logo wird dauerhaft gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await _teamService.removeTeamLogo(
        widget.team.id,
        currentUrl: _effectiveLogoUrl,
      );
      if (mounted) {
        setState(() => _localLogoUrl = null);
        widget.onLogoChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo entfernt.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Entfernen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo =
        _effectiveLogoUrl != null && _effectiveLogoUrl!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Logo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Logo preview
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: hasLogo
                    ? ClipOval(
                        child: Image.network(
                          _effectiveLogoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderIcon(),
                        ),
                      )
                    : _placeholderIcon(),
              ),
            ),

            const SizedBox(height: 20),

            if (widget.canEdit) ...[
              // Upload button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading || _removing ? null : _pickAndUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                    _uploading
                        ? 'Wird hochgeladen…'
                        : hasLogo
                            ? 'Logo ersetzen'
                            : 'Logo hochladen',
                  ),
                ),
              ),

              if (hasLogo) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploading || _removing ? null : _removeLogo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: _removing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.red,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(_removing ? 'Wird entfernt…' : 'Logo entfernen'),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Text(
                'PNG, JPG oder GIF · max. 5 MB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Center(
                child: Text(
                  hasLogo ? 'Logo vorhanden' : 'Kein Logo hochgeladen',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return const Icon(Icons.groups, size: 48, color: Colors.grey);
  }
}
