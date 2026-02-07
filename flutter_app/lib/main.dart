import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutterkit/kit/kit.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/storage_service.dart';
import 'services/firestore_service.dart';
import 'services/functions_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCGFdR_W2fIX9bL9TMclqXglqhDj5b0eDc',
      appId: '1:42298011440:web:37416c5d27d5a4bfaf62f5',
      messagingSenderId: '42298011440',
      projectId: 'deployinstantwebapp',
      storageBucket: 'deployinstantwebapp.firebasestorage.app',
      authDomain: 'deployinstantwebapp.firebaseapp.com',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<FunctionsService>(create: (_) => FunctionsService()),
        Provider<AuthService>(create: (_) => AuthService()),
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
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
