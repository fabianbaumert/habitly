import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';

/// A habit card that allows checking/unchecking for a specific date
class HabitCardForDate extends ConsumerWidget {
  final Habit habit;
  final bool isCompleted;
  final bool isFutureDate;
  final VoidCallback? onToggle;

  const HabitCardForDate({
    super.key,
    required this.habit,
    required this.isCompleted,
    required this.isFutureDate,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Checkbox or icon
            InkWell(
              onTap: isFutureDate ? null : onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: isCompleted ? Colors.white : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Habit details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  if (habit.description != null && habit.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Description: ${habit.description}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      habit.getFrequencyDescription(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted ? Colors.grey : Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Complete/Undo label
            if (!isFutureDate)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  isCompleted ? 'Undo' : 'Complete',
                  style: TextStyle(
                    color: isCompleted ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
