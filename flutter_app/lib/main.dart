import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/upload_screen.dart';
import 'services/storage_service.dart';
import 'services/firestore_service.dart';
import 'services/functions_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
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
      ],
      child: MaterialApp(
        title: 'Firebase Hosting Service',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const UploadScreen(),
      ),
    );
  }
}

