# Fix "Cannot update a GCF function without sourceUrl" Error

## Error
```
Precondition failed. Cannot update a GCF function without sourceUrl
```

## Cause
This error occurs when Firebase tries to update existing Cloud Functions that don't have a valid source URL. This can happen when:
- Functions were partially deployed
- Source code upload failed in a previous deployment
- Functions are in an inconsistent state

## Solution: Delete and Redeploy

### Option 1: Delete All Functions and Redeploy (Recommended)

```bash
# Delete all existing functions
firebase functions:delete onFileUploadTrigger --region us-central1 --force
firebase functions:delete generateApiKeyFunctionCallable --region us-central1 --force
firebase functions:delete listDeploymentsFunction --region us-central1 --force
firebase functions:delete deleteDeploymentFunction --region us-central1 --force
firebase functions:delete getDeploymentStatusFunction --region us-central1 --force

# Wait a few seconds, then redeploy
cd functions
npm run build
firebase deploy --only functions
```

### Option 2: Delete via Google Cloud Console

1. Go to [Cloud Functions Console](https://console.cloud.google.com/functions)
2. Select project: `deployinstantwebapp`
3. Select region: `us-central1`
4. Delete each function:
   - `onFileUploadTrigger`
   - `generateApiKeyFunctionCallable`
   - `listDeploymentsFunction`
   - `deleteDeploymentFunction`
   - `getDeploymentStatusFunction`
5. Wait for deletion to complete
6. Redeploy: `firebase deploy --only functions`

### Option 3: Use gcloud CLI to Delete

```bash
# Set project
gcloud config set project deployinstantwebapp

# Delete functions
gcloud functions delete onFileUploadTrigger --region us-central1 --gen1 --quiet
gcloud functions delete generateApiKeyFunctionCallable --region us-central1 --gen1 --quiet
gcloud functions delete listDeploymentsFunction --region us-central1 --gen1 --quiet
gcloud functions delete deleteDeploymentFunction --region us-central1 --gen1 --quiet
gcloud functions delete getDeploymentStatusFunction --region us-central1 --gen1 --quiet

# Wait a minute, then redeploy
cd functions
npm run build
firebase deploy --only functions
```

## Alternative: Force Redeploy with Source

If deletion doesn't work, try forcing a new deployment:

```bash
cd functions
npm run build

# Deploy with force flag (if available)
firebase deploy --only functions --force

# Or deploy one at a time
firebase deploy --only functions:generateApiKeyFunctionCallable
firebase deploy --only functions:listDeploymentsFunction
firebase deploy --only functions:deleteDeploymentFunction
firebase deploy --only functions:getDeploymentStatusFunction
firebase deploy --only functions:onFileUploadTrigger
```

## Verify Functions Are Deleted

Before redeploying, verify functions are deleted:

```bash
# List functions
gcloud functions list --region us-central1

# Or via Firebase
firebase functions:list
```

## After Redeployment

Once functions are redeployed successfully, verify they're working:

```bash
# Check function status
firebase functions:list

# Test a function (example)
curl https://us-central1-deployinstantwebapp.cloudfunctions.net/generateApiKeyFunctionCallable \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Prevention

To avoid this issue in the future:
- Always wait for deployment to complete before interrupting
- Don't delete source code immediately after deployment
- Keep backup of function source code
- Use version control for function code

