#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== NetLaunch Deploy ==="

# Ensure config is injected
if [ ! -f "$ROOT_DIR/.env" ]; then
  echo "No .env found. Running setup first..."
  "$SCRIPT_DIR/setup.sh" --from-repo
fi

# Source config
set -a
source "$ROOT_DIR/.env"
set +a

echo "Deploying to project: $FIREBASE_PROJECT_ID"

# Inject config into all files
"$SCRIPT_DIR/setup.sh"

# Build functions
echo ""
echo "=== Building Cloud Functions ==="
cd "$ROOT_DIR/functions"
npm run build

# Build Flutter web
echo ""
echo "=== Building Flutter Web ==="
cd "$ROOT_DIR/flutter_app"
flutter build web

# Copy cli-auth.html to build output
cp "$ROOT_DIR/flutter_app/web/cli-auth.html" "$ROOT_DIR/flutter_app/build/web/cli-auth.html"

# Deploy to Firebase
echo ""
echo "=== Deploying to Firebase ==="
cd "$ROOT_DIR"
firebase deploy

echo ""
echo "=== Deploy complete ==="
echo "Dashboard: https://$FIREBASE_PROJECT_ID.web.app"
