import 'package:cloud_firestore/cloud_firestore.dart';

// This class represents a habit with its properties
class Habit {
  String id;
  String name;
  String? dailyGoal;
  bool isDone;
  DateTime createdAt;
  String userId;

  Habit({
    required this.id,
    required this.name,
    this.dailyGoal,
    this.isDone = false,
    required this.createdAt,
    required this.userId,
  });

  // Convert Habit to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dailyGoal': dailyGoal,
      'isDone': isDone,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  // Create a Habit from a Firestore document
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      dailyGoal: data['dailyGoal'],
      isDone: data['isDone'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
    );
  }

  // Clone a habit with some modified properties
  Habit copyWith({
    String? id,
    String? name,
    String? dailyGoal,
    bool? isDone,
    DateTime? createdAt,
    String? userId,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}