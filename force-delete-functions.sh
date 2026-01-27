#!/bin/bash

# Force delete all Cloud Functions
# Run this first, then wait, then redeploy

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

echo "🗑️  Force deleting all Cloud Functions..."
echo ""

# Set project if gcloud is available
if command -v gcloud &> /dev/null; then
    gcloud config set project $PROJECT_ID
    echo "Using gcloud for deletion..."
    echo ""
    
    for func in "${FUNCTIONS[@]}"; do
        echo "Deleting $func..."
        gcloud functions delete "$func" \
            --region "$REGION" \
            --quiet 2>&1 || echo "  (May not exist)"
    done
else
    echo "Using Firebase CLI for deletion..."
    echo ""
    
    for func in "${FUNCTIONS[@]}"; do
        echo "Deleting $func..."
        firebase functions:delete "$func" --region "$REGION" --force 2>&1 || echo "  (May not exist)"
    done
fi

echo ""
echo "✅ Deletion commands sent. Waiting 90 seconds for propagation..."
echo "   (Cloud Functions deletion can take time)"
echo ""
echo "After waiting, run:"
echo "  cd functions && npm run build && firebase deploy --only functions"

