# Setup Guide
fk_6c39aa2a134b603e6f7823100d6a59f30f3e3dadb2f10e967a6bb6965c2c1b0d
## Prerequisites

1. **Node.js 20+** - [Download](https://nodejs.org/)
2. **Flutter SDK** - [Download](https://flutter.dev/docs/get-started/install)
3. **Firebase CLI** - Install with: `npm install -g firebase-tools`
4. **Firebase Project** - Create at [Firebase Console](https://console.firebase.google.com/)

## Step-by-Step Setup

### 1. Initialize Firebase Project

```bash
# Login to Firebase
firebase login

# Initialize Firebase (if not already done)
firebase init

# Select:
# - Firestore
# - Functions
# - Hosting
# - Storage
```

### 2. Configure Firebase Project

Update `.firebaserc` with your Firebase project ID:
```json
{
  "projects": {
    "default": "your-actual-project-id"
  }
}
```

### 3. Set Environment Variables

```bash
# Set custom domain for subdomains
firebase functions:config:set custom_domain.domain="yourdomain.com"
```

### 4. Install Backend Dependencies

```bash
cd functions
npm install
npm run build
```

### 5. Install Flutter Dependencies

```bash
cd flutter_app
flutter pub get
```

### 6. Configure Flutter Firebase

**Option A: Using FlutterFire CLI (Recommended)**
```bash
cd flutter_app
flutterfire configure
```

**Option B: Manual Configuration**

Update `flutter_app/lib/main.dart` with your Firebase configuration:
```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  ),
);
```

### 7. Deploy Firebase Rules

```bash
firebase deploy --only firestore:rules,storage:rules
```

### 8. Deploy Cloud Functions

```bash
cd functions
npm run build
firebase deploy --only functions
```

### 9. Build and Deploy Flutter App

```bash
cd flutter_app
flutter build web
firebase deploy --only hosting
```

## Generate API Keys

API keys can be generated programmatically. You can create a simple script or use the Firebase Console to add them to Firestore.

**Firestore Collection: `apiKeys`**

Document structure:
```json
{
  "apiKey": "hashed_api_key_string",
  "createdAt": "timestamp",
  "usageCount": 0,
  "lastUsed": null,
  "metadata": {}
}
```

To generate an API key, you can:
1. Use the `generateApiKey` function from Cloud Functions
2. Create a temporary Cloud Function to generate keys
3. Manually create hashed keys in Firestore

**API Key Format**: `fk_{random_hex_string}`

Example: `fk_88f679a3c5c60f1b652f689347e31b8848670957bc560134a45fdfab0bc963bb`

## Testing Locally

### Test Flutter App
```bash
cd flutter_app
flutter run -d chrome
```

### Test Cloud Functions Locally
```bash
cd functions
npm run serve
```

### Use Firebase Emulators
```bash
firebase emulators:start
```

## Subdomain Configuration

To enable subdomain deployments:

1. **Add Custom Domain in Firebase Hosting**:
   - Go to Firebase Console > Hosting
   - Add your custom domain (e.g., `yourdomain.com`)

2. **Configure DNS**:
   - Add a wildcard A record: `*.yourdomain.com` → Firebase Hosting IP
   - Or use CNAME: `*.yourdomain.com` → Firebase Hosting domain

3. **Update Environment Variable**:
   ```bash
   firebase functions:config:set custom_domain.domain="yourdomain.com"
   firebase deploy --only functions
   ```

## Troubleshooting

### Flutter Linter Errors
Run `flutter pub get` in the `flutter_app` directory to install dependencies.

### Firebase Initialization Error
Make sure you've configured Firebase options in `lib/main.dart` or run `flutterfire configure`.

### Deployment Fails
- Check Cloud Functions logs: `firebase functions:log`
- Verify API key is valid
- Ensure zip file contains valid web files (e.g., index.html)
- Check Firestore and Storage rules are deployed

### Subdomain Not Working
- Verify DNS wildcard is configured correctly
- Check custom domain is added in Firebase Hosting console
- Ensure `CUSTOM_DOMAIN` environment variable is set in Cloud Functions

## Next Steps

1. Generate your first API key
2. Test file upload and deployment
3. Configure your custom domain
4. Set up DNS for subdomains
5. Start deploying!

