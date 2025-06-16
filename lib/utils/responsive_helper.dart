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
} 