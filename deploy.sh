#!/bin/bash

# Firebase Hosting Service - Deploy Script
# This script builds the Flutter web app and deploys it to Firebase Hosting

set -e  # Exit on error

echo "🚀 Starting deployment process..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI is not installed or not in PATH${NC}"
    echo "Please install Firebase CLI: npm install -g firebase-tools"
    exit 1
fi

# Navigate to Flutter app directory
echo -e "${BLUE}📱 Building Flutter web app...${NC}"
cd flutter_app

# Clean previous build
echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}📦 Getting Flutter dependencies...${NC}"
flutter pub get

# Build for web
echo -e "${BLUE}🔨 Building Flutter web app...${NC}"
flutter build web --release

# Check if build was successful
if [ ! -d "build/web" ]; then
    echo -e "${RED}❌ Build failed! build/web directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Flutter app built successfully!${NC}"

# Navigate back to root
cd ..

# Deploy to Firebase Hosting
echo -e "${BLUE}🔥 Deploying to Firebase Hosting...${NC}"
firebase deploy --only hosting

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}Your app should be live at: https://deployinstantwebapp.web.app${NC}"

