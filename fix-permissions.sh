#!/bin/bash

# Fix Cloud Functions Deployment Permissions
# This script grants the necessary permissions to deploy Cloud Functions

set -e

PROJECT_ID="deployinstantwebapp"
SERVICE_ACCOUNT="42298011440-compute@developer.gserviceaccount.com"
BUCKET="gcf-sources-42298011440-us-central1"

echo "🔧 Fixing Cloud Functions deployment permissions..."
echo ""

# Check if gsutil is available
if ! command -v gsutil &> /dev/null; then
    echo "❌ gsutil is not installed. Please install Google Cloud SDK:"
    echo "   brew install google-cloud-sdk"
    echo "   Or visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if logged in
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "⚠️  Not logged in to Google Cloud. Please run:"
    echo "   gcloud auth login"
    exit 1
fi

# Set the project
echo "📋 Setting project to: $PROJECT_ID"
gcloud config set project $PROJECT_ID

echo ""
echo "🔑 Granting Storage Object Viewer permission to service account..."
echo "   Service Account: $SERVICE_ACCOUNT"
echo "   Bucket: $BUCKET"
echo ""

# Grant Storage Object Viewer permission
if gsutil iam ch serviceAccount:${SERVICE_ACCOUNT}:objectViewer gs://${BUCKET} 2>&1; then
    echo "✅ Storage permission granted successfully!"
else
    echo "⚠️  Could not grant permission via gsutil. Trying alternative method..."
    
    # Alternative: Use gcloud storage
    if command -v gcloud &> /dev/null; then
        gcloud storage buckets add-iam-policy-binding ${BUCKET} \
            --member="serviceAccount:${SERVICE_ACCOUNT}" \
            --role="roles/storage.objectViewer" 2>&1 || {
            echo "❌ Failed to grant permission. Please grant manually via Google Cloud Console:"
            echo "   1. Go to: https://console.cloud.google.com/storage/browser/${BUCKET}"
            echo "   2. Click on the bucket"
            echo "   3. Go to Permissions tab"
            echo "   4. Grant 'Storage Object Viewer' to: ${SERVICE_ACCOUNT}"
            exit 1
        }
        echo "✅ Permission granted using gcloud!"
    else
        echo "❌ Both gsutil and gcloud methods failed."
        echo "   Please grant permission manually via Google Cloud Console"
        exit 1
    fi
fi

echo ""
echo "✅ Permissions fixed! You can now deploy functions:"
echo "   cd functions && npm run build && firebase deploy --only functions"
echo ""

