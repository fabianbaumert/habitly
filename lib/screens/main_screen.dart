import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/screens/calendar_screen.dart';
import 'package:habitly/screens/feedback_screen.dart';
import 'package:habitly/screens/habit_form_screen.dart'; // Import for habit form
import 'package:habitly/screens/home_screen.dart';
import 'package:habitly/screens/settings_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current screen from navigation provider
    final currentScreen = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);
    
    // Return the current screen based on navigation state
    Widget _getCurrentScreen() {
      switch (currentScreen) {
        case NavigationScreen.home:
          return const HomeScreen(showDrawer: false);
        case NavigationScreen.calendar:
          return const CalendarScreen(showDrawer: false);
        case NavigationScreen.feedback:
          return const FeedbackScreen(showDrawer: false);
        case NavigationScreen.settings:
          return const SettingsScreen(showDrawer: false);
        default:
          return const HomeScreen(showDrawer: false);
      }
    }
    
    return Scaffold(
      body: _getCurrentScreen(),
      floatingActionButton: _buildFloatingActionButton(context, currentScreen),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getNavigationIndex(currentScreen),
        onTap: (index) => _onNavigationTapped(index, notifier),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
  
  // Convert navigation screen to bottom navigation index
  int _getNavigationIndex(NavigationScreen screen) {
    switch (screen) {
      case NavigationScreen.home:
        return 0;
      case NavigationScreen.calendar:
        return 1;
      case NavigationScreen.feedback:
        return 2;
      case NavigationScreen.settings:
        return 3;
      default:
        return 0;
    }
  }
  
  // Handle bottom navigation tap
  void _onNavigationTapped(int index, NavigationNotifier notifier) {
    switch (index) {
      case 0:
        notifier.setScreen(NavigationScreen.home);
        break;
      case 1:
        notifier.setScreen(NavigationScreen.calendar);
        break;
      case 2:
        notifier.setScreen(NavigationScreen.feedback);
        break;
      case 3:
        notifier.setScreen(NavigationScreen.settings);
        break;
    }
  }
  
  // Build the floating action button (only on home screen)
  Widget? _buildFloatingActionButton(BuildContext context, NavigationScreen currentScreen) {
    // Only show the "Add Habit" button on the Home screen
    if (currentScreen == NavigationScreen.home) {
      return FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HabitFormScreen(),
            ),
          );
        },
        tooltip: 'Add New Habit',
        child: const Icon(Icons.add),
      );
    }
    
    // No FAB on other screens
    return null;
  }
}