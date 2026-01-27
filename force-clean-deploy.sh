#!/bin/bash

# Force clean delete and redeploy of Cloud Functions
# This script ensures functions are completely removed before redeploying

set -e

PROJECT_ID="deployinstantwebapp"
REGION="us-central1"

FUNCTIONS=(
    "onFileUploadTrigger"
    "generateApiKeyFunctionCallable"
    "listDeploymentsFunction"
    "deleteDeploymentFunction"
    "getDeploymentStatusFunction"
)

echo "🧹 Force cleaning and redeploying Cloud Functions..."
echo ""

# Check if gcloud is available
if command -v gcloud &> /dev/null; then
    echo "📋 Setting project to: $PROJECT_ID"
    gcloud config set project $PROJECT_ID
    USE_GCLOUD=true
else
    USE_GCLOUD=false
    echo "⚠️  gcloud not found, using Firebase CLI only"
fi

echo ""
echo "🗑️  Step 1: Deleting existing functions..."
echo ""

# Delete each function using both methods to ensure it's gone
for func in "${FUNCTIONS[@]}"; do
    echo "   Deleting $func..."
    
    # Try Firebase CLI first
    firebase functions:delete "$func" --region "$REGION" --force 2>/dev/null || true
    
    # Also try gcloud if available
    if [ "$USE_GCLOUD" = true ]; then
        gcloud functions delete "$func" \
            --region "$REGION" \
            --gen1 \
            --quiet 2>/dev/null || true
    fi
    
    echo "   ✓ $func deletion attempted"
done

echo ""
echo "⏳ Waiting 60 seconds for deletions to propagate..."
sleep 60

echo ""
echo "🔍 Step 2: Verifying functions are deleted..."
echo ""

# Verify functions are deleted
REMAINING_FUNCTIONS=$(firebase functions:list 2>/dev/null | grep -c "us-central1" || echo "0")

if [ "$REMAINING_FUNCTIONS" -gt 0 ]; then
    echo "⚠️  Some functions may still exist. Waiting another 30 seconds..."
    sleep 30
fi

echo ""
echo "🔨 Step 3: Building functions..."
cd functions

# Clean build
rm -rf lib/
npm run build

# Verify build succeeded
if [ ! -d "lib" ]; then
    echo "❌ Build failed! lib directory not found."
    exit 1
fi

echo "✅ Build successful!"
echo ""

echo "🚀 Step 4: Deploying functions..."
echo ""

# Deploy with explicit source
firebase deploy --only functions

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Verifying deployment..."
firebase functions:list

echo ""
echo "🎉 Done! All functions should be deployed successfully."

