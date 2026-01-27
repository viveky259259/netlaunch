# Firebase Hosting Service

A web application that allows users to upload zip files and automatically deploy them to Firebase Hosting with unique subdomains.

## Architecture

- **Frontend**: Flutter web application
- **Backend**: Firebase Cloud Functions
- **Storage**: Firebase Storage for file uploads
- **Database**: Firestore for API keys and deployment metadata
- **Hosting**: Firebase Hosting with subdomain-based deployments

## Project Structure

```
firebase_hosting_service/
├── flutter_app/          # Flutter web frontend
├── functions/            # Firebase Cloud Functions
├── firebase/             # Firebase configuration files
├── .firebaserc           # Firebase project configuration
└── firebase.json         # Firebase hosting and functions config
```

## Setup Instructions

### Prerequisites

1. Node.js 20+ installed
2. Flutter SDK installed with web support enabled
3. Firebase CLI installed (`npm install -g firebase-tools`)
4. Firebase project created

### Initial Setup

1. **Configure Firebase Project**:
   ```bash
   firebase login
   firebase use --add
   ```
   Update `.firebaserc` with your project ID.

2. **Set Environment Variables**:
   ```bash
   firebase functions:config:set custom_domain="yourdomain.com"
   ```

3. **Install Backend Dependencies**:
   ```bash
   cd functions
   npm install
   ```

4. **Install Flutter Dependencies**:
   ```bash
   cd flutter_app
   flutter pub get
   ```

5. **Configure Flutter Firebase**:
   ```bash
   cd flutter_app
   flutterfire configure
   ```
   Or manually update `lib/main.dart` with your Firebase configuration.

### Deploy Firebase Rules

```bash
firebase deploy --only firestore:rules,storage:rules
```

### Deploy Cloud Functions

```bash
cd functions
npm run build
firebase deploy --only functions
```

### Build and Deploy Flutter App

```bash
cd flutter_app
flutter build web
firebase deploy --only hosting
```

## Usage

1. **Generate API Key**:
   - API keys can be generated programmatically using the `generateApiKey` function in Cloud Functions
   - Or create them manually in Firestore `apiKeys` collection

2. **Upload and Deploy**:
   - Open the Flutter web app
   - Enter your API key
   - Select a zip file containing your web project
   - Click "Upload and Deploy"
   - Wait for deployment to complete
   - Copy the deployment URL

3. **Manage Deployments**:
   - Click the list icon to view all your deployments
   - Delete deployments as needed

## API Key Format

API keys follow the format: `fk_{random_hex_string}`

Example: `fk_a1b2c3d4e5f6...`

## File Upload Requirements

- Files must be ZIP format
- Maximum file size: 100MB
- Must contain at least one HTML file (e.g., `index.html`)
- Files are uploaded to: `uploads/{apiKey}/{timestamp}.zip`

## Deployment Flow

1. User uploads zip file with API key
2. File is stored in Firebase Storage
3. Storage trigger fires Cloud Function
4. Cloud Function validates API key
5. Zip file is extracted
6. Files are validated
7. Unique subdomain is generated
8. Files are deployed to Firebase Hosting
9. Deployment URL is returned to user

## Subdomain Setup

To enable subdomain deployments:

1. Configure custom domain in Firebase Hosting console
2. Set up wildcard DNS: `*.yourdomain.com` → Firebase Hosting
3. Update `CUSTOM_DOMAIN` environment variable in Cloud Functions

## Security

- API keys are hashed before storage
- Firestore rules restrict direct client access
- Storage rules validate file types and sizes
- Cloud Functions validate all API keys
- File paths are sanitized

## Development

### Run Flutter App Locally

```bash
cd flutter_app
flutter run -d chrome
```

### Test Cloud Functions Locally

```bash
cd functions
npm run serve
```

### Emulator Suite

```bash
firebase emulators:start
```

## Troubleshooting

### Firebase Initialization Error

Make sure you've run `flutterfire configure` or manually added Firebase options in `lib/main.dart`.

### Deployment Fails

- Check Cloud Functions logs: `firebase functions:log`
- Verify API key is valid
- Ensure zip file contains valid web files
- Check Firestore and Storage rules are deployed

### Subdomain Not Working

- Verify DNS wildcard is configured
- Check custom domain is added in Firebase Hosting
- Ensure `CUSTOM_DOMAIN` environment variable is set

## License

MIT

