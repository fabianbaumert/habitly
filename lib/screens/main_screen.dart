import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/screens/calendar_screen.dart';
import 'package:habitly/screens/feedback_screen.dart';
import 'package:habitly/screens/habit_form_screen.dart'; // Import for habit form
import 'package:habitly/screens/home_screen.dart';
import 'package:habitly/screens/today_screen.dart';
import 'package:habitly/screens/account_screen.dart';

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
        case NavigationScreen.today:
          return const TodayScreen(showDrawer: false);
        case NavigationScreen.calendar:
          return const CalendarScreen(showDrawer: false);
        case NavigationScreen.feedback:
          // Feedback is now accessed via Account, but still handle it if deep linked
          return const FeedbackScreen(showDrawer: false);
        case NavigationScreen.account:
          return const AccountScreen(showDrawer: false);
        default:
          return const HomeScreen(showDrawer: false);
      }
    }
    
    return Scaffold(
      body: _getCurrentScreen(),
      floatingActionButton: _buildFloatingActionButton(context, currentScreen),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getNavigationIndex(currentScreen),
        onTap: (index) => _onNavigationTapped(index, notifier),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
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
      case NavigationScreen.today:
        return 1;
      case NavigationScreen.calendar:
        return 2;
      case NavigationScreen.account:
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
        notifier.setScreen(NavigationScreen.today);
        break;
      case 2:
        notifier.setScreen(NavigationScreen.calendar);
        break;
      case 3:
        notifier.setScreen(NavigationScreen.account);
        break;
    }
  }
  
  // Build the floating action button (only on Home and Today screens)
  Widget? _buildFloatingActionButton(BuildContext context, NavigationScreen currentScreen) {
    // Show the "Add Habit" button on the Home and Today screens
    if (currentScreen == NavigationScreen.home || currentScreen == NavigationScreen.today) {
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