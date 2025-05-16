import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/providers/theme_provider.dart';
import 'package:habitly/screens/auth/login_screen.dart';
import 'package:habitly/screens/home_screen.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:habitly/services/habit_history_storage_service.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/sync_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  final logger = appLogger;
  logger.i('Initializing application...');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  logger.i('Firebase initialized');

  // Initialize Firebase services - just accessing the instances ensures they're initialized
  FirebaseAuth.instance;
  FirebaseFirestore.instance;
  logger.i('Firebase services initialized');
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  logger.i('Hive initialized');
  
  // Open preference box for app settings
  await Hive.openBox('preferences');
  
  // Initialize habit storage service
  await HabitStorageService.init();
  logger.i('Habit storage service initialized');
  
  // Initialize habit history storage service
  await HabitHistoryStorageService.init();
  logger.i('Habit history storage service initialized');
  
  // Create providers container to manually initialize services
  final container = ProviderContainer();
  
  // Initialize connectivity monitoring and sync services
  // This ensures they're created and start listening for events
  container.read(connectivityServiceProvider);
  logger.i('Connectivity monitoring initialized');
  
  container.read(syncServiceProvider); 
  logger.i('Offline support with auto sync is ready');
  logger.i('App initialization complete');

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
