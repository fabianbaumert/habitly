import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/widgets/app_drawer.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set the current screen in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setScreen(NavigationScreen.feedback);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Feedback',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Feedback form will be implemented here in Step 10.'),
          ],
        ),
      ),
    );
  }
}