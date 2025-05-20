import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_provider.dart';

class HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool showCheckbox;
  
  const HabitCard({
    super.key,
    required this.habit,
    this.showCheckbox = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    habit.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showCheckbox)
                  Checkbox(
                    value: habit.isDone,
                    onChanged: (_) {
                      ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                    },
                  )
                else
                  SizedBox(
                    width: 40, // Approximate width of a Checkbox
                    height: 40,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (habit.description != null && habit.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Description: ${habit.description}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            // Always show frequency description below the goal
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
    );
  }
}