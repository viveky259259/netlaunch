# How to Generate API Keys

There are several ways to generate API keys for the Firebase Hosting Service:

## Method 1: Using Cloud Function (Recommended)

After deploying the Cloud Functions, you can call the `generateApiKeyFunctionCallable` function.

### Using Firebase Console:

1. Go to Firebase Console > Functions
2. Find `generateApiKeyFunctionCallable`
3. Use the "Test" feature to call it
4. Copy the returned API key

### Using cURL:

```bash
curl -X POST \
  https://us-central1-deployinstantwebapp.cloudfunctions.net/generateApiKeyFunctionCallable \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Using JavaScript/Node.js:

```javascript
const functions = require('firebase-functions');
const generateApiKey = functions.httpsCallable('generateApiKeyFunctionCallable');

generateApiKey({})
  .then((result) => {
    console.log('API Key:', result.data.apiKey);
    console.log('Message:', result.data.message);
  })
  .catch((error) => {
    console.error('Error:', error);
  });
```

### Using Flutter (add to your app):

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<String> generateApiKey() async {
  final functions = FirebaseFunctions.instance;
  final callable = functions.httpsCallable('generateApiKeyFunctionCallable');
  
  try {
    final result = await callable.call();
    final apiKey = result.data['apiKey'] as String;
    return apiKey;
  } catch (e) {
    throw Exception('Failed to generate API key: $e');
  }
}
```

## Method 2: Using Firebase Emulator (Local Development)

1. Start Firebase Emulators:
   ```bash
   firebase emulators:start
   ```

2. Call the function locally:
   ```bash
   curl -X POST \
     http://localhost:5001/deployinstantwebapp/us-central1/generateApiKeyFunctionCallable \
     -H "Content-Type: application/json" \
     -d '{}'
   ```

## Method 3: Manual Generation Script

Create a script to generate API keys:

```javascript
// generate-key.js
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

async function generateApiKey() {
  const apiKey = `fk_${crypto.randomBytes(32).toString('hex')}`;
  const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');
  
  await db.collection('apiKeys').doc(hashedKey).set({
    apiKey: hashedKey,
    createdAt: admin.firestore.Timestamp.now(),
    usageCount: 0,
    lastUsed: null,
    metadata: {},
  });
  
  console.log('API Key generated:', apiKey);
  console.log('⚠️  Save this key securely - it will not be shown again!');
  
  return apiKey;
}

generateApiKey()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
```

Run it:
```bash
cd functions
node generate-key.js
```

## Method 4: Using Firebase Console (Manual)

1. Go to Firebase Console > Firestore Database
2. Navigate to the `apiKeys` collection
3. Click "Add document"
4. Generate a key manually:
   - Document ID: Use a SHA-256 hash of your API key
   - Fields:
     - `apiKey`: SHA-256 hash of your API key (string)
     - `createdAt`: Current timestamp
     - `usageCount`: 0 (number)
     - `lastUsed`: null
     - `metadata`: {} (map)

To generate the hash:
```bash
echo -n "fk_your_random_key_here" | shasum -a 256
```

## API Key Format

- Format: `fk_{64_character_hex_string}`
- Example: `fk_a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456`
- Length: 67 characters (3 for prefix + 64 for hex)

## Security Notes

1. **Save the API key immediately** - The plain text key is only shown once during generation
2. **Store securely** - Treat API keys like passwords
3. **Rotate regularly** - Generate new keys and delete old ones
4. **Monitor usage** - Check `usageCount` and `lastUsed` in Firestore
5. **Restrict access** - Consider adding authentication to the generate function

## Testing Your API Key

1. Open the Flutter web app
2. Enter your API key in the input field
3. Upload a test zip file
4. Check if the deployment starts successfully

## Troubleshooting

### "Invalid API key" error:
- Make sure the API key starts with `fk_`
- Verify the key exists in Firestore `apiKeys` collection
- Check that the hash matches (SHA-256 of the plain key)

### Key not found:
- Verify the key was saved correctly in Firestore
- Check the document ID matches the SHA-256 hash of your key
- Ensure Firestore rules allow Cloud Functions to read the collection

