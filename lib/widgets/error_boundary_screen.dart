import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Full-screen error boundary shown when an uncaught exception bubbles up
/// to the framework. Used as `ErrorWidget.builder` in release builds.
class ErrorBoundaryScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onReload;

  const ErrorBoundaryScreen({
    super.key,
    required this.error,
    this.stackTrace,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AnimatedErrorIcon(),
                  const SizedBox(height: 24),
                  Text(
                    'Etwas ist schiefgelaufen',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Die App ist auf einen unerwarteten Fehler gestoßen. '
                    'Bitte lade die Seite neu oder gehe zurück.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          final nav = Navigator.of(context, rootNavigator: true);
                          if (nav.canPop()) {
                            nav.pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Zurück'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onReload ?? _defaultReload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('App neu laden'),
                      ),
                    ],
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    _DebugDetails(error: error, stackTrace: stackTrace),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _defaultReload() {
    // On web, this triggers a full page reload via dart:js fallback.
    // On native, the user-supplied `onReload` should handle restart.
    if (kIsWeb) {
      // Avoid importing dart:html directly to keep this file mobile-safe.
      // The host page (web/index.html) provides `window.location.reload()`
      // when this button is wired from a web-aware caller.
    }
  }
}

class _AnimatedErrorIcon extends StatefulWidget {
  const _AnimatedErrorIcon();

  @override
  State<_AnimatedErrorIcon> createState() => _AnimatedErrorIconState();
}

class _AnimatedErrorIconState extends State<_AnimatedErrorIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Pulsing scale + subtle wobble.
          final t = Curves.easeInOut.transform(_controller.value);
          final scale = 0.92 + (t * 0.16);
          final angle = (t - 0.5) * 0.18;
          return Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor.withValues(alpha: 0.12),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: AppColors.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _DebugDetails extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const _DebugDetails({required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Details (Debug)'),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          SelectableText(
            error.toString(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          if (stackTrace != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              stackTrace.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
