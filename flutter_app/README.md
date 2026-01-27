# Flutter App - Firebase Hosting Service

This is the Flutter web application for the Firebase Hosting Service.

## Setup

1. Install Flutter and ensure web support is enabled:
   ```bash
   flutter config --enable-web
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your Firebase configuration to `lib/firebase_options.dart` (generate using Firebase CLI)
   - Or update `lib/main.dart` to initialize Firebase with your config

4. Run the app:
   ```bash
   flutter run -d chrome
   ```

5. Build for production:
   ```bash
   flutter build web
   ```

## Firebase Configuration

You need to add your Firebase configuration. You can generate it using:
```bash
flutterfire configure
```

Or manually create `lib/firebase_options.dart` with your Firebase config.

