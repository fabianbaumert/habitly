import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/screens/habit_detail_screen.dart';

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
                        return _buildHabitItem(context, todoHabits[index]);
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
                          return _buildHabitItem(context, completedHabits[index]);
                        },
                      ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHabitItem(BuildContext context, Habit habit) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: InkWell(
        onTap: () {
          // Navigate to habit detail when tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HabitDetailScreen(habit: habit),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Checkbox for marking completion
              InkWell(
                onTap: () {
                  ref.read(habitsProvider.notifier).toggleHabitCompletion(habit);
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: habit.isDone ? Colors.green : Colors.transparent,
                    border: Border.all(
                      color: habit.isDone ? Colors.green : Colors.grey,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.check,
                    size: 18,
                    color: habit.isDone ? Colors.white : Colors.transparent,
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
                        decoration: habit.isDone ? TextDecoration.lineThrough : null,
                        color: habit.isDone ? Colors.grey : null,
                      ),
                    ),
                    if (habit.description != null && habit.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Description: ${habit.description}',
                          style: TextStyle(
                            fontSize: 14,
                            color: habit.isDone ? Colors.grey : Colors.grey[600],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        habit.getFrequencyDescription(),
                        style: TextStyle(
                          fontSize: 12,
                          color: habit.isDone ? Colors.grey : Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
