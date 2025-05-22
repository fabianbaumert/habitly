import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
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
    ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
    // Only show confetti if this is the last todo and not already shown today
    final today = DateTime.now();
    final isNewDay = _lastConfettiDate == null ||
      _lastConfettiDate!.year != today.year ||
      _lastConfettiDate!.month != today.month ||
      _lastConfettiDate!.day != today.day;
    if (wasLastTodo && habitHistory[habit.id] != true && (isNewDay || !_showConfetti)) {
      setState(() {
        _showConfetti = true;
        _lastConfettiDate = today;
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
    
    // Set the current screen in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setScreen(NavigationScreen.today);
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final habitHistoryAsync = ref.watch(habitHistoryProvider(today));

    debugPrint('[TodayScreen] habitsAsync: ${habitsAsync.toString()}');
    debugPrint('[TodayScreen] habitHistoryAsync: ${habitHistoryAsync.toString()}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
      ),
      body: habitsAsync.when(
        loading: () {
          debugPrint('[TodayScreen] habitsProvider is loading');
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          debugPrint('[TodayScreen] habitsProvider error: ${error.toString()}');
          return Center(
            child: Text('Error loading habits: ${error.toString()}'),
          );
        },
        data: (habits) {
          debugPrint('[TodayScreen] habitsProvider data: count=${habits.length}');
          return habitHistoryAsync.when(
            loading: () {
              debugPrint('[TodayScreen] habitHistoryProvider is loading');
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stackTrace) {
              debugPrint('[TodayScreen] habitHistoryProvider error: ${error.toString()}');
              return Center(child: Text('Error loading habit history: ${error.toString()}'));
            },
            data: (habitHistory) {
              debugPrint('[TodayScreen] habitHistoryProvider data: keys=${habitHistory.keys.toList()}');
              // Filter habits due today
              final dueHabits = habits.where((habit) => habit.isDueOn(today)).toList();
              debugPrint('[TodayScreen] dueHabits count: ${dueHabits.length}');
              if (dueHabits.isEmpty) {
                // Reset confetti for a new day if no habits
                if (_lastConfettiDate != null && (_lastConfettiDate!.year != today.year || _lastConfettiDate!.month != today.month || _lastConfettiDate!.day != today.day)) {
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

              // Separate into to-do and completed lists
              final todoHabits = dueHabits.where((h) => habitHistory[h.id] != true).toList();
              final completedHabits = dueHabits.where((h) => habitHistory[h.id] == true).toList();
              debugPrint('[TodayScreen] todoHabits count: ${todoHabits.length}, completedHabits count: ${completedHabits.length}');

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
                                      onToggle: () {
                                        ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                                      },
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
