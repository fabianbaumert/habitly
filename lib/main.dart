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
import 'package:habitly/models/hive_habit.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/notification_service.dart'; // Add this import

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
  
  // Register Hive adapters
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TimeOfDayAdapter());
  }
  
  // Initialize habit storage service
  await HabitStorageService.init();
  logger.i('Habit storage service initialized');
  
  // Initialize notification service
  await NotificationService().initialize();
  logger.i('Notification service initialized');
  
  // Check if this is the first launch to request notification permissions
  final prefsBox = Hive.box('preferences');
  final bool hasRequestedNotificationPermissions = prefsBox.get('notificationPermissionsRequested', defaultValue: false);
  
  if (!hasRequestedNotificationPermissions) {
    logger.i('First launch detected, will request notification permissions');
    // Will request permissions when app loads in MainApp widget
  }
  
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
    
    // Request notification permissions on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefsBox = Hive.box('preferences');
      final bool hasRequestedNotificationPermissions = prefsBox.get('notificationPermissionsRequested', defaultValue: false);
      
      if (!hasRequestedNotificationPermissions) {
        appLogger.i('Requesting notification permissions on first launch');
        final permissionsGranted = await NotificationService().requestPermissions();
        await prefsBox.put('notificationPermissionsRequested', true);
        appLogger.i('Notification permissions request complete: $permissionsGranted');
      }
    });
    
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
