import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_history_storage_service.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:habitly/services/logger_service.dart';

class SyncService {
  final HabitStorageService _habitStorage;
  final HabitHistoryStorageService _habitHistoryStorage;
  final ConnectivityService _connectivityService;
  StreamSubscription<NetworkStatus>? _networkSubscription;
  
  SyncService(this._habitStorage, this._habitHistoryStorage, this._connectivityService);

  Future<void> initialize() async {
    // Listen to connectivity changes
    _networkSubscription = _connectivityService.status.listen((status) {
      if (status == NetworkStatus.online) {
        // When going back online, sync data with Firebase
        _syncDataWithFirebase();
      }
    });
  }

  // Sync all data with Firebase when connectivity is restored
  Future<void> _syncDataWithFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    appLogger.i('Internet connection restored. Starting data sync with Firebase...');
    
    // First sync habits
    await _syncHabits(user.uid);
    
    // Then sync habit history
    await _syncHabitHistory(user.uid);
    
    appLogger.i('Data sync completed');
  }

  // Sync habits between local storage and Firebase
  Future<void> _syncHabits(String userId) async {
    try {
      appLogger.i('Syncing habits...');
      
      // Get local habits
      final localHabits = await _habitStorage.getHabits(userId);
      Map<String, Habit> localHabitsMap = {for (var h in localHabits) h.id: h};
      
      // Get Firebase habits
      final firebaseHabits = await FirebaseFirestore.instance
          .collection('habits')
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) => 
              snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList());
      
      Map<String, Habit> firebaseHabitsMap = {for (var h in firebaseHabits) h.id: h};
      
      // Create lists for operations
      List<Habit> habitsToUpdate = [];
      List<Habit> habitsToCreate = [];
      List<String> habitsToDelete = [];
      
      // Find habits to update in Firebase (local ones that exist in Firebase)
      for (final habit in localHabits) {
        if (firebaseHabitsMap.containsKey(habit.id)) {
          // Use the most recent version based on timestamp comparison
          final firebaseHabit = firebaseHabitsMap[habit.id]!;
          // No real timestamp to compare, so we'll use isDone as a simple check
          // In a real app, you'd want to use updatedAt timestamps
          if (habit.isDone != firebaseHabit.isDone) {
            // Local change is different, update Firebase
            habitsToUpdate.add(habit);
          }
        } else {
          // Habit exists locally but not in Firebase, create it
          habitsToCreate.add(habit);
        }
      }
      
      // Find habits to create locally (firebase ones missing locally)
      for (final habit in firebaseHabits) {
        if (!localHabitsMap.containsKey(habit.id)) {
          await _habitStorage.saveHabit(habit);
          appLogger.i('Created local habit from Firebase: ${habit.id}');
        }
      }
      
      // Update in Firebase
      for (final habit in habitsToUpdate) {
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(habit.id)
            .update(habit.toMap());
        appLogger.i('Updated Firebase habit: ${habit.id}');
      }
      
      // Create in Firebase
      for (final habit in habitsToCreate) {
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(habit.id)
            .set(habit.toMap());
        appLogger.i('Created Firebase habit: ${habit.id}');
      }
      
      appLogger.i('Habit sync completed. Updated: ${habitsToUpdate.length}, Created: ${habitsToCreate.length}');
    } catch (e) {
      appLogger.e('Error syncing habits: $e');
    }
  }

  // Sync habit history between local storage and Firebase
  Future<void> _syncHabitHistory(String userId) async {
    try {
      appLogger.i('Syncing habit history...');
      
      // Get all local habit history
      final localHistory = await _habitHistoryStorage.getAllUserHabitHistory(userId);
      
      // For each date in local history
      for (final dateKey in localHistory.keys) {
        final localData = localHistory[dateKey]!;
        
        // Get corresponding firebase data
        final firebaseSnapshot = await FirebaseFirestore.instance
            .collection('habitHistory')
            .doc(userId)
            .collection('dates')
            .doc(dateKey)
            .get();
            
        if (firebaseSnapshot.exists) {
          // Firebase data exists, merge with preference to local changes
          Map<String, dynamic> firebaseData = firebaseSnapshot.data() ?? {};
          Map<String, bool> mergedData = {};
          
          // Combine all keys from both sources
          Set<String> allKeys = {...localData.keys, ...firebaseData.keys.cast<String>()};
          
          for (String habitId in allKeys) {
            // If habit exists in local data, use that (local changes take precedence)
            if (localData.containsKey(habitId)) {
              mergedData[habitId] = localData[habitId]!;
            } else if (firebaseData.containsKey(habitId)) {
              mergedData[habitId] = firebaseData[habitId] as bool;
            }
          }
          
          // Update Firebase with merged data
          await FirebaseFirestore.instance
              .collection('habitHistory')
              .doc(userId)
              .collection('dates')
              .doc(dateKey)
              .set(mergedData);
              
          // Also update local storage with the full merged data
          await _habitHistoryStorage.saveHabitHistory(userId, dateKey, mergedData);
          
          appLogger.i('Updated habit history for date $dateKey (merged)');
        } else {
          // Firebase data doesn't exist, just upload local data
          await FirebaseFirestore.instance
              .collection('habitHistory')
              .doc(userId)
              .collection('dates')
              .doc(dateKey)
              .set(localData);
              
          appLogger.i('Created Firebase habit history for date $dateKey');
        }
      }
      
      // Now check for Firebase history that doesn't exist locally
      final firebaseDates = await FirebaseFirestore.instance
          .collection('habitHistory')
          .doc(userId)
          .collection('dates')
          .get();
          
      for (final doc in firebaseDates.docs) {
        final dateKey = doc.id;
        
        // If we don't have this date locally, create it
        if (!localHistory.containsKey(dateKey)) {
          final data = doc.data();
          // Convert to typed data
          Map<String, bool> typedData = {};
          data.forEach((key, value) {
            typedData[key] = value as bool;
          });
          
          // Save to local storage
          await _habitHistoryStorage.saveHabitHistory(userId, dateKey, typedData);
          appLogger.i('Downloaded Firebase habit history for date $dateKey');
        }
      }
      
      appLogger.i('Habit history sync completed');
    } catch (e) {
      appLogger.e('Error syncing habit history: $e');
    }
  }

  // Use this when making changes to ensure they persist even when offline
  Future<void> recordHabitCompletion(String habitId, bool completed, DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Format the date as YYYY-MM-DD
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    try {
      // First get existing history for this date
      Map<String, bool> historyData = await _habitHistoryStorage.getHabitHistory(user.uid, dateString);
      
      // Update with new status
      historyData[habitId] = completed;
      
      // Save locally
      await _habitHistoryStorage.saveHabitHistory(user.uid, dateString, historyData);
      
      // Try to update Firebase if online
      if (await _connectivityService.isConnected()) {
        await FirebaseFirestore.instance
            .collection('habitHistory')
            .doc(user.uid)
            .collection('dates')
            .doc(dateString)
            .set({habitId: completed}, SetOptions(merge: true));
            
        appLogger.i('Updated habit completion in Firebase: $habitId=$completed for $dateString');
      } else {
        appLogger.i('Saved habit completion offline: $habitId=$completed for $dateString (will sync later)');
      }
    } catch (e) {
      appLogger.e('Error recording habit completion: $e');
      throw Exception('Failed to record habit completion status');
    }
  }

  void dispose() {
    _networkSubscription?.cancel();
  }
}

// Provider for the HabitHistoryStorageService
final habitHistoryStorageServiceProvider = Provider<HabitHistoryStorageService>((ref) {
  return HabitHistoryStorageService();
});

// Provider for the SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final habitStorage = ref.watch(Provider<HabitStorageService>((ref) => HabitStorageService()));
  final habitHistoryStorage = ref.watch(habitHistoryStorageServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  
  final syncService = SyncService(habitStorage, habitHistoryStorage, connectivityService);
  
  // Initialize the service
  syncService.initialize();
  
  // Clean up on dispose
  ref.onDispose(() {
    syncService.dispose();
  });
  
  return syncService;
});
