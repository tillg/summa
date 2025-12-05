#!/bin/bash

# Clean and Test Script for Summa
# This script cleans the build folder and runs tests

set -e  # Exit on error

echo "🧹 Cleaning build folder..."
cd "$(dirname "$0")/Summa"

# Clean the build folder
xcodebuild clean -project Summa.xcodeproj -scheme Summa

echo ""
echo "🔨 Building project..."
xcodebuild build -project Summa.xcodeproj -scheme Summa -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

echo ""
echo "🧪 Running tests..."
xcodebuild test -project Summa.xcodeproj -scheme Summa -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

echo ""
echo "✅ Tests complete!"
