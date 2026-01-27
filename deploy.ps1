# Firebase Hosting Service - Deploy Script (PowerShell)
# This script builds the Flutter web app and deploys it to Firebase Hosting

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting deployment process..." -ForegroundColor Cyan

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter not found"
    }
} catch {
    Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    exit 1
}

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Firebase CLI not found"
    }
} catch {
    Write-Host "❌ Firebase CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Firebase CLI: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Navigate to Flutter app directory
Write-Host "📱 Building Flutter web app..." -ForegroundColor Blue
Set-Location flutter_app

# Clean previous build
Write-Host "🧹 Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "📦 Getting Flutter dependencies..." -ForegroundColor Blue
flutter pub get

# Build for web
Write-Host "🔨 Building Flutter web app..." -ForegroundColor Blue
flutter build web --release

# Check if build was successful
if (-not (Test-Path "build/web")) {
    Write-Host "❌ Build failed! build/web directory not found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter app built successfully!" -ForegroundColor Green

# Navigate back to root
Set-Location ..

# Deploy to Firebase Hosting
Write-Host "🔥 Deploying to Firebase Hosting..." -ForegroundColor Blue
firebase deploy --only hosting

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "Your app should be live at: https://deployinstantwebapp.web.app" -ForegroundColor Green

