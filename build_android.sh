#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🤖 Starting Android build with version bump...${NC}"

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: pubspec.yaml not found. Are you in a Flutter project directory?${NC}"
    exit 1
fi

# Read current version from pubspec.yaml
current_version=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
echo -e "${YELLOW}📋 Current version: $current_version${NC}"

# Ask user what type of version bump
echo -e "${BLUE}🔄 What type of version bump?${NC}"
echo "1) Patch (bug fixes): $current_version → $(echo $current_version | awk -F. '{print $1"."$2"."($3+1)}')"
echo "2) Minor (new features): $current_version → $(echo $current_version | awk -F. '{print $1"."($2+1)".0"}')"
echo "3) Major (breaking changes): $current_version → $(echo $current_version | awk -F. '{print ($1+1)".0.0"}')"
echo "4) No version bump, just build"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo -e "${YELLOW}🔧 Bumping patch version...${NC}"
        ./bump_version.sh
        ;;
    2)
        echo -e "${YELLOW}🔧 Bumping minor version...${NC}"
        ./bump_minor.sh
        ;;
    3)
        echo -e "${YELLOW}🔧 Bumping major version...${NC}"
        ./bump_major.sh
        ;;
    4)
        echo -e "${YELLOW}🔧 Skipping version bump...${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

# Get new version after bump
new_version=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
echo -e "${GREEN}✅ Version: $new_version${NC}"

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

# Build APK
echo -e "${BLUE}🏗️  Building Android APK...${NC}"
flutter build apk --release

# Build App Bundle (for Play Store)
echo -e "${BLUE}🏗️  Building Android App Bundle...${NC}"
flutter build appbundle --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Android build successful!${NC}"
    echo -e "${GREEN}📱 Version $new_version is ready for Google Play Store${NC}"
    echo -e "${YELLOW}💡 Build outputs:${NC}"
    echo "   📦 APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "   📦 App Bundle: build/app/outputs/bundle/release/app-release.aab"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi 