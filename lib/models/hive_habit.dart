import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:habitly/models/habit.dart';

part 'hive_habit.g.dart';

// Define Hive type for TimeOfDay
class TimeOfDayAdapter extends TypeAdapter<TimeOfDay> {
  @override
  final int typeId = 1;

  @override
  TimeOfDay read(BinaryReader reader) {
    final hour = reader.readInt();
    final minute = reader.readInt();
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void write(BinaryWriter writer, TimeOfDay obj) {
    writer.writeInt(obj.hour);
    writer.writeInt(obj.minute);
  }
}

// Hive model for Habit
@HiveType(typeId: 0)
class HiveHabit {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String? dailyGoal;
  
  @HiveField(3)
  final TimeOfDay? reminderTime;
  
  @HiveField(4)
  final bool isDone;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final String userId;

  HiveHabit({
    required this.id,
    required this.name,
    this.dailyGoal,
    this.reminderTime,
    this.isDone = false,
    required this.createdAt,
    required this.userId,
  });

  // Convert from Habit model to HiveHabit
  factory HiveHabit.fromHabit(Habit habit) {
    return HiveHabit(
      id: habit.id,
      name: habit.name,
      dailyGoal: habit.dailyGoal,
      reminderTime: habit.reminderTime,
      isDone: habit.isDone,
      createdAt: habit.createdAt,
      userId: habit.userId,
    );
  }

  // Convert HiveHabit to Habit model
  Habit toHabit() {
    return Habit(
      id: id,
      name: name,
      dailyGoal: dailyGoal,
      reminderTime: reminderTime,
      isDone: isDone,
      createdAt: createdAt,
      userId: userId,
    );
  }
}