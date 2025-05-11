import 'package:flutter/material.dart';

// Model to represent user notification preferences
class NotificationPreference {
  final bool enableNotifications;
  final bool enableDailyReminders;
  final TimeOfDay? defaultReminderTime;

  NotificationPreference({
    this.enableNotifications = true,
    this.enableDailyReminders = true,
    this.defaultReminderTime,
  });

  // Create a copy with modified properties
  NotificationPreference copyWith({
    bool? enableNotifications,
    bool? enableDailyReminders,
    TimeOfDay? defaultReminderTime,
  }) {
    return NotificationPreference(
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableDailyReminders: enableDailyReminders ?? this.enableDailyReminders,
      defaultReminderTime: defaultReminderTime ?? this.defaultReminderTime,
    );
  }

  // Convert to a map for storage in Hive or Firestore
  Map<String, dynamic> toMap() {
    return {
      'enableNotifications': enableNotifications,
      'enableDailyReminders': enableDailyReminders,
      'defaultReminderTime': defaultReminderTime != null
          ? '${defaultReminderTime!.hour}:${defaultReminderTime!.minute}'
          : null,
    };
  }

  // Create from a map (from Hive or Firestore)
  factory NotificationPreference.fromMap(Map<String, dynamic> map) {
    String? timeString = map['defaultReminderTime'];
    TimeOfDay? reminderTime;

    if (timeString != null) {
      List<String> parts = timeString.split(':');
      reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return NotificationPreference(
      enableNotifications: map['enableNotifications'] ?? true,
      enableDailyReminders: map['enableDailyReminders'] ?? true,
      defaultReminderTime: reminderTime,
    );
  }
}