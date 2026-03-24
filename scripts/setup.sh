#!/bin/bash
set -e

# NetLaunch Setup — injects Firebase config into source files
# Usage:
#   ./scripts/setup.sh              (uses local .env)
#   ./scripts/setup.sh --from-repo  (pulls .env from private repo first)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/.env"
CONFIG_REPO="https://github.com/viveky259259/netlaunch-config.git"
CONFIG_DIR="/tmp/netlaunch-config"

echo "=== NetLaunch Setup ==="

# Option: Pull from private config repo
if [ "$1" = "--from-repo" ]; then
  echo "Pulling config from private repo..."
  rm -rf "$CONFIG_DIR"
  git clone --depth 1 "$CONFIG_REPO" "$CONFIG_DIR" 2>/dev/null || {
    echo "ERROR: Could not clone config repo. Check access."
    exit 1
  }
  cp "$CONFIG_DIR/.env" "$ENV_FILE"
  rm -rf "$CONFIG_DIR"
  echo "Config pulled."
fi

# Check .env exists
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found."
  echo ""
  echo "Options:"
  echo "  1. cp .env.example .env  (then fill in your values)"
  echo "  2. ./scripts/setup.sh --from-repo  (pull from private repo)"
  exit 1
fi

# Source the .env
set -a
source "$ENV_FILE"
set +a

CLOUD_FUNCTIONS_URL="${CLOUD_FUNCTIONS_URL:-https://us-central1-${FIREBASE_PROJECT_ID}.cloudfunctions.net}"

echo "Project: $FIREBASE_PROJECT_ID"

# Replace all placeholders across the codebase
replace_placeholder() {
  local placeholder="$1"
  local value="$2"
  # Find all source files and replace
  find "$ROOT_DIR" \
    -not -path '*/node_modules/*' \
    -not -path '*/.dart_tool/*' \
    -not -path '*/build/*' \
    -not -path '*/.git/*' \
    -not -path '*/functions/lib/*' \
    \( -name '*.dart' -o -name '*.ts' -o -name '*.js' -o -name '*.html' -o -name '*.json' \) \
    -exec sed -i '' "s|${placeholder}|${value}|g" {} +
}

echo "Injecting config..."
replace_placeholder "FIREBASE_API_KEY_PLACEHOLDER" "$FIREBASE_API_KEY"
replace_placeholder "FIREBASE_APP_ID_PLACEHOLDER" "$FIREBASE_APP_ID"
replace_placeholder "FIREBASE_MESSAGING_SENDER_ID_PLACEHOLDER" "$FIREBASE_MESSAGING_SENDER_ID"
replace_placeholder "FIREBASE_PROJECT_ID_PLACEHOLDER" "$FIREBASE_PROJECT_ID"
replace_placeholder "FIREBASE_STORAGE_BUCKET_PLACEHOLDER" "$FIREBASE_STORAGE_BUCKET"
replace_placeholder "FIREBASE_AUTH_DOMAIN_PLACEHOLDER" "$FIREBASE_AUTH_DOMAIN"

echo ""
echo "=== Setup complete ==="
echo "Project: $FIREBASE_PROJECT_ID"
echo "Next: ./scripts/deploy.sh"
