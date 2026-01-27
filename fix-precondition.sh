#!/bin/bash

# Fix "Precondition failed" errors for Cloud Functions deployment
# This script enables required APIs and grants necessary permissions

set -e

PROJECT_ID="deployinstantwebapp"
SERVICE_ACCOUNT="42298011440-compute@developer.gserviceaccount.com"

echo "🔧 Fixing Cloud Functions deployment prerequisites..."
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud is not installed. Please install Google Cloud SDK:"
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
echo "🔌 Enabling required Google Cloud APIs..."
echo ""

# Enable required APIs
APIS=(
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "logging.googleapis.com"
    "storage-component.googleapis.com"
    "firestore.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "   Enabling $api..."
    gcloud services enable "$api" --quiet || echo "   ⚠️  Could not enable $api (may already be enabled)"
done

echo ""
echo "✅ APIs enabled!"
echo ""

echo "🔑 Granting service account permissions..."
echo "   Service Account: $SERVICE_ACCOUNT"
echo ""

# Grant Cloud Functions Developer role
echo "   Granting Cloud Functions Developer role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/cloudfunctions.developer" \
    --condition=None 2>&1 | grep -v "Updated IAM policy" || echo "   ✓ Already has Cloud Functions Developer role"

# Grant Service Account User role
echo "   Granting Service Account User role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/iam.serviceAccountUser" \
    --condition=None 2>&1 | grep -v "Updated IAM policy" || echo "   ✓ Already has Service Account User role"

# Grant Cloud Build Service Account role
echo "   Granting Cloud Build Service Account role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/cloudbuild.builds.builder" \
    --condition=None 2>&1 | grep -v "Updated IAM policy" || echo "   ✓ Already has Cloud Build Service Account role"

echo ""
echo "✅ Permissions granted!"
echo ""

echo "📊 Verifying setup..."
echo ""

# Check enabled APIs
echo "Enabled APIs:"
gcloud services list --enabled --filter="name:cloudfunctions OR name:cloudbuild" --format="table(name)" 2>/dev/null || echo "   (Could not verify)"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Verify billing is enabled: https://console.cloud.google.com/billing"
echo "   2. Try deploying again:"
echo "      cd functions && npm run build && firebase deploy --only functions"
echo ""

