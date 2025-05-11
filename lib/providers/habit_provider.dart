import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/services/habit_storage_service.dart';

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
    .map((snapshot) => 
        snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList());
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
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  // Sync Firestore habits to local storage
  Future<void> _syncWithFirestore(List<Habit> firestoreHabits) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Update local storage with Firestore data
    await _habitStorage.saveHabits(firestoreHabits);
    
    // Update state with the latest data
    final updatedHabits = await _habitStorage.getHabits(user.uid);
    state = AsyncValue.data(updatedHabits);
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
      
      // Sync with Firestore
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(habit.id)
          .set(habit.toMap());
    } catch (e) {
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
      
      // Sync with Firestore
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(habit.id)
          .update(habit.toMap());
    } catch (e) {
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
      
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(habitId)
          .delete();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  // Toggle the isDone state of a habit
  Future<void> toggleHabitCompletion(Habit habit) async {
    final updatedHabit = habit.copyWith(isDone: !habit.isDone);
    await updateHabit(updatedHabit);
    
    try {
      // Also record this change in the habit history for today's date
      await recordHabitCompletion(habit.id, updatedHabit.isDone, DateTime.now());
    } catch (e) {
      debugPrint('Error recording habit completion: $e');
      // Continue even if the history recording fails - at least the habit itself was updated
    }
  }
  
  // Mark habit as complete for a specific date (used from calendar)
  Future<void> toggleHabitCompletionForDate(Habit habit, DateTime date) async {
    try {
      // Get the current completion status for this habit on this date
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Create a map with the toggled completion status
      final Map<String, bool> update = {habit.id: true};  // Default to marking as complete
      
      // Check if we need to toggle it off instead (if it's already completed)
      try {
        final docRef = FirebaseFirestore.instance
            .collection('habitHistory')
            .doc(user.uid)
            .collection('dates')
            .doc(dateString);
            
        final snapshot = await docRef.get();
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final currentStatus = data[habit.id] as bool? ?? false;
          update[habit.id] = !currentStatus;
        }
      } catch (e) {
        // If there's an error checking status, continue with default (marking as complete)
        debugPrint('Error checking habit status: $e');
      }
      
      // Update the habit completion status directly with a single write operation
      await FirebaseFirestore.instance
          .collection('habitHistory')
          .doc(user.uid)
          .collection('dates')
          .doc(dateString)
          .set(update, SetOptions(merge: true));
      
      // If the date is today, also update the habit's isDone state
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDate = DateTime(date.year, date.month, date.day);
      
      if (selectedDate.isAtSameMomentAs(today)) {
        await updateHabit(habit.copyWith(isDone: update[habit.id]!));
      }
    } catch (e) {
      debugPrint('Error toggling habit completion for date: $e');
      // Re-throw as a more specific error that can be handled by the UI
      throw Exception('Could not update habit completion. Please try again later.');
    }
  }
}