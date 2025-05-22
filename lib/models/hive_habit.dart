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
  final DateTime createdAt;
  
  @HiveField(5)
  final String userId;

  @HiveField(6)
  final int frequencyTypeIndex;

  @HiveField(7)
  final List<int>? specificDays;

  HiveHabit({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.userId,
    this.frequencyTypeIndex = 0,
    this.specificDays,
  });

  // Convert from Habit model to HiveHabit
  factory HiveHabit.fromHabit(Habit habit) {
    return HiveHabit(
      id: habit.id,
      name: habit.name,
      description: habit.description,
      createdAt: habit.createdAt,
      userId: habit.userId,
      frequencyTypeIndex: habit.frequencyType.index,
      specificDays: habit.specificDays?.map((d) => d.value).toList(),
    );
  }

  // Convert HiveHabit to Habit model
  Habit toHabit() {
    return Habit(
      id: id,
      name: name,
      description: description,
      createdAt: createdAt,
      userId: userId,
      frequencyType: FrequencyType.values[frequencyTypeIndex],
      specificDays: specificDays?.map((v) => DayOfWeek.fromInt(v)).toList(),
    );
  }
}