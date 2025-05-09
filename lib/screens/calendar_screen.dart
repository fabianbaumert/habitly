import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/widgets/app_drawer.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set the current screen in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setScreen(NavigationScreen.calendar);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Calendar View',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Your habit calendar will be implemented here in Step 9.'),
          ],
        ),
      ),
    );
  }
}