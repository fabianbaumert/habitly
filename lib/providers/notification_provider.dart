import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/notification_preference.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:hive/hive.dart';

// Notification preferences state notifier for managing user notification settings
class NotificationPreferenceNotifier extends StateNotifier<NotificationPreference> {
  final Ref ref;
  
  // Initialize with default preferences
  NotificationPreferenceNotifier(this.ref) 
      : super(NotificationPreference(
          enableNotifications: true,
        )) {
    _loadPreferences();
  }

  // Load saved preferences from Hive and sync with Firestore if user is logged in
  Future<void> _loadPreferences() async {
    try {
      // Load local preferences first
      final box = await Hive.openBox('preferences');
      final localPrefs = box.get('notificationPreferences');
      
      if (localPrefs != null) {
        state = NotificationPreference.fromMap(
          Map<String, dynamic>.from(localPrefs)
        );
      }
      
      // Then check if there are preferences in Firestore for the current user
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('userPreferences')
            .doc(user.uid)
            .get();
            
        if (doc.exists && doc.data()!.containsKey('notifications')) {
          state = NotificationPreference.fromMap(
            Map<String, dynamic>.from(doc.data()!['notifications'])
          );
          
          // Update local storage with cloud data
          await box.put('notificationPreferences', doc.data()!['notifications']);
        } else {
          // If no cloud data exists, save the current state to Firestore
          await _saveToFirestore();
        }
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
      // Keep default preferences if there's an error
    }
  }

  // Save preferences to both Hive and Firestore
  Future<void> _savePreferences() async {
    final user = ref.read(authStateProvider).value;
    
    try {
      // Always save to local storage
      final box = await Hive.openBox('preferences');
      await box.put('notificationPreferences', state.toMap());
      
      // Save to Firestore if user is logged in
      if (user != null) {
        await _saveToFirestore();
      }
    } catch (e) {
      print('Error saving notification preferences: $e');
    }
  }
  
  // Helper to save to Firestore
  Future<void> _saveToFirestore() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    
    await FirebaseFirestore.instance
        .collection('userPreferences')
        .doc(user.uid)
        .set({
          'notifications': state.toMap(),
        }, SetOptions(merge: true));
  }

  // Update enable notifications setting
  Future<void> setEnableNotifications(bool enable) async {
    state = state.copyWith(enableNotifications: enable);
    await _savePreferences();
  }
}

// Provider for notification preferences state management
final notificationPreferencesProvider = StateNotifierProvider<NotificationPreferenceNotifier, NotificationPreference>((ref) {
  return NotificationPreferenceNotifier(ref);
});