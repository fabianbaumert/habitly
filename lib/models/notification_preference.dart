import 'package:flutter/material.dart';

// Model to represent user notification preferences
class NotificationPreference {
  final bool enableNotifications;

  NotificationPreference({
    this.enableNotifications = true,
  });

  // Create a copy with modified properties
  NotificationPreference copyWith({
    bool? enableNotifications,
  }) {
    return NotificationPreference(
      enableNotifications: enableNotifications ?? this.enableNotifications,
    );
  }

  // Convert to a map for storage in Hive or Firestore
  Map<String, dynamic> toMap() {
    return {
      'enableNotifications': enableNotifications,
    };
  }

  // Create from a map (from Hive or Firestore)
  factory NotificationPreference.fromMap(Map<String, dynamic> map) {
    return NotificationPreference(
      enableNotifications: map['enableNotifications'] ?? true,
    );
  }
}