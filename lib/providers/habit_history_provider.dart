import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_history_storage_service.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/sync_service.dart';

// Provider for habit history (completion by date)
final habitHistoryProvider = FutureProvider.family<Map<String, bool>, DateTime>((ref, date) async {
  print('[habitHistoryProvider] called for date: ${date.toIso8601String()}');
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('[habitHistoryProvider] No user logged in');
    return {};
  }
  
  // Format the date as YYYY-MM-DD for storage
  final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  print('[habitHistoryProvider] dateString: ${dateString}');
  
  try {
    // Get the local habit history storage
    final historyStorage = ref.read(habitHistoryStorageServiceProvider);
    print('[habitHistoryProvider] got historyStorage');
    
    // First check local storage
    final localData = await historyStorage.getHabitHistory(user.uid, dateString);
    print('[habitHistoryProvider] localData: keys=${localData.keys.toList()}');
    
    // Check if online and we should check for newer data
    final isOnline = ref.read(isOnlineProvider);
    print('[habitHistoryProvider] isOnline=${isOnline}');
    
    if (isOnline) {
      try {
        // Try to get data from Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection('habitHistory')
            .doc(user.uid)
            .collection('dates')
            .doc(dateString)
            .get();
        print('[habitHistoryProvider] Firestore snapshot.exists=${snapshot.exists}');
            
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          // Convert from Map<String, dynamic> to Map<String, bool>
          final Map<String, bool> firebaseData = Map.from(data.map(
            (key, value) => MapEntry(key, value as bool)
          ));
          print('[habitHistoryProvider] firebaseData: keys=${firebaseData.keys.toList()}');
          
          // Merge, preferring local changes over remote when both exist
          Map<String, bool> mergedData = {...firebaseData, ...localData};
          
          // If there are differences, update local storage
          if (firebaseData.length != localData.length || 
              !firebaseData.keys.every((key) => 
                localData.containsKey(key) && localData[key] == firebaseData[key])) {
            await historyStorage.saveHabitHistory(user.uid, dateString, mergedData);
            print('[habitHistoryProvider] Merged and saved to local storage');
          }
          
          return mergedData;
        }
      } catch (e) {
        print('[habitHistoryProvider] Error accessing Firestore: ${e.toString()}');
        appLogger.w('Error accessing Firestore for habit history: $e');
        // Fallback to local data only
      }
    }
    
    // Return local data if online fetch failed or we're offline
    print('[habitHistoryProvider] Returning localData');
    return localData;
  } catch (e) {
    print('[habitHistoryProvider] Error: ${e.toString()}');
    appLogger.e('Error fetching habit history: $e');
    return {}; // Return empty map on error
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