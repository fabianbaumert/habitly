import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines the type of frequency for habits
enum FrequencyType {
  daily,
  weekly, // Combined frequency type for all weekly patterns
  monthly,
  yearly,
  custom
}

/// Represents days of the week (starting with Monday = 1 to match DateTime.weekday)
enum DayOfWeek {
  monday(1),
  tuesday(2),
  wednesday(3),
  thursday(4),
  friday(5),
  saturday(6),
  sunday(7);
  
  final int value;
  const DayOfWeek(this.value);
  
  static DayOfWeek fromInt(int value) {
    return DayOfWeek.values.firstWhere((day) => day.value == value);
  }
}

// This class represents a habit with its properties
class Habit {
  String id;
  String name;
  String? description;
  bool isDone;
  DateTime createdAt;
  String userId;
  
  // Frequency related properties
  FrequencyType frequencyType;
  List<DayOfWeek>? specificDays; // For weekly selection (one or more days)
  int? dayOfMonth;       // For monthly frequency (1-31)
  int? month;            // For yearly frequency (1-12)
  int? customInterval;   // For custom interval (every X days)
  DateTime? lastCompletedDate; // To track the last completion

  Habit({
    required this.id,
    required this.name,
    this.description,
    this.isDone = false,
    required this.createdAt,
    required this.userId,
    this.frequencyType = FrequencyType.daily,
    this.specificDays,
    this.dayOfMonth,
    this.month,
    this.customInterval,
    this.lastCompletedDate,
  });

  // Convert Habit to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isDone': isDone,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'frequencyType': frequencyType.name,
      'specificDays': specificDays?.map((day) => day.value).toList(),
      'dayOfMonth': dayOfMonth,
      'month': month,
      'customInterval': customInterval,
      'lastCompletedDate': lastCompletedDate != null ? Timestamp.fromDate(lastCompletedDate!) : null,
    };
  }

  // Create a Habit from a Firestore document
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse frequency type
    FrequencyType frequency = FrequencyType.daily;
    if (data['frequencyType'] != null) {
      frequency = FrequencyType.values.firstWhere(
        (e) => e.name == data['frequencyType'],
        orElse: () => FrequencyType.daily,
      );
    }

    // Parse specific days
    List<DayOfWeek>? specificDays;
    if (data['specificDays'] != null) {
      specificDays = (data['specificDays'] as List)
          .map((day) => DayOfWeek.fromInt(day))
          .toList();
    }

    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      isDone: data['isDone'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      frequencyType: frequency,
      specificDays: specificDays,
      dayOfMonth: data['dayOfMonth'],
      month: data['month'],
      customInterval: data['customInterval'],
      lastCompletedDate: data['lastCompletedDate'] != null 
          ? (data['lastCompletedDate'] as Timestamp).toDate()
          : null,
    );
  }

  // Clone a habit with some modified properties
  Habit copyWith({
    String? id,
    String? name,
    String? description,
    bool? isDone,
    DateTime? createdAt,
    String? userId,
    FrequencyType? frequencyType,
    List<DayOfWeek>? specificDays,
    int? dayOfMonth,
    int? month,
    int? customInterval,
    DateTime? lastCompletedDate,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      frequencyType: frequencyType ?? this.frequencyType,
      specificDays: specificDays ?? this.specificDays,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      month: month ?? this.month,
      customInterval: customInterval ?? this.customInterval,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }
  
  /// Checks if the habit is due on a specific date
  bool isDueOn(DateTime date) {
    // If the habit was completed today, it's not due again
    if (lastCompletedDate != null &&
        lastCompletedDate!.year == date.year &&
        lastCompletedDate!.month == date.month &&
        lastCompletedDate!.day == date.day) {
      return false;
    }
    
    switch (frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.weekly:
        if (specificDays != null && specificDays!.isNotEmpty) {
          // Check if today's weekday is in the specificDays list (one or more days)
          return specificDays!.any((day) => day.value == date.weekday);
        }
        return false;
      case FrequencyType.monthly:
        if (dayOfMonth == null) return false;
        // Handle months with fewer days than the selected day
        final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
        final actualDayOfMonth = dayOfMonth! > lastDayOfMonth ? lastDayOfMonth : dayOfMonth!;
        return date.day == actualDayOfMonth;
      case FrequencyType.yearly:
        if (dayOfMonth == null || month == null) return false;
        return date.day == dayOfMonth && date.month == month;
      case FrequencyType.custom:
        if (customInterval == null || customInterval! <= 0 || lastCompletedDate == null) return true;
        // Calculate days since last completion
        final difference = date.difference(lastCompletedDate!).inDays;
        return difference >= customInterval!;
    }
  }
  
  /// Returns a human-readable description of the habit frequency
  String getFrequencyDescription() {
    switch (frequencyType) {
      case FrequencyType.daily:
        return 'Daily';
      case FrequencyType.weekly:
        if (specificDays == null || specificDays!.isEmpty) return 'Weekly';
        final dayNames = specificDays!.map((day) => day.name.substring(0, 3)).join(', ');
        return specificDays!.length == 1 
            ? 'Weekly on ${specificDays![0].name}' 
            : 'Weekly on $dayNames';
      case FrequencyType.monthly:
        if (dayOfMonth == null) return 'Monthly';
        return 'Monthly on day $dayOfMonth';
      case FrequencyType.yearly:
        if (dayOfMonth == null || month == null) return 'Yearly';
        final monthName = [
          'January', 'February', 'March', 'April', 'May', 'June', 
          'July', 'August', 'September', 'October', 'November', 'December'
        ][month! - 1];
        return 'Yearly on $monthName $dayOfMonth';
      case FrequencyType.custom:
        if (customInterval == null || customInterval! <= 0) return 'Custom interval';
        return customInterval == 1 
            ? 'Every day' 
            : 'Every $customInterval days';
    }
  }
}