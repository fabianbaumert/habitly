import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
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
  }
}