import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:habitly/widgets/habit_card.dart';
import 'package:habitly/screens/habit_detail_screen.dart';

// Create a provider to track calendar update triggers
final calendarUpdateProvider = StateProvider<int>((ref) => 0);

class CalendarScreen extends ConsumerStatefulWidget {
  final bool showDrawer;
  
  const CalendarScreen({
    super.key,
    this.showDrawer = true,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;
  
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
  
  // Check if a date has all habits completed (real-time, reactive)
  bool _areAllHabitsCompleted(DateTime date, AsyncValue<List<Habit>> habitsAsync, AsyncValue<Map<String, bool>> habitHistoryAsync) {
    return habitsAsync.when(
      data: (habits) {
        if (habits.isEmpty) return false;
        final habitsForDate = habits.where((habit) => habit.isDueOn(date)).toList();
        if (habitsForDate.isEmpty) return false;
        return habitHistoryAsync.when(
          data: (serverStatus) {
            for (final habit in habitsForDate) {
              final isCompleted = _getCompletionStatus(habit.id, date, serverStatus);
              if (!isCompleted) return false;
            }
            return true;
          },
          loading: () => false,
          error: (_, __) => false,
        );
      },
      loading: () => false,
      error: (_, __) => false,
    );
  }

  // Calculate completion rate (real-time, reactive)
  double _getCompletionRate(DateTime date, AsyncValue<List<Habit>> habitsAsync, AsyncValue<Map<String, bool>> habitHistoryAsync) {
    return habitsAsync.when(
      data: (habits) {
        if (habits.isEmpty) return 0.0;
        final habitsForDate = habits.where((habit) => habit.isDueOn(date)).toList();
        if (habitsForDate.isEmpty) return 0.0;
        return habitHistoryAsync.when(
          data: (serverStatus) {
            int completedCount = 0;
            for (final habit in habitsForDate) {
              final isCompleted = _getCompletionStatus(habit.id, date, serverStatus);
              if (isCompleted) completedCount++;
            }
            return completedCount / habitsForDate.length;
          },
          loading: () => 0.0,
          error: (_, __) => 0.0,
        );
      },
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );
  }
  
  // Function to toggle completion state in the database and refresh provider
  void _toggleHabitCompletion(Habit habit, DateTime date, bool currentStatus) {
    ref.read(habitsProvider.notifier).toggleHabitCompletionForDate(
      habit, 
      date
    ).then((_) {
      // No need to invalidate, StreamProvider will update automatically
      ref.read(calendarUpdateProvider.notifier).state++;
    });
  }

  // Function to get the current completion status (from provider only)
  bool _getCompletionStatus(String habitId, DateTime date, Map<String, bool> serverStatus) {
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
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showLegendDialog(context),
            tooltip: 'Show legend',
          ),
        ],
      ),
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
          return Consumer(
            builder: (context, ref, _) {
              final habitsAsync = ref.watch(habitsProvider);
              final habitHistoryAsync = ref.watch(habitHistoryProvider(date));
              return habitsAsync.when(
                data: (habits) {
                  final habitsForDate = habits.where((habit) => habit.isDueOn(date)).toList();
                  if (habitsForDate.isEmpty) return const SizedBox.shrink();
                  return habitHistoryAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (serverStatus) {
                      // Check if all habits are completed
                      final allCompleted = habitsForDate.every((habit) => serverStatus[habit.id] ?? false);
                      final completedCount = habitsForDate.where((habit) => serverStatus[habit.id] ?? false).length;
                      final completionRate = habitsForDate.isEmpty ? 0.0 : completedCount / habitsForDate.length;
                      Color markerColor;
                      if (allCompleted) {
                        markerColor = Colors.green;
                      } else if (completionRate > 0) {
                        markerColor = Colors.amber;
                      } else {
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
                        width: 12,
                        height: 12,
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildSelectedDayHabits() {
    final habitsAsync = ref.watch(habitsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final isFutureDate = selectedDate.isAfter(today);
    final habitHistoryAsync = ref.watch(habitHistoryProvider(_selectedDay));

    return habitsAsync.when(
      data: (habits) {
        // Only show habits that are scheduled for the selected date
        final selectedDayHabits = habits.where((habit) => habit.isDueOn(selectedDate)).toList();
        if (selectedDayHabits.isEmpty) {
          return const Center(
            child: Text(
              'No habits found for this day',
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        return habitHistoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error loading habit history: $error')),
          data: (habitHistory) {
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
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HabitDetailScreen(habit: habit),
                            ),
                          );
                        },
                        child: HabitCard(
                          habit: habit,
                          isCompleted: isCompleted,
                          isFutureDate: isFutureDate,
                          onToggle: isFutureDate
                            ? null
                            : () => _toggleHabitCompletion(habit, _selectedDay, isCompleted),
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