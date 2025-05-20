import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_provider.dart';

class HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool showCheckbox;
  final bool? isCompleted; // For custom completion status (e.g., calendar)
  final VoidCallback? onToggle; // For custom toggle (e.g., calendar)
  final bool isFutureDate;

  const HabitCard({
    super.key,
    required this.habit,
    this.showCheckbox = true,
    this.isCompleted,
    this.onToggle,
    this.isFutureDate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = isCompleted ?? habit.isDone;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Custom circular check/unchecked icon
                if (showCheckbox)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      onTap: isFutureDate ? null : (onToggle ?? () {
                        ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                      }),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: completed ? Colors.green : Colors.transparent,
                          border: Border.all(
                            color: completed ? Colors.green : Colors.grey,
                            width: 2,
                          ),
                        ),
                        width: 24,
                        height: 24,
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: completed ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(width: 24, height: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: completed ? TextDecoration.lineThrough : null,
                          color: completed ? Colors.grey : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (habit.description != null && habit.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            habit.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: completed ? Colors.grey : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          habit.getFrequencyDescription(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}