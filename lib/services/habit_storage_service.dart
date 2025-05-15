import 'package:hive/hive.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/models/hive_habit.dart';
import 'package:habitly/services/logger_service.dart';

class HabitStorageService {
  static const String _habitsBoxName = 'habits';

  // Initialize Hive for habit storage
  static Future<void> init() async {
    try {
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HiveHabitAdapter());
      }

      // Open the habits box
      await Hive.openBox<HiveHabit>(_habitsBoxName);
      appLogger.i('HabitStorageService initialized');
    } catch (e) {
      appLogger.e('Failed to initialize HabitStorageService: $e');
      rethrow;
    }
  }

  // Get all habits for a user
  Future<List<Habit>> getHabits(String userId) async {
    try {
      final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
      final habits = box.values
          .where((habit) => habit.userId == userId)
          .map((hiveHabit) => hiveHabit.toHabit())
          .toList();
      return habits;
    } catch (e) {
      appLogger.e('Failed to get habits: $e');
      rethrow;
    }
  }

  // Save a habit
  Future<void> saveHabit(Habit habit) async {
    try {
      final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
      final hiveHabit = HiveHabit.fromHabit(habit);
      await box.put(habit.id, hiveHabit);
    } catch (e) {
      appLogger.e('Failed to save habit: $e');
      rethrow;
    }
  }

  // Save multiple habits
  Future<void> saveHabits(List<Habit> habits) async {
    try {
      final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
      final Map<String, HiveHabit> entries = {
        for (final habit in habits) habit.id: HiveHabit.fromHabit(habit)
      };
      await box.putAll(entries);
    } catch (e) {
      appLogger.e('Failed to save multiple habits: $e');
      rethrow;
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId) async {
    try {
      final box = await Hive.openBox<HiveHabit>(_habitsBoxName);
      await box.delete(habitId);
    } catch (e) {
      appLogger.e('Failed to delete habit: $e');
      rethrow;
    }
  }

  // Update a habit
  Future<void> updateHabit(Habit habit) async {
    try {
      await saveHabit(habit);
    } catch (e) {
      appLogger.e('Failed to update habit: $e');
      rethrow;
    }
  }

  // Clear all habits for a user
  Future<void> clearUserHabits(String userId) async {
    try {
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
      appLogger.i('Cleared ${keysToDelete.length} habits for user $userId');
    } catch (e) {
      appLogger.e('Failed to clear user habits: $e');
      rethrow;
    }
  }

  // Reset the entire Hive database (useful for development/testing)
  static Future<void> resetDatabase() async {
    try {
      // Close and delete the habits box
      if (Hive.isBoxOpen(_habitsBoxName)) {
        final box = Hive.box<HiveHabit>(_habitsBoxName);
        await box.clear();  // Clear all records
        await box.close();  // Close the box
      }

      // Delete the box from disk
      await Hive.deleteBoxFromDisk(_habitsBoxName);

      // Reopen the box (empty now)
      await Hive.openBox<HiveHabit>(_habitsBoxName);

      appLogger.i('Hive database reset');
    } catch (e) {
      appLogger.e('Failed to reset Hive database: $e');
      rethrow;
    }
  }
}