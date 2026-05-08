import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/livestream_service.dart';
import '../../utils/app_colors.dart';

/// Admin screen to connect or disconnect the central RHBL YouTube channel.
///
/// The actual OAuth dance is handled by the `youtubeOAuthCallback` cloud
/// function. The Flutter side just opens Google's consent URL in the
/// browser; once the user has accepted, the callback writes
/// `config/youtube_oauth` and this screen reflects the new state on the
/// next refresh.
class YoutubeConnectScreen extends StatefulWidget {
  const YoutubeConnectScreen({super.key});

  @override
  State<YoutubeConnectScreen> createState() => _YoutubeConnectScreenState();
}

class _YoutubeConnectScreenState extends State<YoutubeConnectScreen> {
  final LivestreamService _service = LivestreamService();

  bool _loading = true;
  bool _connecting = false;
  bool _connected = false;
  String? _channelTitle;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    final connected = await _service.isYoutubeConnected();
    final title = connected ? await _service.connectedChannelTitle() : null;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _connected = connected;
      _channelTitle = title;
    });
  }

  Future<void> _startOAuth() async {
    setState(() => _connecting = true);
    try {
      final url = await _service.getYoutubeAuthUrl();
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Browser konnte nicht geöffnet werden.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trennen?'),
        content: const Text(
            'Das Refresh-Token wird gelöscht. Neue Streams können erst '
            'nach erneutem Verbinden erstellt werden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Trennen')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.disconnectYoutube();
      await _refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YouTube-Verbindung entfernt.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YouTube-Verbindung',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Verbinde den zentralen RHBL-YouTube-Kanal, damit die App '
            'pro Turnier automatisch einen Live-Broadcast inkl. RTMP-URL '
            'und Stream-Key erstellen kann.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    _connected ? Icons.check_circle : Icons.cancel,
                    color: _connected ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connected ? 'Verbunden' : 'Nicht verbunden',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_channelTitle != null) ...[
                          const SizedBox(height: 4),
                          Text('Channel: $_channelTitle'),
                        ],
                      ],
                    ),
                  ),
                  if (_connected)
                    OutlinedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Trennen'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _connecting ? null : _startOAuth,
            icon: _connecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_circle),
            label: Text(_connected ? 'Erneut verbinden' : 'Mit YouTube verbinden'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Status aktualisieren'),
          ),
        ],
      ),
    );
  }
}
