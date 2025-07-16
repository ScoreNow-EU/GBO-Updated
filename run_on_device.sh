#!/bin/bash

# Script to run Flutter on iPhone with xcrun fix

echo "🔧 Setting up environment for iPhone build..."

# Set PATH to use our custom xcrun
export PATH="$(pwd):$PATH"

# Verify our custom xcrun is being used
echo "📱 Using xcrun: $(which xcrun)"
echo "📱 Testing xcrun version:"
xcrun version

# Clear any cached build artifacts
echo "🧹 Cleaning Flutter build cache..."
flutter clean > /dev/null 2>&1

# Run Flutter on Marie's iPhone
echo "🚀 Starting Flutter on Marie's iPhone..."
flutter run -d "00008110-001E290E2208401E" --verbose 