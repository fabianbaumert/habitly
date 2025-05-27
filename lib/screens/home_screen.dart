import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/screens/habit_detail_screen.dart';
import 'package:habitly/screens/habit_form_screen.dart';
import 'package:habitly/widgets/habit_card.dart';

class HomeScreen extends ConsumerWidget {
  final bool showDrawer;
  
  const HomeScreen({
    super.key, 
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
      ),
      body: habitsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Text('Error loading habits: $error'),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No habits yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first habit to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HabitFormScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create a new habit'),
                  ),
                ],
              ),
            );
          }

          // Sort habits by createdAt descending (newest first)
          final sortedHabits = [...habits]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed the 'Your Habits' sub-headline
              Expanded(
                child: ListView.builder(
                  itemCount: sortedHabits.length,
                  itemBuilder: (context, index) {
                    final habit = sortedHabits[index];
                    return InkWell(
                      onTap: () {
                        // Navigate to habit detail screen when tapped
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HabitDetailScreen(habit: habit),
                          ),
                        );
                      },
                      child: HabitCard(habit: habit, showCheckbox: false),
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