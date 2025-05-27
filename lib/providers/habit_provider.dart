import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/sync_service.dart';

// Provider for the habit storage service
final habitStorageServiceProvider = Provider<HabitStorageService>((ref) {
  return HabitStorageService();
});

// Provider to stream habits from Firestore
final firestoreHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }
  
  return FirebaseFirestore.instance
    .collection('habits')
    .where('userId', isEqualTo: user.uid)
    .snapshots()
    .map((snapshot) {
      final habits = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
      return habits;
    });
});

// Provider to get habits from local storage
final localHabitsProvider = FutureProvider<List<Habit>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  final habitStorage = ref.watch(habitStorageServiceProvider);
  if (user == null) {
    return [];
  }
  
  return await habitStorage.getHabits(user.uid);
});

// Combined provider that prioritizes local data but keeps in sync with Firestore
final habitsProvider = StateNotifierProvider<HabitsNotifier, AsyncValue<List<Habit>>>((ref) {
  final habitStorage = ref.watch(habitStorageServiceProvider);
  return HabitsNotifier(habitStorage, ref);
});

class HabitsNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final HabitStorageService _habitStorage;
  final Ref _ref;
  String? _currentUserId;
  
  HabitsNotifier(this._habitStorage, this._ref) : super(const AsyncValue.loading()) {
    _init();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Listen to auth state changes
    _ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        final newUserId = user?.uid;
        
        // If user changed (logged out or switched users), clear local data and reinitialize
        if (_currentUserId != newUserId) {
          _currentUserId = newUserId;
          _handleUserChange(newUserId);
        }
      });
    });
  }

  Future<void> _handleUserChange(String? newUserId) async {
    // If we had a previous user, explicitly clear their habits from local storage
    String? previousUserId = newUserId == null ? _currentUserId : null;
    if (previousUserId != null) {
      // Clean up previous user's data from local storage
      await _habitStorage.clearUserHabits(previousUserId);
      appLogger.i('Cleared local habits for previous user: $previousUserId');
      
      // Also clear habit history for previous user from Hive
      try {
        // Use the sync service which already has a reference to habit history storage
        final syncService = _ref.read(syncServiceProvider);
        await syncService.clearUserData(previousUserId);
        appLogger.i('Cleared local habit history for previous user: $previousUserId');
      } catch (e) {
        appLogger.e('Error clearing local habit history: $e');
      }
      
      // Also update the currentUserIdProvider to force other providers to update
      _ref.read(currentUserIdProvider.notifier).state = newUserId;
    }
    
    if (newUserId == null) {
      // User logged out, clear state
      state = const AsyncValue.data([]);
      appLogger.i('User logged out, cleared habits state');
    } else {
      // User logged in or switched, load new user's data
      appLogger.i('User changed to: $newUserId, reloading data');
      
      // Clear state first
      state = const AsyncValue.loading();
      
      // Reinitialize for new user
      await _init();
    }
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    
    _currentUserId = user.uid;
    
    // Start with local data
    try {
      final localHabits = await _habitStorage.getHabits(user.uid);
      state = AsyncValue.data(localHabits);
      appLogger.i('Loaded ${localHabits.length} habits from local storage');
      
      // Listen to Firestore updates
      _ref.listen(firestoreHabitsProvider, (previous, next) {
        next.whenData((firestoreHabits) {
          // If we have new data from Firestore, update local storage and state
          if (firestoreHabits.isNotEmpty) {
            _syncWithFirestore(firestoreHabits);
          }
        });
      });
    } catch (e) {
      appLogger.e('Error initializing habits: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Sync Firestore habits to local storage
  Future<void> _syncWithFirestore(List<Habit> firestoreHabits) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update local storage with Firestore data
      await _habitStorage.saveHabits(firestoreHabits);
      
      // Update state with the latest data
      final updatedHabits = await _habitStorage.getHabits(user.uid);
      state = AsyncValue.data(updatedHabits);
    } catch (e) {
      appLogger.e('Error syncing with Firestore: $e');
    }
  }

  // Add a new habit
  Future<void> addHabit(Habit habit) async {
    try {
      appLogger.i('[HabitsNotifier] addHabit: Saving habit id=${habit.id}, name=${habit.name}');
      // Save to local storage first
      await _habitStorage.saveHabit(habit);
      appLogger.i('[HabitsNotifier] addHabit: Saved to local storage');
      // Update state
      state.whenData((habits) {
        state = AsyncValue.data([...habits, habit]);
        appLogger.i('[HabitsNotifier] addHabit: State updated, count=${habits.length + 1}');
      });
      // Check connectivity before trying to sync with Firestore
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.isConnected();
      if (isOnline) {
        // Sync with Firestore if online
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(habit.id)
            .set(habit.toMap());
        appLogger.i('Added habit to Firebase: ${habit.name} (${habit.id})');
      } else {
        appLogger.i('Added habit locally (offline): ${habit.name} (${habit.id}) - will sync when online');
      }
      connectivityService.dispose();
    } catch (e) {
      appLogger.e('Error adding habit: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Update a habit
  Future<void> updateHabit(Habit habit) async {
    try {
      // Update local storage first
      await _habitStorage.updateHabit(habit);
      
      // Update state
      state.whenData((habits) {
        final updatedHabits = habits.map((h) =>
          h.id == habit.id ? habit : h).toList();
        state = AsyncValue.data(updatedHabits);
      });
      
      // Check connectivity before trying to sync with Firestore
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.isConnected();
      
      if (isOnline) {
        // Sync with Firestore if online
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(habit.id)
            .update(habit.toMap());
        appLogger.i('Updated habit in Firebase: ${habit.name} (${habit.id})');
      } else {
        appLogger.i('Updated habit locally (offline): ${habit.name} (${habit.id}) - will sync when online');
      }
      
      connectivityService.dispose();
    } catch (e) {
      appLogger.e('Error updating habit: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId) async {
    try {
      // Delete from local storage first
      await _habitStorage.deleteHabit(habitId);
      
      // Update state
      state.whenData((habits) {
        final updatedHabits = habits.where((h) => h.id != habitId).toList();
        state = AsyncValue.data(updatedHabits);
      });
      
      // Check connectivity before trying to sync with Firestore
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.isConnected();
      
      if (isOnline) {
        // Delete from Firestore if online
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(habitId)
            .delete();
        appLogger.i('Deleted habit from Firebase: $habitId');
      } else {
        appLogger.i('Deleted habit locally (offline): $habitId - will sync when online');
        // Note: We'll need special handling during sync since the habit is already deleted locally
        // This is a limitation of our simple implementation
      }
      
      connectivityService.dispose();
    } catch (e) {
      appLogger.e('Error deleting habit: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Toggle the completion state of a habit
  Future<void> toggleHabitCompletion(Habit habit) async {
    try {
      final now = DateTime.now();
      // Get the current completion status for today
      final habitHistoryAsync = await _ref.read(habitHistoryProvider(now).future);
      final currentStatus = habitHistoryAsync[habit.id] == true;
      final newStatus = !currentStatus;
      
      // Record completion in habit history
      await recordHabitCompletion(habit.id, newStatus, now);
      
      // Also update the habit's lastCompletedDate for redundancy
      if (newStatus) {
        // Set lastCompletedDate to today if completing
        final updatedHabit = habit.copyWith(lastCompletedDate: now);
        await updateHabit(updatedHabit);
        appLogger.i('Updated lastCompletedDate for habit ${habit.id} to ${now.toIso8601String().split('T')[0]}');
      } else if (habit.lastCompletedDate != null) {
        // If we're un-completing and the lastCompletedDate is today, clear it
        final today = DateTime(now.year, now.month, now.day);
        final lastCompleted = DateTime(
          habit.lastCompletedDate!.year,
          habit.lastCompletedDate!.month,
          habit.lastCompletedDate!.day
        );
        
        if (today.isAtSameMomentAs(lastCompleted)) {
          final updatedHabit = habit.copyWith(lastCompletedDate: null);
          await updateHabit(updatedHabit);
          appLogger.i('Cleared lastCompletedDate for habit ${habit.id}');
        }
      }
    } catch (e) {
      appLogger.e('Error toggling habit completion: $e');
    }
  }

  // Mark habit as complete for a specific date (used from calendar)
  Future<void> toggleHabitCompletionForDate(Habit habit, DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Get the current status first
      Map<String, bool> currentStatus = {};
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('habitHistory')
            .doc(user.uid)
            .collection('dates')
            .doc(dateString)
            .get();
            
        if (docSnapshot.exists) {
          currentStatus = Map<String, bool>.from(docSnapshot.data() ?? {});
        }
      } catch (e) {
        appLogger.w('Error checking habit status: $e');
      }
      
      // Toggle the current status (or default to true if not set)
      final newStatus = !(currentStatus[habit.id] ?? false);
      final update = {habit.id: newStatus};
      
      // Update the habit completion status directly with a single write operation
      await FirebaseFirestore.instance
          .collection('habitHistory')
          .doc(user.uid)
          .collection('dates')
          .doc(dateString)
          .set(update, SetOptions(merge: true));
          
      appLogger.i('Set habit ${habit.name} to ${newStatus ? "completed" : "uncompleted"} for $dateString');
    } catch (e) {
      appLogger.e('Error toggling habit completion for date: $e');
      throw Exception('Could not update habit completion. Please try again later.');
    }
  }

  /// Determines if a habit is due on the specified date based on its frequency
  bool isHabitDueOnDate(Habit habit, DateTime date) {
    return habit.isDueOn(date);
  }

  /// Get all habits that are due on a specific date
  List<Habit> getHabitsDueOnDate(DateTime date) {
    List<Habit> dueHabits = [];
    
    state.whenData((habits) {
      dueHabits = habits.where((habit) => isHabitDueOnDate(habit, date)).toList();
    });
    
    return dueHabits;
  }
  
  /// Filter habits by frequency type
  List<Habit> getHabitsByFrequencyType(FrequencyType frequencyType) {
    List<Habit> filteredHabits = [];
    
    state.whenData((habits) {
      filteredHabits = habits.where((habit) => habit.frequencyType == frequencyType).toList();
    });
    
    return filteredHabits;
  }
  
  /// Get habits that repeat on a specific day of the week
  List<Habit> getHabitsForDayOfWeek(int dayOfWeek) {
    List<Habit> filteredHabits = [];
    
    state.whenData((habits) {
      filteredHabits = habits.where((habit) {
        if (habit.frequencyType == FrequencyType.weekly && 
            habit.specificDays != null && 
            habit.specificDays!.any((day) => day.value == dayOfWeek)) {
          return true;
        }
        return false;
      }).toList();
    });
    
    return filteredHabits;
  }

  /// Check if any habits are due today
  bool hasHabitsDueToday() {
    final today = DateTime.now();
    return getHabitsDueOnDate(today).isNotEmpty;
  }

  /// Update a habit with new frequency settings
  Future<void> updateHabitFrequency({
    required String habitId, 
    required FrequencyType frequencyType,
    List<DayOfWeek>? specificDays,
    int? dayOfMonth,
    int? month,
  }) async {
    try {
      Habit? habitToUpdate;
      
      state.whenData((habits) {
        habitToUpdate = habits.firstWhere((h) => h.id == habitId);
      });
      
      if (habitToUpdate != null) {
        final updatedHabit = habitToUpdate!.copyWith(
          frequencyType: frequencyType,
          specificDays: specificDays,
          dayOfMonth: dayOfMonth, 
          month: month,
        );
        
        await updateHabit(updatedHabit);
      }
    } catch (e) {
      appLogger.e('Error updating habit frequency: $e');
      throw Exception('Could not update habit frequency. Please try again later.');
    }
  }
}