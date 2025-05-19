import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/screens/calendar_screen.dart';
import 'package:habitly/screens/debug_screen.dart'; // Import for debug screen
import 'package:habitly/screens/feedback_screen.dart';
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
      floatingActionButton: kDebugMode ? FloatingActionButton(
        onPressed: () {
          // Navigate to the debug screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DebugScreen()),
          );
        },
        mini: true,
        tooltip: 'Debug Menu',
        child: const Icon(Icons.bug_report),
      ) : null,
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
}