import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/notification_service.dart';

// Provider for the habit storage service
final habitStorageServiceProvider = Provider<HabitStorageService>((ref) {
  return HabitStorageService();
});

// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
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
  late final NotificationService _notificationService;
  
  HabitsNotifier(this._habitStorage, this._ref) : super(const AsyncValue.loading()) {
    _notificationService = _ref.read(notificationServiceProvider);
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
      
      // Schedule notifications for habits with reminders
      _scheduleAllHabitNotifications(localHabits);
      
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

  // Schedule notifications for all habits with reminder times
  Future<void> _scheduleAllHabitNotifications(List<Habit> habits) async {
    try {
      await _notificationService.rescheduleAllHabitNotifications(habits);
    } catch (e) {
      appLogger.e('Error scheduling all habit notifications: $e');
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
      
      // Reschedule notifications after sync
      await _scheduleAllHabitNotifications(updatedHabits);
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
      
      // Schedule notification if reminder time is set
      if (habit.reminderTime != null) {
        await _notificationService.scheduleHabitReminder(habit);
        final timeStr = '${habit.reminderTime!.hour}:${habit.reminderTime!.minute.toString().padLeft(2, '0')}';
        appLogger.i('Scheduled notification for new habit: ${habit.name} at $timeStr');
      }
      
      // Sync with Firestore
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(habit.id)
          .set(habit.toMap());
          
      appLogger.i('Added habit: ${habit.name} (${habit.id})');
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
      
      // Update notification if reminder time exists
      if (habit.reminderTime != null) {
        await _notificationService.scheduleHabitReminder(habit);
        appLogger.i('Updated notification for habit: ${habit.name}');
      } else {
        // Cancel notification if reminder time was removed
        await _notificationService.cancelNotification(habit.id);
        appLogger.i('Cancelled notification for habit: ${habit.name}');
      }
      
      // Sync with Firestore
      await FirebaseFirestore.instance
          .collection('habits')
          .doc(habit.id)
          .update(habit.toMap());
          
      appLogger.i('Updated habit: ${habit.name} (${habit.id})');
    } catch (e) {
      appLogger.e('Error updating habit: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId) async {
    try {
      // Cancel any notifications for this habit
      await _notificationService.cancelNotification(habitId);
      appLogger.i('Cancelled notification for deleted habit: $habitId');
      
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
          
      appLogger.i('Deleted habit: $habitId');
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
}