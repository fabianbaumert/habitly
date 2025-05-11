import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/providers/theme_provider.dart';
import 'package:habitly/screens/auth/login_screen.dart';
import 'package:habitly/screens/home_screen.dart';
import 'package:habitly/models/hive_habit.dart';
import 'package:habitly/services/habit_storage_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase services - just accessing the instances ensures they're initialized
  FirebaseAuth.instance;
  FirebaseFirestore.instance;
  
  // Initialize Firebase Messaging and request permissions
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Open preference box for app settings
  await Hive.openBox('preferences');
  
  // Register Hive adapters
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TimeOfDayAdapter());
  }
  
  // Initialize habit storage service
  await HabitStorageService.init();

  runApp(
    // Wrap app with ProviderScope for Riverpod
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    // Get the current theme from the theme provider
    final appTheme = ref.watch(appThemeProvider);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habitly',
      // Use the theme from the provider
      theme: appTheme,
      home: authState.when(
        data: (user) {
          // If user is authenticated, show home screen, otherwise show login
          return user != null ? const HomeScreen() : const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Scaffold(
          body: Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }
}
