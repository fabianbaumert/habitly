import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/screens/habit_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:habitly/providers/habit_history_provider.dart';

// Create a provider for the current habit being viewed
final currentHabitProvider = Provider<Habit>((ref) {
  throw UnimplementedError('Provider was not overridden');
});

// Provider to track the currently selected month in the calendar
final selectedMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

class HabitDetailScreen extends ConsumerWidget {
  final Habit habit;

  const HabitDetailScreen({
    super.key,
    required this.habit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the habits provider to get real-time updates
    final habitsAsync = ref.watch(habitsProvider);
    
    // Find the current habit in the updated list to get the latest state
    final currentHabit = habitsAsync.when(
      data: (habits) {
        // Find the habit with the matching ID
        final updatedHabit = habits.firstWhere(
          (h) => h.id == habit.id,
          orElse: () => habit, // Fallback to original if not found
        );
        return updatedHabit;
      },
      loading: () => habit, // Use original while loading
      error: (_, __) => habit, // Use original in case of error
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentHabit.name),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editHabit(context, currentHabit),
            tooltip: 'Edit habit',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteHabit(context, ref, currentHabit),
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
            _buildOverviewSection(context, ref, currentHabit),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Calendar Section
            _buildCalendarSection(context, currentHabit),
          ],
        ),
      ),
    );
  }

  // Habit Overview Section (read-only, only description and frequency, no headline, info icon for description)
  Widget _buildOverviewSection(BuildContext context, WidgetRef ref, Habit currentHabit) {
    final hasDescription = currentHabit.description != null && currentHabit.description!.isNotEmpty;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDescription)
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentHabit.description!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            if (hasDescription) const SizedBox(height: 12),
            // Frequency (always same top margin if no description)
            Row(
              children: [
                const Icon(Icons.repeat, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  currentHabit.getFrequencyDescription(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Calendar Section - Shows a small calendar with completed days
  Widget _buildCalendarSection(BuildContext context, Habit currentHabit) {
    return Consumer(
      builder: (context, ref, child) {
        // Get the selected month from the provider
        final selectedMonth = ref.watch(selectedMonthProvider);
        
        // Get current month days
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysInMonth = DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
        final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
        final firstWeekdayOfMonth = firstDayOfMonth.weekday; // 1 for Monday, 7 for Sunday
        
        // Use the habit history provider for today's completion status
        final habitHistoryAsync = ref.watch(habitHistoryProvider(today));
        final isCompletedToday = habitHistoryAsync.when(
          data: (history) => history[currentHabit.id] == true,
          loading: () => false,
          error: (e, _) => false,
        );
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Habit Completion Calendar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Month header with navigation arrows
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous month button
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    // Navigate to previous month
                    final previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
                    ref.read(selectedMonthProvider.notifier).state = previousMonth;
                  },
                ),
                
                // Month and year display
                Text(
                  DateFormat.yMMMM().format(selectedMonth),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                
                // Next month button
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    // Navigate to next month
                    final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
                    ref.read(selectedMonthProvider.notifier).state = nextMonth;
                  },
                ),
              ],
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
                final dayDate = DateTime(selectedMonth.year, selectedMonth.month, day);
                
                // Check if this is today
                final isToday = dayDate.year == today.year && 
                                dayDate.month == today.month && 
                                dayDate.day == today.day;
                                
                // Only mark today as completed if the habit is done
                final isCompleted = isToday && isCompletedToday;
                final isFutureDay = dayDate.compareTo(today) > 0;
                
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted 
                      ? Colors.green.withAlpha((0.8 * 255).toInt()) 
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
      },
    );
  }

  // Edit habit method
  void _editHabit(BuildContext context, Habit currentHabit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitFormScreen(existingHabit: currentHabit),
      ),
    );
  }

  // Delete habit method with confirmation dialog
  void _deleteHabit(BuildContext context, WidgetRef ref, Habit currentHabit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete "${currentHabit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDelete(context, ref, currentHabit);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Handle actual deletion after confirmation
  void _confirmDelete(BuildContext context, WidgetRef ref, Habit currentHabit) async {
    try {
      await ref.read(habitsProvider.notifier).deleteHabit(currentHabit.id);
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