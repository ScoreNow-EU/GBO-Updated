# 🚀 GBO Build Scripts

Automated build scripts with integrated version bumping for the German Beach Open app.

## 📋 Available Scripts

### 🎯 **Master Build Script** (Recommended)
```bash
./build.sh
```
- Interactive script for all platforms
- Automatic version bumping
- Supports iOS, Android, Web, or all platforms
- Color-coded output with progress indicators

### 🍎 **iOS Only**
```bash
./build_and_bump.sh
```
- Builds iOS release with version bump
- Automatically opens next steps for Xcode

### 🤖 **Android Only**
```bash
./build_android.sh
```
- Builds both APK and App Bundle
- Ready for Google Play Store

### 🔧 **Version Bump Only**
```bash
./bump_version.sh    # Patch: 0.1.1 → 0.1.2
./bump_minor.sh      # Minor: 0.1.1 → 0.2.0  
./bump_major.sh      # Major: 0.1.1 → 1.0.0
```

## 🎯 **Workflow**

### For App Store Connect:
1. Run `./build.sh`
2. Choose version bump type (usually patch for bug fixes)
3. Choose "iOS only" 
4. Follow the Xcode instructions shown

### For Google Play Store:
1. Run `./build.sh`
2. Choose version bump type
3. Choose "Android only"
4. Upload the generated App Bundle

### For Both Stores:
1. Run `./build.sh`
2. Choose version bump type
3. Choose "Both iOS and Android"
4. Follow instructions for both platforms

## 📱 **Version Strategy**

- **Patch (0.1.X)**: Bug fixes, small improvements
- **Minor (0.X.0)**: New features, backwards compatible
- **Major (X.0.0)**: Breaking changes, major releases

## 🎨 **Features**

✅ Automatic semantic versioning  
✅ Color-coded progress output  
✅ Error handling and validation  
✅ Multi-platform support  
✅ Clean builds (flutter clean + pub get)  
✅ Ready-to-upload outputs  

## 🚀 **Quick Start**

```bash
# Most common use case - iOS patch release
./build.sh
# Choose: 1 (patch), 1 (iOS)

# Android release  
./build.sh
# Choose: 1 (patch), 2 (Android)
```

---
*Generated for GBO v0.1.1 - German Beach Open Tournament Management System* 