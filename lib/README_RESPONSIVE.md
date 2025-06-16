# Responsive Design System

This document outlines the responsive design system implemented for the German Beach Open tournament management app.

## Overview

The app now features a comprehensive responsive design that adapts to different screen sizes:
- **Mobile**: < 768px - Uses drawer navigation with collapsible menu
- **Tablet**: 768px - 1024px - Uses side navigation with responsive content
- **Desktop**: > 1024px - Full side navigation with optimized layout

## Components

### 1. ResponsiveHelper (`lib/utils/responsive_helper.dart`)
Utility class that provides:
- Screen size detection methods
- Responsive padding calculations
- Font scaling based on screen size
- Grid column calculations
- Navigation display logic

### 2. ResponsiveLayout (`lib/widgets/responsive_layout.dart`)
Main layout wrapper that:
- Shows side navigation on larger screens
- Uses drawer with hamburger menu on mobile
- Automatically adjusts padding and spacing
- Provides responsive app bar with German titles

### 3. ResponsiveCard (`lib/widgets/responsive_card.dart`)
Card components that:
- Adapt padding based on screen size
- Support responsive grid layouts
- Scale text appropriately
- Maintain consistent spacing

### 4. ResponsiveDashboard (`lib/widgets/responsive_dashboard.dart`)
Dashboard template that:
- Creates responsive grid layouts
- Adapts card sizes for different screens
- Scales icons and text appropriately
- Provides touch-friendly mobile interface

## Key Features

### Mobile Navigation
- Hamburger menu button (☰) opens navigation drawer
- Navigation drawer closes automatically after selection
- All menu items are touch-optimized
- German text throughout ("Menü öffnen" tooltip)

### Responsive Content
- Content padding adjusts based on screen size
- Text scales appropriately (0.9x mobile, 1.0x tablet, 1.1x desktop)
- Grid layouts adapt (1 column mobile, 2 tablet, 3 desktop)
- Headers stack vertically on mobile

### German Localization
All user-facing text is in German:
- "Menü öffnen" - Open menu
- "Turniere" - Tournaments
- "Rangliste" - Rankings
- "ADMIN BEREICH" - Admin area
- "Preset Verwaltung" - Preset management
- "Schiedsrichter Verwaltung" - Referee management

## Usage

### Using ResponsiveLayout
```dart
ResponsiveLayout(
  selectedSection: selectedSection,
  onSectionChanged: (section) => setState(() => selectedSection = section),
  title: "Mein Titel",
  body: MyContent(),
)
```

### Using ResponsiveCard
```dart
ResponsiveCard(
  child: MyCardContent(),
)
```

### Using ResponsiveText
```dart
ResponsiveText(
  "Mein Text",
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
)
```

## Screen Breakpoints

- **Mobile**: < 768px
  - Single column layouts
  - Drawer navigation
  - Compact spacing
  - Smaller fonts

- **Tablet**: 768px - 1024px
  - Two column layouts
  - Side navigation
  - Medium spacing
  - Standard fonts

- **Desktop**: > 1024px
  - Three column layouts
  - Full side navigation
  - Generous spacing
  - Larger fonts

## Next Steps

To apply responsive design to other screens:
1. Wrap existing screens with `ResponsiveLayout`
2. Use `ResponsiveCard` for content sections
3. Replace regular `Text` with `ResponsiveText` where needed
4. Test on different screen sizes
5. Adjust breakpoints if needed 