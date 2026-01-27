#!/bin/bash

# Create Firebase Storage bucket if it doesn't exist

set -e

PROJECT_ID="deployinstantwebapp"
BUCKET_NAME="deployinstantwebapp.firebasestorage.app"
REGION="us-central1"

echo "🪣 Creating Firebase Storage bucket..."
echo ""

# Check if bucket exists
if gsutil ls -b "gs://${BUCKET_NAME}" &>/dev/null; then
    echo "✅ Bucket already exists: ${BUCKET_NAME}"
else
    echo "Creating bucket: ${BUCKET_NAME}"
    echo "Region: ${REGION}"
    echo ""
    
    # Create the bucket
    gsutil mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} "gs://${BUCKET_NAME}" || {
        echo "❌ Failed to create bucket. Trying alternative method..."
        
        # Alternative: Use gcloud
        gcloud storage buckets create "gs://${BUCKET_NAME}" \
            --project=${PROJECT_ID} \
            --location=${REGION} \
            --default-storage-class=STANDARD || {
            echo "❌ Could not create bucket. Please create it manually:"
            echo "   1. Go to: https://console.cloud.google.com/storage"
            echo "   2. Create bucket: ${BUCKET_NAME}"
            echo "   3. Region: ${REGION}"
            exit 1
        }
    }
    
    echo "✅ Bucket created successfully!"
fi

echo ""
echo "📝 Bucket details:"
gsutil ls -L -b "gs://${BUCKET_NAME}" | head -10

echo ""
echo "✅ Storage bucket is ready!"

