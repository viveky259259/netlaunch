import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutterkit/kit/kit.dart';
import 'package:netlaunch_auth/netlaunch_auth.dart';
import 'package:netlaunch_api/netlaunch_api.dart';
import 'package:netlaunch_ui/netlaunch_ui.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'FIREBASE_API_KEY_PLACEHOLDER',
      appId: 'FIREBASE_APP_ID_PLACEHOLDER',
      messagingSenderId: 'FIREBASE_MESSAGING_SENDER_ID_PLACEHOLDER',
      projectId: 'FIREBASE_PROJECT_ID_PLACEHOLDER',
      storageBucket: 'FIREBASE_STORAGE_BUCKET_PLACEHOLDER',
      authDomain: 'FIREBASE_AUTH_DOMAIN_PLACEHOLDER',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = FirebaseAuthProvider();
    return MultiProvider(
      providers: [
        Provider<AuthProvider>(create: (_) => authProvider),
        Provider<StorageService>(create: (_) => StorageService(authProvider)),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<FunctionsService>(create: (_) => FunctionsService()),
      ],
      child: MaterialApp(
        title: 'NetLaunch',
        theme: netLaunchTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return StreamBuilder<AuthUser?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: UkSpinner()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        return const LandingScreen();
      },
    );
  }
}
