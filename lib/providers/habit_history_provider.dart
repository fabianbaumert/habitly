import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/services/logger_service.dart';

// Provider for habit history (completion by date)
final habitHistoryProvider = FutureProvider.family<Map<String, bool>, DateTime>((ref, date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  
  // Format the date as YYYY-MM-DD for storage
  final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  
  try {
    // Get the habit completion status for this specific date
    final snapshot = await FirebaseFirestore.instance
        .collection('habitHistory')
        .doc(user.uid)
        .collection('dates')
        .doc(dateString)
        .get();
        
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data() as Map<String, dynamic>;
      // Convert from Map<String, dynamic> to Map<String, bool>
      final Map<String, bool> typedData = Map.from(data.map(
        (key, value) => MapEntry(key, value as bool)
      ));
      return typedData;
    }
    
    return {};
  } catch (e) {
    appLogger.e('Error fetching habit history: $e');
    return {}; // Return empty map on error
  }
});

// Provider to get completion rate for a specific date
final completionRateProvider = FutureProvider.family<double, DateTime>((ref, date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0.0;

  try {
    // Get all habits that existed on this date
    final habitsOnDate = await FirebaseFirestore.instance
        .collection('habits')
        .where('userId', isEqualTo: user.uid)
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(date))
        .get();
        
    if (habitsOnDate.docs.isEmpty) return 0.0;

    // Get the completion status for this date
    final historyData = await ref.watch(habitHistoryProvider(date).future);

    // Count completed habits
    int completedHabits = 0;
    for (final doc in habitsOnDate.docs) {
      final habitId = doc.id;
      if (historyData[habitId] == true) {
        completedHabits++;
      }
    }

    return completedHabits / habitsOnDate.docs.length;
  } catch (e) {
    appLogger.e('Error calculating completion rate: $e');
    return 0.0;
  }
});

// Provider to check if all habits were completed on a specific date
final allHabitsCompletedProvider = FutureProvider.family<bool, DateTime>((ref, date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  
  try {
    // Get all habits that existed on this date
    final habitsOnDate = await FirebaseFirestore.instance
        .collection('habits')
        .where('userId', isEqualTo: user.uid)
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(date))
        .get();
        
    if (habitsOnDate.docs.isEmpty) return false;

    // Get the completion status for this date
    final historyData = await ref.watch(habitHistoryProvider(date).future);
    if (historyData.isEmpty) return false;

    // Check if all habits were completed
    for (final doc in habitsOnDate.docs) {
      final habitId = doc.id;
      if (historyData[habitId] != true) {
        return false; // At least one habit was not completed
      }
    }
    
    return true; // All habits were completed
  } catch (e) {
    appLogger.e('Error checking habit completion: $e');
    return false;
  }
});

// Function to record habit completion for a specific date
Future<void> recordHabitCompletion(String habitId, bool completed, DateTime date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Format the date as YYYY-MM-DD
  final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  try {
    // Reference to the document for this date
    final docRef = FirebaseFirestore.instance
        .collection('habitHistory')
        .doc(user.uid)
        .collection('dates')
        .doc(dateString);

    // Update the habit completion status using a transaction to handle concurrent updates
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        transaction.set(docRef, {habitId: completed});
      } else {
        transaction.update(docRef, {habitId: completed});
      }
    });
    
    appLogger.i('Recorded habit $habitId as ${completed ? "completed" : "uncompleted"} for $dateString');
  } catch (e) {
    appLogger.e('Failed to record habit completion: $e');
    throw e; // Rethrow to propagate the error
  }
}

// Function to record the completion status for multiple habits at once
Future<void> bulkRecordHabitCompletions(Map<String, bool> habitStatuses, DateTime date) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  if (habitStatuses.isEmpty) return;

  // Format the date as YYYY-MM-DD
  final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  try {
    // Reference to the document for this date
    final docRef = FirebaseFirestore.instance
        .collection('habitHistory')
        .doc(user.uid)
        .collection('dates')
        .doc(dateString);

    // Use set with merge option to update or create the document
    await docRef.set(habitStatuses, SetOptions(merge: true));
    
    appLogger.i('Recorded ${habitStatuses.length} habit completions for $dateString');
  } catch (e) {
    appLogger.e('Failed to record habit completions: $e');
    throw e;
  }
}