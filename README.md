# German Beach Open - Tournament Management System

A comprehensive Flutter application for managing beach volleyball tournaments, built specifically for the German Beach Open (GBO).

## 🏐 Features

- **Tournament Management**: Create and manage beach volleyball tournaments
- **Team Management**: Register teams and manage rosters
- **Referee System**: Invite and manage referees with real-time notifications
- **Delegate Management**: Handle tournament delegates and officials
- **Real-time Updates**: Live tournament brackets and game results
- **Multi-platform**: iOS, Android, and Web support
- **Face ID Authentication**: Secure admin access on iOS devices
- **Push Notifications**: Background monitoring for referee invitations

## 🌐 Live Web App

The application is deployed and accessible at:
**https://gbo-updated.web.app**

## 🚀 Deployment

### Firebase Hosting

The web version is automatically deployed to Firebase Hosting:

#### Automatic Deployment
- **Main Branch**: Automatic deployment when code is pushed to `main`
- **Pull Requests**: Preview deployments for all pull requests

#### Manual Deployment
```bash
# Using the deployment script
./deploy.sh

# Or manually
flutter build web --release
firebase deploy --only hosting
```

### iOS Deployment
The iOS app can be distributed via TestFlight and the App Store.

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK (3.24.0 or later)
- Firebase CLI
- Xcode (for iOS development)
- Android Studio (for Android development)

### Installation
```bash
# Clone the repository
git clone https://github.com/ScoreNow-EU/GBO-Updated.git
cd GBO-Updated

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Configuration
The app is configured to use Firebase for:
- **Authentication**: User login and management
- **Firestore**: Real-time database for tournaments, teams, etc.
- **Analytics**: Usage tracking and insights
- **Hosting**: Web app deployment

## 📱 Platform Support

- ✅ **iOS**: Full support with Face ID authentication
- ✅ **Android**: Full support
- ✅ **Web**: Responsive design with PWA features
- 🚧 **macOS**: Limited support
- 🚧 **Windows/Linux**: Limited support

## 🔧 Configuration Files

- `firebase.json`: Firebase Hosting configuration
- `pubspec.yaml`: Flutter dependencies and project settings
- `lib/firebase_config.dart`: Firebase project configuration
- `.github/workflows/`: Automated deployment workflows

## 📄 License

This project is proprietary software developed for the German Beach Open.
