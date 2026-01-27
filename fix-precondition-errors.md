# Fix "Precondition failed" Errors in Cloud Functions Deployment

## Common Causes

"Precondition failed" errors typically occur due to:

1. **APIs not enabled** - Required Google Cloud APIs need to be enabled
2. **Billing not enabled** - Cloud Functions requires billing to be enabled
3. **Service account permissions** - Missing IAM permissions
4. **Resource quotas** - Exceeded quota limits
5. **Invalid configuration** - Issues in function code or configuration

## Solution Steps

### Step 1: Enable Required APIs

Enable the following APIs in Google Cloud Console:

```bash
# Enable Cloud Functions API
gcloud services enable cloudfunctions.googleapis.com

# Enable Cloud Build API (required for building functions)
gcloud services enable cloudbuild.googleapis.com

# Enable Cloud Logging API
gcloud services enable logging.googleapis.com

# Enable Cloud Storage API
gcloud services enable storage-component.googleapis.com

# Enable Firestore API (if using Firestore)
gcloud services enable firestore.googleapis.com

# Enable Cloud Resource Manager API
gcloud services enable cloudresourcemanager.googleapis.com
```

Or enable all at once:
```bash
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com \
  storage-component.googleapis.com \
  firestore.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### Step 2: Verify Billing is Enabled

1. Go to [Google Cloud Console - Billing](https://console.cloud.google.com/billing)
2. Ensure billing is enabled for project `deployinstantwebapp`
3. If not enabled, link a billing account

### Step 3: Check Service Account Permissions

The Cloud Functions service account needs these roles:

```bash
PROJECT_ID="deployinstantwebapp"
SERVICE_ACCOUNT="42298011440-compute@developer.gserviceaccount.com"

# Grant Cloud Functions Developer role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/cloudfunctions.developer"

# Grant Service Account User role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/iam.serviceAccountUser"

# Grant Cloud Build Service Account role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/cloudbuild.builds.builder"
```

### Step 4: Check Function Configuration

Verify your functions are correctly configured:

1. **Check runtime version** - Ensure Node.js 20 is available
2. **Check memory/timeout limits** - Ensure within quota
3. **Check region availability** - `us-central1` should be available

### Step 5: Check Build Logs

View detailed error messages:

```bash
# Check Firebase debug log
cat firebase-debug.log | tail -100

# Or check Cloud Build logs
gcloud builds list --limit=5
```

### Step 6: Try Deploying with Verbose Output

```bash
cd functions
npm run build
firebase deploy --only functions --debug
```

## Quick Fix Script

Run this script to enable all required APIs and fix permissions:

```bash
#!/bin/bash
PROJECT_ID="deployinstantwebapp"
SERVICE_ACCOUNT="42298011440-compute@developer.gserviceaccount.com"

echo "Enabling required APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com \
  storage-component.googleapis.com \
  firestore.googleapis.com \
  cloudresourcemanager.googleapis.com

echo "Granting service account permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/iam.serviceAccountUser"

echo "Done! Try deploying again."
```

## Alternative: Deploy Functions Individually

If deploying all functions fails, try deploying one at a time:

```bash
# Deploy one function to test
firebase deploy --only functions:generateApiKeyFunctionCallable

# If successful, deploy others
firebase deploy --only functions:listDeploymentsFunction
firebase deploy --only functions:deleteDeploymentFunction
firebase deploy --only functions:getDeploymentStatusFunction
firebase deploy --only functions:onFileUploadTrigger
```

## Check Firebase Project Status

```bash
# Verify project is active
firebase projects:list

# Check current project
firebase use

# Verify you're logged in
firebase login:list
```

## Common Issues and Solutions

### Issue: "API cloudfunctions.googleapis.com not enabled"
**Solution**: Enable the API (see Step 1)

### Issue: "Billing account not found"
**Solution**: Enable billing in Google Cloud Console

### Issue: "Permission denied"
**Solution**: Grant service account permissions (see Step 3)

### Issue: "Quota exceeded"
**Solution**: Check quotas in Google Cloud Console and request increase if needed

### Issue: "Invalid function configuration"
**Solution**: Check function code for syntax errors, verify package.json dependencies

## Verify Setup

After applying fixes, verify everything is set up:

```bash
# Check enabled APIs
gcloud services list --enabled | grep -E "(cloudfunctions|cloudbuild)"

# Check service account permissions
gcloud projects get-iam-policy deployinstantwebapp \
  --flatten="bindings[].members" \
  --filter="bindings.members:42298011440-compute@developer.gserviceaccount.com"
```

