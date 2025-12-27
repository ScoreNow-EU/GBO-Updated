# Wallpaper & Splash Screen Guide

## Overview

Two responsive screen components have been created for iPhone and iPad:

1. **SplashScreen** - Animated launch screen
2. **WallpaperScreen** - Persistent wallpaper background

## Files Created

- `lib/screens/splash_screen.dart` - Launch animation screen
- `lib/screens/wallpaper_screen.dart` - Responsive wallpaper for iPhone/iPad

## Usage Examples

### 1. Splash Screen (on App Launch)

```dart
import 'package:your_app/screens/splash_screen.dart';

// Use in your main app initialization
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        home: SplashScreen(
          duration: const Duration(seconds: 3),
          onComplete: () {
            setState(() {
              _showSplash = false;
            });
          },
        ),
      );
    }
    
    return MaterialApp(
      home: const HomeScreen(),
    );
  }
}
```

### 2. Wallpaper Screen (Background)

```dart
import 'package:your_app/screens/wallpaper_screen.dart';

// Use as a background behind other content
Widget build(BuildContext context) {
  return Stack(
    children: [
      // Wallpaper background
      WallpaperScreen(
        showContent: false, // Hide default content
      ),
      
      // Your content on top
      Center(
        child: Column(
          children: [
            Text('Your content here'),
          ],
        ),
      ),
    ],
  );
}
```

### 3. Wallpaper with Custom Content

```dart
WallpaperScreen(
  showContent: true,
  onTap: () {
    // Handle tap
    Navigator.push(...);
  },
)
```

## Features

### SplashScreen
- ✅ Automatic fade-in animation
- ✅ Scale animation effect
- ✅ Loading indicator
- ✅ Auto-dismisses after duration
- ✅ Responsive for iPhone & iPad
- ✅ Customizable duration

### WallpaperScreen
- ✅ Responsive iPhone layout (portrait)
- ✅ Responsive iPad layout (landscape)
- ✅ Gradient background using app colors
- ✅ Decorative shapes (circles, lines)
- ✅ Tap-to-continue feature
- ✅ Feature list for iPad
- ✅ Logo with shadow effects

## Customization

### Change Duration
```dart
SplashScreen(
  duration: const Duration(seconds: 5), // Change to 5 seconds
  onComplete: () { ... }
)
```

### Hide Splash Content
```dart
WallpaperScreen(
  showContent: false, // Hides "Tap to continue"
)
```

### Add Tap Handler
```dart
WallpaperScreen(
  onTap: () {
    print('Screen tapped!');
    Navigator.push(...);
  },
)
```

## Design Elements

### Colors
- **Gradient:** Pink → Peach → Light Orange (from AppColors)
- **Accents:** White with 8-20% opacity
- **Text:** White with 70% opacity for subtitles

### Typography
- **Title:** HeadlineLarge, Bold, 1.5 letter spacing
- **Subtitle:** TitleMedium, 0.5 letter spacing
- **Body:** BodySmall, subtle styling

### Responsive Breakpoints
- **Tablet (iPad):** `shortestSide > 600`
- **Phone (iPhone):** `shortestSide ≤ 600`

## Layout Details

### iPhone Layout (Portrait)
- Centered vertical stack
- Logo: 120x120
- Large title with accent line
- Single column

### iPad Layout (Landscape)
- Two-column split
- Left: Decorative elements
- Right: Content area
- Logo: 140x140
- Feature list below title

## Animations

### SplashScreen Animations
1. **Fade In:** 0 → 1 opacity over 1500ms
2. **Scale:** 0.8 → 1.0 scale over 1500ms
3. **Curve:** Ease-in for fade, Ease-out for scale

### Recommended Usage
- Show for 3-4 seconds on app launch
- Include branding/logo
- Show loading indicator

## Integration Steps

1. Import the screens:
```dart
import 'lib/screens/splash_screen.dart';
import 'lib/screens/wallpaper_screen.dart';
```

2. For splash screen, add to your main app widget

3. For wallpaper, use as background in Stack

4. Customize colors in `lib/utils/app_colors.dart` if needed

## Responsive Testing

### iPhone
- Test on: iPhone 13, iPhone 14, iPhone 15
- Portrait orientation

### iPad
- Test on: iPad Pro 11", iPad Pro 12.9"
- Landscape orientation

## Performance Notes

- CustomPaint is efficient for simple shapes
- Animations use single AnimationController
- No heavy image loading
- Smooth 60fps on all devices

---

**Created:** December 2, 2025  
**App Version:** 1.0.7  
**Responsive:** ✅ iPhone & iPad
