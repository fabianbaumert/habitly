import 'package:hive/hive.dart';
import 'package:habitly/services/logger_service.dart';

class HabitHistoryStorageService {
  static const String _habitHistoryBoxName = 'habit_history';

  // Initialize habit history storage
  static Future<void> init() async {
    try {
      // Open the habit history box
      await Hive.openBox<Map>(_habitHistoryBoxName);
      appLogger.i('HabitHistoryStorageService initialized');
    } catch (e) {
      appLogger.e('Failed to initialize HabitHistoryStorageService: $e');
      rethrow;
    }
  }

  // Save habit completion status for a date
  Future<void> saveHabitHistory(String userId, String dateKey, Map<String, bool> habitStatus) async {
    try {
      final box = await Hive.openBox<Map>(_habitHistoryBoxName);
      final key = '${userId}_$dateKey';
      await box.put(key, habitStatus);
      appLogger.i('Saved habit history for $dateKey, key=$key');
    } catch (e) {
      appLogger.e('Failed to save habit history: $e');
      rethrow;
    }
  }

  // Get habit completion status for a date
  Future<Map<String, bool>> getHabitHistory(String userId, String dateKey) async {
    try {
      final box = await Hive.openBox<Map>(_habitHistoryBoxName);
      final key = '${userId}_$dateKey';
      final data = box.get(key);
      
      if (data != null) {
        // Convert from generic Map to Map<String, bool>
        final Map<String, bool> typedData = Map.from(data.map(
          (key, value) => MapEntry(key.toString(), value as bool)
        ));
        return typedData;
      }
      
      return {};
    } catch (e) {
      appLogger.e('Failed to get habit history: $e');
      return {};
    }
  }

  // Get all habit history entries for a user
  Future<Map<String, Map<String, bool>>> getAllUserHabitHistory(String userId) async {
    try {
      final box = await Hive.openBox<Map>(_habitHistoryBoxName);
      final Map<String, Map<String, bool>> result = {};
      
      // Filter keys by userId prefix and extract the date part
      for (final key in box.keys) {
        final keyStr = key.toString();
        if (keyStr.startsWith('${userId}_')) {
          final dateKey = keyStr.substring(userId.length + 1); // +1 for the underscore
          final data = box.get(key);
          
          if (data != null) {
            // Convert from generic Map to Map<String, bool>
            final Map<String, bool> typedData = Map.from(data.map(
              (key, value) => MapEntry(key.toString(), value as bool)
            ));
            result[dateKey] = typedData;
          }
        }
      }
      
      return result;
    } catch (e) {
      appLogger.e('Failed to get all habit history: $e');
      return {};
    }
  }

  // Delete habit history for a specific day
  Future<void> deleteHabitHistory(String userId, String dateKey) async {
    try {
      final box = await Hive.openBox<Map>(_habitHistoryBoxName);
      final key = '${userId}_$dateKey';
      await box.delete(key);
    } catch (e) {
      appLogger.e('Failed to delete habit history: $e');
      rethrow;
    }
  }

  // Clear all habit history for a user
  Future<void> clearUserHabitHistory(String userId) async {
    try {
      final box = await Hive.openBox<Map>(_habitHistoryBoxName);
      
      // Get all keys for habit history belonging to this user
      final keysToDelete = box.keys.where(
        (key) => key.toString().startsWith('${userId}_')
      ).toList();
      
      // Delete all matching habit history
      for (final key in keysToDelete) {
        await box.delete(key);
      }
      
      appLogger.i('Cleared ${keysToDelete.length} habit history entries for user $userId');
    } catch (e) {
      appLogger.e('Failed to clear user habit history: $e');
      rethrow;
    }
  }

  // Reset the habit history database
  static Future<void> resetDatabase() async {
    try {
      // Close and delete the history box
      if (Hive.isBoxOpen(_habitHistoryBoxName)) {
        final box = Hive.box<Map>(_habitHistoryBoxName);
        await box.clear();  // Clear all records
        await box.close();  // Close the box
      }
      
      // Delete the box from disk
      await Hive.deleteBoxFromDisk(_habitHistoryBoxName);
      
      // Reopen the box (empty now)
      await Hive.openBox<Map>(_habitHistoryBoxName);
      
      appLogger.i('Habit history database reset');
    } catch (e) {
      appLogger.e('Failed to reset habit history database: $e');
      rethrow;
    }
  }
}
