import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    
    appLogger.i('Initializing notification service...');

    // Initialize notification settings
    const AndroidInitializationSettings androidInitialize = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSInitialize = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iOSInitialize,
    );

    // Initialize plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        appLogger.i('Notification clicked: ${details.payload}');
      },
    );

    _isInitialized = true;
    appLogger.i('Notification service initialized');
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    appLogger.i('Requesting notification permissions...');
    
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    final IOSFlutterLocalNotificationsPlugin? iOSPlugin = 
        _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    bool permissionsGranted = false;

    // Request permissions based on platform
    if (androidPlugin != null) {
      permissionsGranted = await androidPlugin.requestNotificationsPermission() ?? false;
    }
    
    if (iOSPlugin != null) {
      permissionsGranted = await iOSPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }

    appLogger.i('Notification permissions granted: $permissionsGranted');
    return permissionsGranted;
  }

  // Schedule notification for a habit
  Future<void> scheduleHabitReminder(Habit habit) async {
    if (!_isInitialized) await initialize();
    
    // If no reminder time set, don't schedule anything
    if (habit.reminderTime == null) {
      appLogger.i('No reminder time set for habit: ${habit.name}');
      return;
    }

    // Cancel any existing notification for this habit
    await cancelNotification(habit.id);
    
    final timeStr = '${habit.reminderTime!.hour}:${habit.reminderTime!.minute.toString().padLeft(2, '0')}';
    appLogger.i('Scheduling notification for habit: ${habit.name} at $timeStr');

    // Define notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders for your habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // Calculate when to show the notification (daily at the specified time)
    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      habit.reminderTime!.hour,
      habit.reminderTime!.minute,
    );
    
    // If the time has passed today, schedule for tomorrow
    final effectiveDate = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;
    
    final tzScheduleTime = tz.TZDateTime.from(effectiveDate, tz.local);

    // Get the title and body for notification
    String title = 'Time for: ${habit.name}';
    String body = habit.dailyGoal != null && habit.dailyGoal!.isNotEmpty 
        ? 'Goal: ${habit.dailyGoal}'
        : 'Don\'t forget your daily habit!';

    try {
      // Schedule the notification to repeat daily
      await _notificationsPlugin.zonedSchedule(
        habit.id.hashCode,  // Use hash of id as notification id
        title,
        body,
        tzScheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat at same time daily
        payload: habit.id, // Store habit id as payload
      );
      
      appLogger.i('Notification scheduled successfully for habit: ${habit.name}');
    } catch (e) {
      appLogger.e('Failed to schedule notification: $e');
      rethrow;
    }
  }

  // Cancel a notification for a habit
  Future<void> cancelNotification(String habitId) async {
    if (!_isInitialized) await initialize();
    
    try {
      await _notificationsPlugin.cancel(habitId.hashCode);
      appLogger.i('Cancelled notification for habit ID: $habitId');
    } catch (e) {
      appLogger.e('Error cancelling notification: $e');
      rethrow;
    }
  }
  
  // Reschedule all habit notifications
  Future<void> rescheduleAllHabitNotifications(List<Habit> habits) async {
    if (!_isInitialized) await initialize();
    
    appLogger.i('Rescheduling all habit notifications');
    
    for (final habit in habits) {
      if (habit.reminderTime != null) {
        await scheduleHabitReminder(habit);
      }
    }
    
    appLogger.i('Finished rescheduling ${habits.where((h) => h.reminderTime != null).length} notifications');
  }
}