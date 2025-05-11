import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// This class represents a habit with its properties
class Habit {
  String id;
  String name;
  String? dailyGoal;
  TimeOfDay? reminderTime;
  bool isDone;
  DateTime createdAt;
  String userId;

  Habit({
    required this.id,
    required this.name,
    this.dailyGoal,
    this.reminderTime,
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
      'reminderTime': reminderTime != null ? 
        '${reminderTime!.hour}:${reminderTime!.minute}' : null,
      'isDone': isDone,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  // Create a Habit from a Firestore document
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String? reminderTimeStr = data['reminderTime'];
    TimeOfDay? reminder;
    
    if (reminderTimeStr != null) {
      List<String> timeParts = reminderTimeStr.split(':');
      reminder = TimeOfDay(
        hour: int.parse(timeParts[0]), 
        minute: int.parse(timeParts[1])
      );
    }

    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      dailyGoal: data['dailyGoal'],
      reminderTime: reminder,
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
    TimeOfDay? reminderTime,
    bool? isDone,
    DateTime? createdAt,
    String? userId,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      reminderTime: reminderTime ?? this.reminderTime,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}