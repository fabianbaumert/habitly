import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:habitly/services/logger_service.dart';

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
  
  HabitsNotifier(this._habitStorage, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    
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
      // Save to local storage first
      await _habitStorage.saveHabit(habit);
      
      // Update state
      state.whenData((habits) {
        state = AsyncValue.data([...habits, habit]);
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

  // Toggle the isDone state of a habit
  Future<void> toggleHabitCompletion(Habit habit) async {
    try {
      final updatedHabit = habit.copyWith(isDone: !habit.isDone);
      await updateHabit(updatedHabit);
      
      // Also record this change in the habit history for today's date
      await recordHabitCompletion(habit.id, updatedHabit.isDone, DateTime.now());
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
      
      // If the date is today, also update the habit's isDone state
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDate = DateTime(date.year, date.month, date.day);
      
      if (selectedDate.isAtSameMomentAs(today)) {
        await updateHabit(habit.copyWith(isDone: update[habit.id]!));
      }
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
    int? customInterval,
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
          customInterval: customInterval,
        );
        
        await updateHabit(updatedHabit);
      }
    } catch (e) {
      appLogger.e('Error updating habit frequency: $e');
      throw Exception('Could not update habit frequency. Please try again later.');
    }
  }
}