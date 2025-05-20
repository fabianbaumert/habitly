import 'package:habitly/models/habit.dart';

/// A helper class to work with frequency data
class FrequencyData {
  final FrequencyType frequencyType;
  final List<DayOfWeek>? specificDays; // Used for weekly selection
  final int? dayOfMonth;
  final int? month;
  final int? customInterval;

  FrequencyData({
    required this.frequencyType,
    this.specificDays,
    this.dayOfMonth,
    this.month,
    this.customInterval,
  });

  /// Create FrequencyData from a Habit
  factory FrequencyData.fromHabit(Habit habit) {
    return FrequencyData(
      frequencyType: habit.frequencyType,
      specificDays: habit.specificDays,
      dayOfMonth: habit.dayOfMonth,
      month: habit.month,
      customInterval: habit.customInterval,
    );
  }

  /// Apply frequency data to a habit
  Habit applyToHabit(Habit habit) {
    return habit.copyWith(
      frequencyType: frequencyType,
      specificDays: specificDays,
      dayOfMonth: dayOfMonth,
      month: month,
      customInterval: customInterval,
    );
  }

  /// Get a human-readable description
  String getDescription() {
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
