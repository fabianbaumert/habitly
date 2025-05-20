import 'package:hive/hive.dart';
import 'package:habitly/models/habit.dart';

part 'hive_habit.g.dart';

// Hive model for Habit
@HiveType(typeId: 0)
class HiveHabit {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String? description;
  
  @HiveField(4)
  final bool isDone;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final String userId;

  HiveHabit({
    required this.id,
    required this.name,
    this.description,
    this.isDone = false,
    required this.createdAt,
    required this.userId,
  });

  // Convert from Habit model to HiveHabit
  factory HiveHabit.fromHabit(Habit habit) {
    return HiveHabit(
      id: habit.id,
      name: habit.name,
      description: habit.description,
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
      description: description,
      isDone: isDone,
      createdAt: createdAt,
      userId: userId,
    );
  }
}