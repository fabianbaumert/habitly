import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

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

  // Load habits for the given user
  void _loadHabits(User user) {
    ref.read(habitsCollectionProvider)
        .where('userId', isEqualTo: user.uid)
        .get()
        .then((snapshot) {
      state = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
    });
  }

  // Add a new habit
  Future<void> addHabit(String name, {String? dailyGoal, TimeOfDay? reminderTime}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

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

    // Add to Firestore
    await ref.read(habitsCollectionProvider).doc(id).set(habit.toMap());
    
    // Update local state
    state = [...state, habit];
  }

  // Update an existing habit
  Future<void> updateHabit(Habit habit) async {
    await ref.read(habitsCollectionProvider).doc(habit.id).update(habit.toMap());
    
    // Update local state
    state = [
      for (final item in state)
        if (item.id == habit.id) habit else item
    ];
  }

  // Delete a habit
  Future<void> deleteHabit(String id) async {
    await ref.read(habitsCollectionProvider).doc(id).delete();
    
    // Update local state
    state = state.where((habit) => habit.id != id).toList();
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