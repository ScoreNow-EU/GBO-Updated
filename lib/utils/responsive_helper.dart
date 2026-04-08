import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Device type for scoring layout differentiation
enum ScoringDeviceType {
  /// iPad/tablet: touch-optimized, larger buttons, on-screen keyboard
  tablet,
  /// Desktop/PC: compact layout, physical keyboard, mouse-driven
  desktop,
}

class ResponsiveHelper {
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(double width) => width < mobileBreakpoint;
  static bool isTablet(double width) => width >= mobileBreakpoint && width < tabletBreakpoint;
  static bool isDesktop(double width) => width >= tabletBreakpoint;

  static bool shouldShowSideNavigation(double width) => width >= mobileBreakpoint;
  static bool shouldUseDrawer(double width) => width < mobileBreakpoint;

  static double getContentPadding(double width) {
    if (isMobile(width)) return 16.0;
    if (isTablet(width)) return 24.0;
    return 32.0;
  }

  static double getFontScale(double width) {
    if (isMobile(width)) return 0.9;
    if (isTablet(width)) return 1.0;
    return 1.1;
  }

  static int getGridColumns(double width) {
    if (isMobile(width)) return 1;
    if (isTablet(width)) return 2;
    return 3;
  }

  /// Detect if the scoring device is a tablet (iPad) or desktop (PC).
  /// On native iOS/Android → tablet.
  /// On web → check if touch-capable via pointer device kinds + screen size heuristics.
  /// On macOS/Windows/Linux → desktop.
  static ScoringDeviceType getScoringDeviceType(BuildContext context) {
    final platform = Theme.of(context).platform;

    // Native mobile/tablet platforms → always tablet
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
      return ScoringDeviceType.tablet;
    }

    // Native desktop platforms → always desktop
    if (platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux) {
      // On web, macOS user agent is reported for Safari on iPad too,
      // so check if running on web AND has touch support
      if (kIsWeb) {
        // On web: use screen size as heuristic.
        // iPads max out around 1366 logical px width in landscape.
        // Desktop monitors are typically wider.
        final size = MediaQuery.of(context).size;
        final shortestSide = size.shortestSide;
        // iPads have shortest side ≤ 1024, desktops typically > 1024
        if (shortestSide <= 1024 && size.width <= 1400) {
          return ScoringDeviceType.tablet;
        }
        return ScoringDeviceType.desktop;
      }
      return ScoringDeviceType.desktop;
    }

    // Fallback: use screen size
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 1400 ? ScoringDeviceType.desktop : ScoringDeviceType.tablet;
  }

  /// Whether the device is a desktop/PC for scoring purposes
  static bool isScoringDesktop(BuildContext context) {
    return getScoringDeviceType(context) == ScoringDeviceType.desktop;
  }

  /// Whether the device is a tablet/iPad for scoring purposes
  static bool isScoringTablet(BuildContext context) {
    return getScoringDeviceType(context) == ScoringDeviceType.tablet;
  }
} 