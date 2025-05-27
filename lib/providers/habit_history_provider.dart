import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_history_storage_service.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/sync_service.dart';

// Provider for the habit history storage service
final habitHistoryStorageServiceProvider = Provider<HabitHistoryStorageService>((ref) {
  return HabitHistoryStorageService();
});

// Provider for tracking the current user ID to invalidate caches on user change
final currentUserIdProvider = StateProvider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

// Provider for habit history (completion by date)
final habitHistoryProvider = StreamProvider.family<Map<String, bool>, DateTime>((ref, date) async* {
  // Using the authStateProvider directly to get the most up-to-date auth state
  final authState = ref.watch(authStateProvider);
  
  // Wait for auth state to resolve and yield empty if no user
  final user = authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
  
  if (user == null) {
    yield {};
    return;
  }
  
  try {
    // Format the date as YYYY-MM-DD for storage
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    // First try to get data from local storage to avoid permission issues during transitions
    final historyStorage = ref.read(habitHistoryStorageServiceProvider);
    final localData = await historyStorage.getHabitHistory(user.uid, dateString);
    
    // Yield local data first to prevent UI from showing errors during auth transitions
    yield localData;
    
    // Listen to Firestore for real-time updates for the CURRENT user
    final docStream = FirebaseFirestore.instance
        .collection('habitHistory')
        .doc(user.uid) 
        .collection('dates')
        .doc(dateString)
        .snapshots();
        
    await for (final snapshot in docStream) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, bool> firebaseData = Map.from(data.map(
          (key, value) => MapEntry(key, value as bool)
        ));
        yield firebaseData;
      } else {
        yield {};
      }
    }
  } catch (e) {
    appLogger.e('Error fetching habit history: $e');
    yield {}; // Return empty map on error
  }
});

// Provider to get completion rate for a specific date
final completionRateProvider = FutureProvider.family<double, DateTime>((ref, date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0.0;

  try {
    // Get all habits that existed on this date
    final habitsOnDate = await FirebaseFirestore.instance
        .collection('habits')
        .where('userId', isEqualTo: user.uid)
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(date))
        .get();
        
    if (habitsOnDate.docs.isEmpty) return 0.0;

    // Get the completion status for this date
    final historyData = await ref.read(habitHistoryProvider(date).future);

    // Count completed habits
    int completedHabits = 0;
    for (final doc in habitsOnDate.docs) {
      final habitId = doc.id;
      if (historyData[habitId] == true) {
        completedHabits++;
      }
    }

    return completedHabits / habitsOnDate.docs.length;
  } catch (e) {
    appLogger.e('Error calculating completion rate: $e');
    return 0.0;
  }
});

// Provider to check if all habits were completed on a specific date
final allHabitsCompletedProvider = FutureProvider.family<bool, DateTime>((ref, date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  
  try {
    // Get all habits that existed on this date
    final habitsOnDate = await FirebaseFirestore.instance
        .collection('habits')
        .where('userId', isEqualTo: user.uid)
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(date))
        .get();
        
    if (habitsOnDate.docs.isEmpty) return false;

    // Get the completion status for this date
    final historyData = await ref.read(habitHistoryProvider(date).future);
    if (historyData.isEmpty) return false;

    // Check if all habits were completed
    for (final doc in habitsOnDate.docs) {
      final habitId = doc.id;
      if (historyData[habitId] != true) {
        return false; // At least one habit was not completed
      }
    }
    
    return true; // All habits were completed
  } catch (e) {
    appLogger.e('Error checking habit completion: $e');
    return false;
  }
});

// Function to record habit completion for a specific date
Future<void> recordHabitCompletion(String habitId, bool completed, DateTime date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    // Use the sync service to handle this operation with offline support
    final syncService = ProviderContainer().read(syncServiceProvider);
    await syncService.recordHabitCompletion(habitId, completed, date);
    
    // Note: We don't need to invalidate the provider here as it will be done by 
    // the calling function in today_screen.dart via ref.invalidate()
    
    appLogger.i('Recorded habit $habitId as ${completed ? "completed" : "uncompleted"} for ${date.toIso8601String().split('T')[0]}');
  } catch (e) {
    appLogger.e('Failed to record habit completion: $e');
    rethrow; // Rethrow to propagate the error
  }
}

// Function to record the completion status for multiple habits at once
Future<void> bulkRecordHabitCompletions(Map<String, bool> habitStatuses, DateTime date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  if (habitStatuses.isEmpty) return;

  // Format the date as YYYY-MM-DD
  final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  try {
    // Get the local habit history storage
    final historyStorage = ProviderContainer().read(habitHistoryStorageServiceProvider);
    
    // Save to local storage first
    await historyStorage.saveHabitHistory(user.uid, dateString, habitStatuses);
    
    // Try to update Firebase if online
    final isOnline = await ProviderContainer().read(connectivityServiceProvider).isConnected();
    if (isOnline) {
      // Reference to the document for this date
      final docRef = FirebaseFirestore.instance
          .collection('habitHistory')
          .doc(user.uid)
          .collection('dates')
          .doc(dateString);

      // Use set with merge option to update or create the document
      await docRef.set(habitStatuses, SetOptions(merge: true));
      appLogger.i('Recorded ${habitStatuses.length} habit completions in Firebase for $dateString');
    } else {
      appLogger.i('Recorded ${habitStatuses.length} habit completions locally for $dateString (will sync later)');
    }
  } catch (e) {
    appLogger.e('Failed to record habit completions: $e');
    rethrow;
  }
}