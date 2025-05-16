import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/widgets/app_drawer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// Create a provider to track calendar update triggers
final calendarUpdateProvider = StateProvider<int>((ref) => 0);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;
  
  // Add a map to keep track of locally updated completion states
  final Map<String, bool> _localCompletionStatus = {};
  
  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month;
    
    // Set the current screen in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setScreen(NavigationScreen.calendar);
    });
  }
  
  // Check if a date has all habits completed (considering local changes)
  Future<bool> _areAllHabitsCompleted(DateTime date) async {
    final habitsAsync = ref.read(habitsProvider);
    
    return habitsAsync.when(
      data: (habits) async {
        if (habits.isEmpty) return false;
        
        // Get filtered habits for this date
        final dateFormatted = DateTime(date.year, date.month, date.day);
        final habitsForDate = habits.where(
          (habit) {
            final habitDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
            return !habitDate.isAfter(dateFormatted);
          }
        ).toList();
        
        if (habitsForDate.isEmpty) return false;
        
        // Get server status
        final serverStatus = await ref.read(habitHistoryProvider(date).future);
        
        // Check if all habits are completed (either in server or local state)
        for (final habit in habitsForDate) {
          final isCompleted = _getCompletionStatus(habit.id, date, serverStatus);
          if (!isCompleted) {
            return false; // Found an uncompleted habit
          }
        }
        
        return true; // All habits are completed
      },
      loading: () => false,
      error: (_, __) => false,
    );
  }
  
  // Calculate completion rate (considering local changes)
  Future<double> _getCompletionRate(DateTime date) async {
    final habitsAsync = ref.read(habitsProvider);
    
    return habitsAsync.when(
      data: (habits) async {
        if (habits.isEmpty) return 0.0;
        
        // Get filtered habits for this date
        final dateFormatted = DateTime(date.year, date.month, date.day);
        final habitsForDate = habits.where(
          (habit) {
            final habitDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
            return !habitDate.isAfter(dateFormatted);
          }
        ).toList();
        
        if (habitsForDate.isEmpty) return 0.0;
        
        // Get server status
        final serverStatus = await ref.read(habitHistoryProvider(date).future);
        
        // Count completed habits
        int completedCount = 0;
        for (final habit in habitsForDate) {
          final isCompleted = _getCompletionStatus(habit.id, date, serverStatus);
          if (isCompleted) {
            completedCount++;
          }
        }
        
        return completedCount / habitsForDate.length;
      },
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );
  }
  
  // Function to toggle completion state locally and in the database
  void _toggleHabitCompletion(Habit habit, DateTime date, bool currentStatus) {
    // Update local state immediately
    setState(() {
      // Create a key that includes both habit ID and date
      final key = '${habit.id}_${date.year}-${date.month}-${date.day}';
      _localCompletionStatus[key] = !currentStatus;
    });
    
    // Then update the database
    ref.read(habitsProvider.notifier).toggleHabitCompletionForDate(
      habit, 
      date
    );
    
    // Trigger calendar update
    ref.read(calendarUpdateProvider.notifier).state++;
  }
  
  // Function to get the current completion status (from local state if available)
  bool _getCompletionStatus(String habitId, DateTime date, Map<String, bool> serverStatus) {
    final key = '${habitId}_${date.year}-${date.month}-${date.day}';
    
    // If we have a local override, use that
    if (_localCompletionStatus.containsKey(key)) {
      return _localCompletionStatus[key]!;
    }
    
    // Otherwise use the server status
    return serverStatus[habitId] ?? false;
  }
  
  void _showLegendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Calendar Legend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LegendItem(
                color: Colors.green,
                label: 'All habits completed',
              ),
              const SizedBox(height: 12),
              const _LegendItem(
                color: Colors.amber,
                label: 'Some habits completed',
              ),
              const SizedBox(height: 12),
              const _LegendItem(
                color: Colors.grey,
                label: 'No habits completed',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Watch calendar update trigger to rebuild when needed
    final _ = ref.watch(calendarUpdateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showLegendDialog(context),
            tooltip: 'Show legend',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildCalendar(),
          const Divider(),
          Expanded(
            child: _buildSelectedDayHabits(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalendar() {
    // Watch the provider to refresh the calendar when needed
    final _ = ref.watch(calendarUpdateProvider);
    
    return TableCalendar(
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          return FutureBuilder<bool>(
            future: _areAllHabitsCompleted(date),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink(); // Show nothing while loading
              }
              
              return FutureBuilder<double>(
                future: _getCompletionRate(date),
                builder: (context, rateSnapshot) {
                  if (!rateSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  
                  final completionRate = rateSnapshot.data ?? 0.0;
                  Color markerColor;
                  
                  if (snapshot.data == true) {
                    // All habits completed
                    markerColor = Colors.green;
                  } else if (completionRate > 0) {
                    // Some habits completed
                    markerColor = Colors.amber;
                  } else {
                    // No habits completed
                    markerColor = Colors.grey.withAlpha((0.3 * 255).toInt());
                  }
                  
                  // Only show markers for dates up to today
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final checkDate = DateTime(date.year, date.month, date.day);
                  
                  if (checkDate.isAfter(today)) {
                    return const SizedBox.shrink();
                  }
                  
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: markerColor,
                    ),
                    width: 8,
                    height: 8,
                  );
                }
              );
            }
          );
        },
      ),
    );
  }
  
  Widget _buildSelectedDayHabits() {
    final habitsAsync = ref.watch(habitsProvider);
    
    // Get current date for comparison (for disabling future date interactions)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final isFutureDate = selectedDate.isAfter(today);
    
    // Debug print to track selected day
    debugPrint('Selected day: ${_selectedDay.toString()}, Is Future: $isFutureDate');
    
    return habitsAsync.when(
      data: (habits) {
        // Sort habits by creation date (oldest first)
        habits.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        // Debug - log the habits and their creation dates
        debugPrint('Total habits: ${habits.length}');
        
        // Only show habits that existed on or before the selected day
        final selectedDayHabits = habits.where(
          (habit) {
            final habitDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
            return !habitDate.isAfter(selectedDate);
          }
        ).toList();
        
        debugPrint('Filtered habits: ${selectedDayHabits.length}');
        
        if (selectedDayHabits.isEmpty) {
          return const Center(
            child: Text(
              'No habits found for this day',
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        
        return FutureBuilder<Map<String, bool>>(
          future: ref.read(habitHistoryProvider(_selectedDay).future),
          builder: (context, snapshot) {
            final habitHistory = snapshot.data ?? {};
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Habits for ${DateFormat('EEEE, MMMM d, y').format(_selectedDay)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: selectedDayHabits.length,
                    itemBuilder: (context, index) {
                      final habit = selectedDayHabits[index];
                      final isCompleted = _getCompletionStatus(habit.id, _selectedDay, habitHistory);
                      
                      // Text color based on future date status
                      final textColor = isFutureDate ? Colors.grey : null;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isFutureDate 
                                  ? Colors.grey 
                                  : (isCompleted ? Colors.green : Colors.grey),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      habit.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                    ),
                                    if (habit.dailyGoal != null && habit.dailyGoal!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Goal: ${habit.dailyGoal}',
                                          style: TextStyle(
                                            color: isFutureDate ? Colors.grey[400] : Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isFutureDate)
                                // Show disabled button for future dates
                                TextButton.icon(
                                  icon: Icon(
                                    isCompleted ? Icons.undo : Icons.check,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  label: Text(
                                    isCompleted ? 'Undo' : 'Complete',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: null, // Disabled
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                )
                              else
                                // Active button for past or current dates
                                TextButton.icon(
                                  icon: Icon(
                                    isCompleted ? Icons.undo : Icons.check,
                                    color: isCompleted ? Colors.orange : Colors.green,
                                    size: 20,
                                  ),
                                  label: Text(
                                    isCompleted ? 'Undo' : 'Complete',
                                    style: TextStyle(
                                      color: isCompleted ? Colors.orange : Colors.green,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: () {
                                    _toggleHabitCompletion(habit, _selectedDay, isCompleted);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading habits: $error'),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  
  const _LegendItem({
    required this.color,
    required this.label,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}