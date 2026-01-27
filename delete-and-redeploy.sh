#!/bin/bash

# Delete and redeploy Cloud Functions
# This fixes the "Cannot update a GCF function without sourceUrl" error

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

echo "🗑️  Deleting existing Cloud Functions..."
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud is not installed. Using Firebase CLI instead..."
    USE_FIREBASE=true
else
    USE_FIREBASE=false
fi

# Set project
if [ "$USE_FIREBASE" = false ]; then
    gcloud config set project $PROJECT_ID
fi

# Delete each function
for func in "${FUNCTIONS[@]}"; do
    echo "   Deleting $func..."
    
    if [ "$USE_FIREBASE" = false ]; then
        # Use gcloud
        gcloud functions delete "$func" \
            --region "$REGION" \
            --gen1 \
            --quiet 2>/dev/null || echo "   ⚠️  Function $func not found or already deleted"
    else
        # Use Firebase CLI
        firebase functions:delete "$func" --region "$REGION" --force 2>/dev/null || \
            echo "   ⚠️  Function $func not found or already deleted"
    fi
done

echo ""
echo "⏳ Waiting for deletions to complete (30 seconds)..."
sleep 30

echo ""
echo "🔨 Building functions..."
cd functions
npm run build

echo ""
echo "🚀 Redeploying functions..."
firebase deploy --only functions --debug

echo ""
echo "✅ Done! Functions have been redeployed."
echo ""
echo "📝 Verify deployment:"
echo "   firebase functions:list"

