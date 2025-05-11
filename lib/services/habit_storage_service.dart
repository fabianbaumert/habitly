import 'package:hive/hive.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/models/hive_habit.dart';
import 'package:flutter/material.dart';

class HabitStorageService {
  static const String _habitsBoxName = 'habits';

  // Initialize Hive for habit storage
  static Future<void> init() async {
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      // Register HiveHabitAdapter when it's generated
      Hive.registerAdapter(HiveHabitAdapter());
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TimeOfDayAdapter());
    }

    // Open the habits box
    await Hive.openBox<HiveHabit>(_habitsBoxName);
  }

  // Get all habits for a user
  Future<List<Habit>> getHabits(String userId) async {
    final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
    
    return box.values
        .where((habit) => habit.userId == userId)
        .map((hiveHabit) => hiveHabit.toHabit())
        .toList();
  }

  // Save a habit
  Future<void> saveHabit(Habit habit) async {
    final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
    final hiveHabit = HiveHabit.fromHabit(habit);
    
    await box.put(habit.id, hiveHabit);
  }

  // Save multiple habits
  Future<void> saveHabits(List<Habit> habits) async {
    final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
    
    final Map<String, HiveHabit> entries = {
      for (final habit in habits) habit.id: HiveHabit.fromHabit(habit)
    };
    
    await box.putAll(entries);
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId) async {
    final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
    await box.delete(habitId);
  }

  // Update a habit
  Future<void> updateHabit(Habit habit) async {
    await saveHabit(habit);
  }

  // Clear all habits for a user
  Future<void> clearUserHabits(String userId) async {
    final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
    
    // Get all keys for habits belonging to this user
    final keysToDelete = box.values
        .where((habit) => habit.userId == userId)
        .map((habit) => habit.id)
        .toList();
    
    // Delete all matching habits
    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }
}