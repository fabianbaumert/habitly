import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/widgets/habit_card.dart';
import 'package:habitly/screens/habit_detail_screen.dart';
import 'package:habitly/widgets/celebration_confetti.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_history_provider.dart';

class TodayScreen extends ConsumerStatefulWidget {
  final bool showDrawer;
  
  const TodayScreen({
    super.key, 
    this.showDrawer = true,
  });

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _showCompleted = false;
  bool _showConfetti = false;
  DateTime? _lastConfettiDate;
  late final DateTime today = DateTime.now();

  void _handleToggleHabit(Habit habit, List<Habit> dueHabits, Map<String, bool> habitHistory) {
    final wasLastTodo = dueHabits.where((h) => habitHistory[h.id] != true && h.id != habit.id).isEmpty;
    
    // Create optimistic UI update - update current view immediately 
    // before the async operations complete
    setState(() {
      // Update the local state optimistically
      final currentStatus = habitHistory[habit.id] == true;
      habitHistory[habit.id] = !currentStatus;
    });
    
    // Toggle the habit in the background
    ref.read(habitsProvider.notifier).toggleHabitCompletion(habit).then((_) {
      // Only invalidate habitHistoryProvider as it's more lightweight
      ref.invalidate(habitHistoryProvider(today));
      
      // Show confetti if needed - delay slightly to ensure UI has updated
      if (wasLastTodo && habitHistory[habit.id] == true) {
        _showConfettiIfNeeded();
      }
    });
  }
  
  void _showConfettiIfNeeded() {
    final currentDate = DateTime.now();
    final isNewDay = _lastConfettiDate == null ||
      _lastConfettiDate!.year != currentDate.year ||
      _lastConfettiDate!.month != currentDate.month ||
      _lastConfettiDate!.day != currentDate.day;
      
    if (isNewDay || !_showConfetti) {
      setState(() {
        _showConfetti = true;
        _lastConfettiDate = currentDate;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showConfetti = false;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final habitHistoryAsync = ref.watch(habitHistoryProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
      ),
      body: habitsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Text('Error loading habits: ${error.toString()}'),
          );
        },
        data: (habits) {
          return habitHistoryAsync.when(
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stackTrace) {
              return Center(child: Text('Error loading habit history: ${error.toString()}'));
            },
            data: (habitHistory) {
              // Filter habits due today
              final dueHabits = habits.where((habit) => habit.isDueOn(today)).toList();
              
              if (dueHabits.isEmpty) {
                // Reset confetti for a new day if no habits
                if (_lastConfettiDate != null && (_lastConfettiDate!.year != today.year || 
                    _lastConfettiDate!.month != today.month || 
                    _lastConfettiDate!.day != today.day)) {
                  _lastConfettiDate = null;
                  _showConfetti = false;
                }
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'All done for today!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No habits scheduled for today',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Memoize these lists to avoid unnecessary rebuilds
              final todoHabits = dueHabits.where((h) => habitHistory[h.id] != true).toList();
              final completedHabits = dueHabits.where((h) => habitHistory[h.id] == true).toList();

              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // To-do section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'To Do',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${todoHabits.length} remaining',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // To-do list
                      Expanded(
                        child: todoHabits.isEmpty 
                          ? const Center(
                              child: Text(
                                'Nothing left to do today!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: todoHabits.length,
                              itemBuilder: (context, index) {
                                final habit = todoHabits[index];
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
                                    showCheckbox: true,
                                    isCompleted: habitHistory[habit.id] == true,
                                    onToggle: () => _handleToggleHabit(habit, dueHabits, habitHistory),
                                  ),
                                );
                              },
                            ),
                      ),
                      // Completed section header with toggle
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showCompleted = !_showCompleted;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Completed',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${completedHabits.length} habits',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    _showCompleted 
                                      ? Icons.keyboard_arrow_up 
                                      : Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Completed list (collapsible)
                      if (_showCompleted)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                          child: completedHabits.isEmpty
                            ? const Center(
                                child: Text(
                                  'No completed habits yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: completedHabits.length,
                                itemBuilder: (context, index) {
                                  final habit = completedHabits[index];
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
                                      showCheckbox: true,
                                      isCompleted: habitHistory[habit.id] == true,
                                      onToggle: () => _handleToggleHabit(habit, dueHabits, habitHistory),
                                    ),
                                  );
                                },
                              ),
                        ),
                    ],
                  ),
                  CelebrationConfetti(show: _showConfetti),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
