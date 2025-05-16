import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/screens/calendar_screen.dart';
import 'package:habitly/screens/debug_screen.dart';
import 'package:habitly/screens/feedback_screen.dart';
import 'package:habitly/screens/home_screen.dart';
import 'package:habitly/screens/settings_screen.dart';
import 'package:flutter/foundation.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScreen = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Habitly',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Build better habits',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            selected: currentScreen == NavigationScreen.home,
            onTap: () {
              notifier.setScreen(NavigationScreen.home);
              _navigateTo(context, const HomeScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendar'),
            selected: currentScreen == NavigationScreen.calendar,
            onTap: () {
              notifier.setScreen(NavigationScreen.calendar);
              _navigateTo(context, const CalendarScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Feedback'),
            selected: currentScreen == NavigationScreen.feedback,
            onTap: () {
              notifier.setScreen(NavigationScreen.feedback);
              _navigateTo(context, const FeedbackScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            selected: currentScreen == NavigationScreen.settings,
            onTap: () {
              notifier.setScreen(NavigationScreen.settings);
              _navigateTo(context, const SettingsScreen());
            },
          ),
          // Only show the Debug option in debug mode
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Debug'),
              subtitle: const Text('Developer Options'),
              selected: currentScreen == NavigationScreen.debug,
              onTap: () {
                // No need to set the navigation state since this is a temporary screen
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const DebugScreen())
                );
              },
            ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    // Close the drawer
    Navigator.pop(context);
    
    // Navigate to the selected screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}