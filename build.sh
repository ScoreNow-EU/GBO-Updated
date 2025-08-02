#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🚀 GBO Universal Build Script${NC}"
echo -e "${BLUE}===============================${NC}"

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

# Ask user which platform to build
echo -e "${BLUE}🎯 Which platform to build?${NC}"
echo "1) iOS only"
echo "2) Android only"
echo "3) Both iOS and Android"
echo "4) Web"

read -p "Enter choice (1-4): " platform_choice

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

case $platform_choice in
    1)
        echo -e "${BLUE}🍎 Building iOS release...${NC}"
        flutter build ios --release
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ iOS build successful!${NC}"
            echo -e "${YELLOW}💡 Next steps:${NC}"
            echo "   1. Open Xcode: open ios/Runner.xcworkspace"
            echo "   2. Archive and upload to App Store Connect"
        fi
        ;;
    2)
        echo -e "${BLUE}🤖 Building Android releases...${NC}"
        flutter build apk --release
        flutter build appbundle --release
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Android builds successful!${NC}"
            echo -e "${YELLOW}💡 Build outputs:${NC}"
            echo "   📦 APK: build/app/outputs/flutter-apk/app-release.apk"
            echo "   📦 App Bundle: build/app/outputs/bundle/release/app-release.aab"
        fi
        ;;
    3)
        echo -e "${BLUE}🍎🤖 Building both iOS and Android...${NC}"
        
        # Build iOS
        echo -e "${BLUE}🍎 Building iOS...${NC}"
        flutter build ios --release
        ios_success=$?
        
        # Build Android
        echo -e "${BLUE}🤖 Building Android APK...${NC}"
        flutter build apk --release
        apk_success=$?
        
        echo -e "${BLUE}🤖 Building Android App Bundle...${NC}"
        flutter build appbundle --release
        aab_success=$?
        
        # Report results
        if [ $ios_success -eq 0 ] && [ $apk_success -eq 0 ] && [ $aab_success -eq 0 ]; then
            echo -e "${GREEN}✅ All builds successful!${NC}"
            echo -e "${YELLOW}💡 iOS Next steps:${NC}"
            echo "   1. Open Xcode: open ios/Runner.xcworkspace"
            echo "   2. Archive and upload to App Store Connect"
            echo -e "${YELLOW}💡 Android outputs:${NC}"
            echo "   📦 APK: build/app/outputs/flutter-apk/app-release.apk"
            echo "   📦 App Bundle: build/app/outputs/bundle/release/app-release.aab"
        else
            echo -e "${RED}❌ Some builds failed!${NC}"
        fi
        ;;
    4)
        echo -e "${BLUE}🌐 Building web...${NC}"
        flutter build web --release
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Web build successful!${NC}"
            echo -e "${YELLOW}💡 Output: build/web/${NC}"
            
            # Ask if user wants to deploy to Firebase
            echo ""
            echo -e "${BLUE}🚀 Deploy to Firebase Hosting?${NC}"
            echo "1) Yes, deploy now"
            echo "2) No, just build"
            
            read -p "Enter choice (1-2): " deploy_choice
            
            case $deploy_choice in
                1)
                    echo -e "${BLUE}🔧 Checking Firebase CLI...${NC}"
                    if ! command -v firebase &> /dev/null; then
                        echo -e "${RED}❌ Firebase CLI not found. Please install it first:${NC}"
                        echo -e "${YELLOW}   npm install -g firebase-tools${NC}"
                        echo -e "${YELLOW}   or: curl -sL https://firebase.tools | bash${NC}"
                        exit 1
                    fi
                    
                    echo -e "${BLUE}🚀 Deploying to Firebase Hosting...${NC}"
                    firebase deploy --only hosting
                    
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✅ Deployment successful!${NC}"
                        echo -e "${PURPLE}🌐 Your app is now live!${NC}"
                        
                        # Try to get the hosting URL from Firebase
                        echo -e "${YELLOW}💡 Check your Firebase console for the live URL${NC}"
                    else
                        echo -e "${RED}❌ Deployment failed!${NC}"
                        echo -e "${YELLOW}💡 You can deploy later using: firebase deploy --only hosting${NC}"
                    fi
                    ;;
                2)
                    echo -e "${YELLOW}⏭️ Skipping deployment...${NC}"
                    echo -e "${YELLOW}💡 To deploy later, run: firebase deploy --only hosting${NC}"
                    ;;
                *)
                    echo -e "${RED}❌ Invalid choice. Skipping deployment.${NC}"
                    echo -e "${YELLOW}💡 To deploy later, run: firebase deploy --only hosting${NC}"
                    ;;
            esac
        else
            echo -e "${RED}❌ Web build failed!${NC}"
        fi
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

echo -e "${PURPLE}🎉 Build process complete for version $new_version!${NC}" 