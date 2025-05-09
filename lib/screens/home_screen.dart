import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/widgets/app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    // Set the current screen in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setScreen(NavigationScreen.home);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habitly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Habitly!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Your habits dashboard will appear here.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // This will be implemented in Step 6
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Habit creation will be implemented in Step 6'),
                  ),
                );
              },
              child: const Text('Add New Habit'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Habit creation will be implemented in Step 6'),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Add New Habit',
      ),
    );
  }
}