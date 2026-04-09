import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        final isOffline = results.isNotEmpty &&
            results.every((r) => r == ConnectivityResult.none);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isOffline
              ? MaterialBanner(
                  key: const ValueKey('offline'),
                  backgroundColor: Colors.red.shade700,
                  content: const Text(
                    'Keine Internetverbindung – Offline-Modus aktiv',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  leading: const Icon(Icons.wifi_off, color: Colors.white),
                  actions: const [SizedBox.shrink()],
                )
              : const SizedBox.shrink(key: ValueKey('online')),
        );
      },
    );
  }
}
