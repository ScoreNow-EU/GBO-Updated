#!/bin/bash

# Fast iOS Build Script
# This script optimizes the build process for faster development

echo "🚀 Starting Fast iOS Build..."

# Set environment variables for faster builds
export FLUTTER_BUILD_MODE=debug
export FLUTTER_COMPILATION_MODE=debug
export XCODE_WORKSPACE_PATH="ios/Runner.xcworkspace"

# Clean only if first argument is 'clean'
if [ "$1" == "clean" ]; then
    echo "🧹 Cleaning project..."
    flutter clean
    rm -rf ios/Pods
    rm -rf ios/Podfile.lock
    rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
fi

# Build with optimizations
echo "📱 Building for iOS with optimizations..."
flutter build ios --debug --no-codesign --simulator --verbose

echo "✅ Build completed! Should be much faster now." 