import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Web-only platform view import gated via conditional import.
import 'livestream_embed_web.dart'
    if (dart.library.io) 'livestream_embed_stub.dart' as platform_view;

/// Renders a YouTube livestream embed for the given watch/embed URL.
/// On web a sandboxed `<iframe>` is used; on mobile/desktop a `WebViewWidget`.
class LivestreamEmbed extends StatefulWidget {
  final String url;
  final double aspectRatio;

  const LivestreamEmbed({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<LivestreamEmbed> createState() => _LivestreamEmbedState();
}

class _LivestreamEmbedState extends State<LivestreamEmbed> {
  WebViewController? _controller;
  String? _embedUrl;

  @override
  void initState() {
    super.initState();
    _embedUrl = _toEmbedUrl(widget.url);
    if (!kIsWeb && _embedUrl != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(Uri.parse(_embedUrl!));
    }
  }

  @override
  void didUpdateWidget(covariant LivestreamEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final newEmbed = _toEmbedUrl(widget.url);
      _embedUrl = newEmbed;
      if (!kIsWeb && newEmbed != null) {
        _controller?.loadRequest(Uri.parse(newEmbed));
      }
    }
  }

  /// Converts a YouTube watch/short/embed URL into an embed URL. Returns null
  /// when no video id can be extracted.
  static String? _toEmbedUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return null;
    String? id;
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (uri.host.contains('youtube.com')) {
      if (uri.pathSegments.contains('embed')) {
        final idx = uri.pathSegments.indexOf('embed');
        if (idx + 1 < uri.pathSegments.length) {
          id = uri.pathSegments[idx + 1];
        }
      } else if (uri.pathSegments.contains('live')) {
        final idx = uri.pathSegments.indexOf('live');
        if (idx + 1 < uri.pathSegments.length) {
          id = uri.pathSegments[idx + 1];
        }
      } else {
        id = uri.queryParameters['v'];
      }
    }
    if (id == null || id.isEmpty) return null;
    return 'https://www.youtube.com/embed/$id?playsinline=1&rel=0';
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_embedUrl == null) {
      return _buildFallback(context, 'Ungültige Livestream-URL');
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: kIsWeb
            ? platform_view.buildYoutubeIframe(_embedUrl!)
            : (_controller != null
                ? WebViewWidget(controller: _controller!)
                : _buildFallback(context, 'Player nicht verfügbar')),
      ),
    );
  }

  Widget _buildFallback(BuildContext context, String message) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Auf YouTube öffnen'),
            ),
          ],
        ),
      ),
    );
  }
}
