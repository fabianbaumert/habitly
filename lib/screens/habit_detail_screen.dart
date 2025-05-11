import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/screens/habit_form_screen.dart';
import 'package:intl/intl.dart';

class HabitDetailScreen extends ConsumerWidget {
  final Habit habit;

  const HabitDetailScreen({
    Key? key,
    required this.habit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editHabit(context),
            tooltip: 'Edit habit',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteHabit(context, ref),
            tooltip: 'Delete habit',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Habit Overview Section
            _buildOverviewSection(context, ref),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Progress History Section
            _buildProgressHistorySection(context),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Calendar Section
            _buildCalendarSection(context),
          ],
        ),
      ),
    );
  }

  // Habit Overview Section
  Widget _buildOverviewSection(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Status indicator
            Row(
              children: [
                Icon(
                  habit.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: habit.isDone ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${habit.isDone ? "Completed" : "Not completed"} today',
                  style: TextStyle(
                    color: habit.isDone ? Colors.green : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Toggle completion button
                TextButton.icon(
                  icon: Icon(
                    habit.isDone ? Icons.undo : Icons.check,
                    color: habit.isDone ? Colors.orange : Colors.green,
                  ),
                  label: Text(
                    habit.isDone ? 'Undo' : 'Complete',
                    style: TextStyle(
                      color: habit.isDone ? Colors.orange : Colors.green,
                    ),
                  ),
                  onPressed: () {
                    ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Daily goal
            if (habit.dailyGoal != null && habit.dailyGoal!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.flag, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Goal: ${habit.dailyGoal}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            
            const SizedBox(height: 12),
            
            // Reminder time
            if (habit.reminderTime != null)
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Reminder: ${habit.reminderTime!.format(context)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            
            const SizedBox(height: 12),
            
            // Creation date
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Started: ${DateFormat.yMMMd().format(habit.createdAt)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: habit.isDone ? 1.0 : 0.0,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  habit.isDone ? Colors.green : Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Progress History Section - Shows weekly/daily overview
  Widget _buildProgressHistorySection(BuildContext context) {
    // Get the current date and the days of the week
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Calculate the dates for the current week (Monday to Sunday)
    final currentWeekday = now.weekday; // 1 for Monday, 7 for Sunday
    final firstDayOfWeek = today.subtract(Duration(days: currentWeekday - 1));
    
    // In a real implementation, we'd fetch the habit completion history
    // Since we don't have habit history tracking yet, we'll just show
    // the current completion status if it's today, otherwise no historical data
    final isCompletedToday = habit.isDone;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Progress',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final dayName = daysOfWeek[index];
            final dayDate = firstDayOfWeek.add(Duration(days: index));
            final isToday = dayDate.year == today.year && 
                            dayDate.month == today.month &&
                            dayDate.day == today.day;
            final isPastDay = dayDate.compareTo(today) <= 0;
            // Only show completed if it's today and isDone is true
            final isCompleted = isToday && isCompletedToday;
            
            return Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPastDay
                        ? (isCompleted ? Colors.green : Colors.grey[300])
                        : Colors.grey[200], // Future days are lighter grey
                  ),
                  child: Center(
                    child: isPastDay
                        ? (isToday
                            ? Icon(
                                isCompleted ? Icons.check : Icons.close,
                                color: isCompleted ? Colors.white : Colors.grey[600],
                                size: 20,
                              )
                            : Text(
                                dayName[0], // Just the first letter for past days
                                style: TextStyle(color: Colors.grey[600]),
                              ))
                        : Text(
                            dayName[0], // Just the first letter for future days
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dayName,
                  style: TextStyle(
                    color: isPastDay ? Colors.black : Colors.grey[400],
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // Calendar Section - Shows a small calendar with completed days
  Widget _buildCalendarSection(BuildContext context) {
    // Get current month days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final firstWeekdayOfMonth = firstDayOfMonth.weekday; // 1 for Monday, 7 for Sunday
    
    // In a real implementation, we'd fetch the habit completion history
    // Since we don't have habit history tracking yet, we'll just show
    // the current completion status if it's today
    final isCompletedToday = habit.isDone;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Calendar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        
        // Month header
        Center(
          child: Text(
            DateFormat.yMMMM().format(now),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Day of week headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) => 
            SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            )
          ).toList(),
        ),
        
        const SizedBox(height: 8),
        
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: firstWeekdayOfMonth - 1 + daysInMonth,
          itemBuilder: (context, index) {
            // Empty cells before the first day of month
            if (index < firstWeekdayOfMonth - 1) {
              return const SizedBox.shrink();
            }
            
            // Day cells
            final day = index - (firstWeekdayOfMonth - 1) + 1;
            final isToday = day == now.day;
            // Only mark today as completed if the habit is done
            final isCompleted = isToday && isCompletedToday;
            final dayDate = DateTime(now.year, now.month, day);
            final isFutureDay = dayDate.compareTo(today) > 0;
            
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted 
                  ? Colors.green.withOpacity(0.8) 
                  : Colors.transparent,
                border: isToday 
                  ? Border.all(color: Theme.of(context).primaryColor, width: 2) 
                  : null,
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted 
                        ? Colors.white 
                        : (isFutureDay ? Colors.grey[400] : null),
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Completed'),
            
            const SizedBox(width: 24),
            
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).primaryColor, width: 2),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Today'),
          ],
        ),
      ],
    );
  }

  // Edit habit method
  void _editHabit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitFormScreen(existingHabit: habit),
      ),
    );
  }

  // Delete habit method with confirmation dialog
  void _deleteHabit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete "${habit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDelete(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Handle actual deletion after confirmation
  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(habitsProvider.notifier).deleteHabit(habit.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting habit: $e')),
        );
      }
    }
  }
}