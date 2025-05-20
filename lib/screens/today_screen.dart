import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/widgets/habit_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
      ),
      body: habitsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Text('Error loading habits: $error'),
        ),
        data: (habits) {
          // Filter habits due today
          final today = DateTime.now();
          final dueHabits = habits.where((habit) => 
            habit.isDueOn(today)
          ).toList();
          
          if (dueHabits.isEmpty) {
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
          final todoHabits = dueHabits.where((h) => !h.isDone).toList();
          final completedHabits = dueHabits.where((h) => h.isDone).toList();

          return Column(
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
                        return HabitCard(
                          habit: habit,
                          showCheckbox: true,
                          onToggle: () {
                            ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                          },
                          // isCompleted and isFutureDate use defaults
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
                          return HabitCard(
                            habit: habit,
                            showCheckbox: true,
                            onToggle: () {
                              ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                            },
                          );
                        },
                      ),
                ),
            ],
          );
        },
      ),
    );
  }
}
