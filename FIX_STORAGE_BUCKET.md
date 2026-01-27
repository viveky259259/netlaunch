# Fix Storage Bucket Issue

## Error
```
Cloud Storage trigger bucket deployinstantwebapp.firebasestorage.app not found
```

## Solution: Create Storage Bucket via Firebase Console

The `.firebasestorage.app` bucket is a special Firebase domain bucket that must be created through Firebase Console, not via gsutil.

### Steps:

1. **Go to Firebase Console**:
   - Visit: https://console.firebase.google.com/
   - Select project: `deployinstantwebapp`

2. **Enable Storage**:
   - Go to **Build** > **Storage**
   - Click **Get Started** (if not already enabled)
   - Choose **Start in production mode** (we'll use security rules)
   - Select location: **us-central1** (or your preferred region)
   - Click **Done**

3. **Verify Bucket Created**:
   - The bucket `deployinstantwebapp.firebasestorage.app` should now exist
   - You can verify in Google Cloud Console: https://console.cloud.google.com/storage

4. **Deploy Storage Rules**:
   ```bash
   firebase deploy --only storage:rules
   ```

5. **Redeploy Functions**:
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions:onFileUploadTrigger
   ```

## Alternative: Use Regular Bucket

If you prefer to use a regular bucket name:

1. **Update Flutter App** (`flutter_app/lib/main.dart`):
   ```dart
   storageBucket: 'deployinstantwebapp-uploads.firebasestorage.app',
   ```

2. **Update Storage Service** to use the new bucket name

3. **Update Storage Trigger** in `functions/src/index.ts` to specify the bucket:
   ```typescript
   export const onFileUploadTrigger = functions
     .region('us-central1')
     .storage
     .bucket('deployinstantwebapp-uploads')
     .object()
     .onFinalize(onFileUpload);
   ```

## Quick Fix Command

After creating the bucket via Firebase Console, run:

```bash
cd functions
npm run build
firebase deploy --only functions:onFileUploadTrigger
```

