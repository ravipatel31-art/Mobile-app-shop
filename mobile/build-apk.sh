#!/bin/bash

echo "Building Cafe POS APK..."
echo "================================"

# Navigate to mobile directory
cd "$(dirname "$0")"

# Clean and install dependencies
echo "Cleaning and installing dependencies..."
flutter clean
flutter pub get

# Build release APK
echo "Building release APK..."
flutter build apk --release --split-per-abi

# Check build output
echo "================================"
echo "Build completed!"
echo "================================"
echo ""
echo "APK files created:"
ls -lh build/app/outputs/flutter-apk/

echo ""
echo "To install on your phone:"
echo "1. Copy the APK file to your phone"
echo "2. Tap the APK file to install"
echo "3. Allow installation from unknown sources if prompted"

echo ""
echo "APK locations:"
echo "- ARM64-v8a: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo "- ARMv7: build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
echo "- x86_64: build/app/outputs/flutter-apk/app-x86_64-release.apk"
