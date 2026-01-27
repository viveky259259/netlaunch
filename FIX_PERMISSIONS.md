# Fix Cloud Functions Deployment Permissions

## Error
```
Access to bucket gcf-sources-42298011440-us-central1 denied. 
You must grant Storage Object Viewer permission to 42298011440-compute@developer.gserviceaccount.com
```

## Solution: Grant Storage Permissions

### Method 1: Using Google Cloud Console (Easiest)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: `deployinstantwebapp`
3. Navigate to **Cloud Storage** > **Buckets**
4. Find the bucket: `gcf-sources-42298011440-us-central1`
5. Click on the bucket name
6. Go to **Permissions** tab
7. Click **Grant Access**
8. Add principal: `42298011440-compute@developer.gserviceaccount.com`
9. Select role: **Storage Object Viewer**
10. Click **Save**

### Method 2: Using gcloud CLI

```bash
# Set the project
gcloud config set project deployinstantwebapp

# Grant Storage Object Viewer permission
gsutil iam ch serviceAccount:42298011440-compute@developer.gserviceaccount.com:objectViewer gs://gcf-sources-42298011440-us-central1
```

### Method 3: Using gcloud with bucket IAM

```bash
# Grant permission using gcloud
gcloud storage buckets add-iam-policy-binding gcf-sources-42298011440-us-central1 \
  --member="serviceAccount:42298011440-compute@developer.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

## Alternative: Use Default Service Account

If the above doesn't work, you can also grant the permission to the default App Engine service account:

```bash
# Grant to App Engine default service account
gsutil iam ch serviceAccount:deployinstantwebapp@appspot.gserviceaccount.com:objectViewer gs://gcf-sources-42298011440-us-central1
```

## Verify Permissions

After granting permissions, verify they're set correctly:

```bash
gsutil iam get gs://gcf-sources-42298011440-us-central1
```

You should see the service account listed with `roles/storage.objectViewer` or `objectViewer` permission.

## Retry Deployment

After fixing permissions, retry the deployment:

```bash
cd functions
npm run build
firebase deploy --only functions
```

## Additional Permissions That May Be Needed

If you still encounter issues, you may also need to grant:

1. **Cloud Functions Service Account** permissions:
   - `roles/cloudfunctions.developer`
   - `roles/iam.serviceAccountUser`

2. **Firestore permissions** (if using Firestore):
   - `roles/datastore.user`

3. **Storage permissions** (for your app's storage bucket):
   - `roles/storage.objectAdmin` or `roles/storage.admin`

## Quick Fix Script

Create a script to grant all necessary permissions:

```bash
#!/bin/bash
PROJECT_ID="deployinstantwebapp"
SERVICE_ACCOUNT="42298011440-compute@developer.gserviceaccount.com"
BUCKET="gcf-sources-42298011440-us-central1"

echo "Granting Storage Object Viewer permission..."
gsutil iam ch serviceAccount:${SERVICE_ACCOUNT}:objectViewer gs://${BUCKET}

echo "Granting Cloud Functions permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudfunctions.developer"

echo "Done! Try deploying again."
```

## Troubleshooting

### If you don't have gsutil installed:
```bash
# Install Google Cloud SDK
# macOS
brew install google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/docs/install
```

### If you get "permission denied" when running commands:
- Make sure you're logged in: `gcloud auth login`
- Make sure you have the right project: `gcloud config set project deployinstantwebapp`
- Make sure you have Owner or Editor role on the project

### If the bucket doesn't exist:
The bucket `gcf-sources-42298011440-us-central1` is automatically created by Firebase/Google Cloud Functions. If it doesn't exist, try deploying once and it should be created automatically, then grant permissions.

