import 'package:flutter/material.dart';

/// NavigatorObserver zur Debug-Anzeige der aktuellen Route/Screen
/// Gibt bei jedem Screen-Wechsel die .dart-Datei in der Konsole aus
/// 
/// VERWENDUNG:
/// Bei der Navigation einfach `settings` hinzufügen:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => MeinScreen(),
///     settings: const RouteSettings(name: 'MeinScreen'),  // <- Diese Zeile hinzufügen
///   ),
/// );
/// ```
/// 
/// Die Ausgabe erscheint dann in der Konsole als:
/// ðŸ§­ [PUSH] MeinScreen â†’ screens/mein_screen.dart
class RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute('PUSH', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRoute('POP', route);
    if (previousRoute != null) {
      _logRoute('BACK TO', previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logRoute('REPLACE', newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logRoute('REMOVE', route);
  }

  void _logRoute(String action, Route<dynamic> route) {
    final routeName = route.settings.name ?? 'unnamed';
    final widgetInfo = _getWidgetInfo(route);
    
    // Ausgabe in Konsole mit Emoji für bessere Sichtbarkeit
    final display = widgetInfo.isNotEmpty ? widgetInfo : routeName;
    debugPrint('ðŸ§­ [$action] $display');
    
    // Zusätzlich: Title des Browser-Tabs aktualisieren (nur für Web)
    // Dies erscheint auch in den Browser DevTools
  }

  String _getWidgetInfo(Route<dynamic> route) {
    try {
      // Named Route vorhanden?
      if (route.settings.name != null && route.settings.name != '/') {
        final name = route.settings.name!;
        // Konvertiere zu Dateiname
        final fileName = _camelToSnake(name);
        return '$name â†’ screens/$fileName.dart';
      }
      
      // Fallback für unnamed routes
      if (route is MaterialPageRoute) {
        return 'MaterialPageRoute (unnamed - Hinweis: settings: RouteSettings(name: "ScreenName") hinzufügen)';
      }
      
      return 'Route: ${route.runtimeType}';
    } catch (e) {
      return 'Route (Fehler beim Extrahieren)';
    }
  }

  String _camelToSnake(String camelCase) {
    return camelCase
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceFirst('_', '');
  }
}
