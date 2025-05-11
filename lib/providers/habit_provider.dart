import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/services/habit_storage_service.dart';
import 'package:uuid/uuid.dart';

// Provider for the habit storage service
final habitStorageServiceProvider = Provider<HabitStorageService>((ref) {
  return HabitStorageService();
});

// Provider for the habits collection reference in Firestore
final habitsCollectionProvider = Provider<CollectionReference>((ref) {
  return FirebaseFirestore.instance.collection('habits');
});

// Provider that returns the current user's habits stream from Firestore
final userHabitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  final user = ref.watch(authStateProvider).value;
  
  // If no user is authenticated, return an empty list
  if (user == null) {
    return Stream.value([]);
  }
  
  // Query habits for the current user
  return FirebaseFirestore.instance
      .collection('habits')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => 
          snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList());
});

// StateNotifierProvider to handle habit CRUD operations
class HabitNotifier extends StateNotifier<List<Habit>> {
  final Ref ref;
  
  HabitNotifier(this.ref) : super([]) {
    // Initialize with data if a user is logged in
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _loadHabits(user);
    }
  }

  // Load habits for the given user from both Firestore and local storage
  Future<void> _loadHabits(User user) async {
    try {
      // First try to load from local storage for immediate results
      final storageService = ref.read(habitStorageServiceProvider);
      final localHabits = await storageService.getHabits(user.uid);
      
      if (localHabits.isNotEmpty) {
        state = localHabits;
      }
      
      // Then try to get the latest data from Firestore
      final snapshot = await ref.read(habitsCollectionProvider)
          .where('userId', isEqualTo: user.uid)
          .get();
          
      final firebaseHabits = snapshot.docs
          .map((doc) => Habit.fromFirestore(doc))
          .toList();
      
      // Update state with Firebase data
      state = firebaseHabits;
      
      // Sync local storage with Firestore data
      await storageService.saveHabits(firebaseHabits);
    } catch (e) {
      print('Error loading habits: $e');
      // If there's an error with Firestore, we'll use whatever we have in local storage
    }
  }

  // Add a new habit
  Future<void> addHabit(String name, {String? dailyGoal, TimeOfDay? reminderTime}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      print('No authenticated user found. Cannot add habit.');
      return;
    }

    print('Creating habit "$name" for user ${user.uid}');
    
    final id = const Uuid().v4();
    final habit = Habit(
      id: id,
      name: name,
      dailyGoal: dailyGoal,
      reminderTime: reminderTime,
      isDone: false,
      createdAt: DateTime.now(),
      userId: user.uid,
    );

    try {
      // Add to Firestore
      print('Attempting to save habit to Firestore...');
      await ref.read(habitsCollectionProvider).doc(id).set(habit.toMap());
      print('Successfully saved habit to Firestore');
      
      // Add to local storage
      print('Saving habit to local storage...');
      await ref.read(habitStorageServiceProvider).saveHabit(habit);
      print('Successfully saved habit to local storage');
      
      // Update local state
      state = [...state, habit];
      print('Habit creation complete: ${habit.id}');
    } catch (e, stackTrace) {
      print('Error adding habit to Firestore: $e');
      print('Stack trace: $stackTrace');
      // If there's an error with Firestore, at least add it locally
      try {
        await ref.read(habitStorageServiceProvider).saveHabit(habit);
        state = [...state, habit];
      } catch (localError) {
        print('Error saving habit locally: $localError');
        throw localError;
      }
    }
  }

  // Update an existing habit
  Future<void> updateHabit(Habit habit) async {
    try {
      // Update in Firestore
      await ref.read(habitsCollectionProvider).doc(habit.id).update(habit.toMap());
      
      // Update in local storage
      await ref.read(habitStorageServiceProvider).updateHabit(habit);
      
      // Update local state
      state = [
        for (final item in state)
          if (item.id == habit.id) habit else item
      ];
    } catch (e) {
      print('Error updating habit in Firestore: $e');
      // If there's an error with Firestore, at least update it locally
      try {
        await ref.read(habitStorageServiceProvider).updateHabit(habit);
        state = [
          for (final item in state)
            if (item.id == habit.id) habit else item
        ];
      } catch (localError) {
        print('Error updating habit locally: $localError');
        throw localError;
      }
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String id) async {
    try {
      // Delete from Firestore
      await ref.read(habitsCollectionProvider).doc(id).delete();
      
      // Delete from local storage
      await ref.read(habitStorageServiceProvider).deleteHabit(id);
      
      // Update local state
      state = state.where((habit) => habit.id != id).toList();
    } catch (e) {
      print('Error deleting habit: $e');
      // If there's an error with Firestore, at least delete it locally
      try {
        await ref.read(habitStorageServiceProvider).deleteHabit(id);
        state = state.where((habit) => habit.id != id).toList();
      } catch (localError) {
        print('Error deleting habit locally: $localError');
        throw localError;
      }
    }
  }

  // Toggle the completion status of a habit
  Future<void> toggleHabitCompletion(String id) async {
    final habit = state.firstWhere((h) => h.id == id);
    final updatedHabit = habit.copyWith(isDone: !habit.isDone);
    
    await updateHabit(updatedHabit);
  }
}

// Provider for habit state management
final habitProvider = StateNotifierProvider<HabitNotifier, List<Habit>>((ref) {
  return HabitNotifier(ref);
});