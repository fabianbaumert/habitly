import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/models/theme_preference.dart';
import 'package:hive/hive.dart';

// Theme state notifier to handle theme changes
class ThemeNotifier extends StateNotifier<ThemePreference> {
  // Initialize with light mode as default
  ThemeNotifier() : super(ThemePreference()) {
    _loadThemePreference();
  }

  // Load saved theme preference from Hive
  Future<void> _loadThemePreference() async {
    try {
      final box = await Hive.openBox('preferences');
      final isDarkMode = box.get('isDarkMode', defaultValue: false);
      state = ThemePreference(isDarkMode: isDarkMode);
    } catch (e) {
      // Fall back to default light theme if there's an error
      state = ThemePreference();
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    try {
      // Update state
      state = state.toggle();
      
      // Save preference to Hive
      final box = await Hive.openBox('preferences');
      await box.put('isDarkMode', state.isDarkMode);
    } catch (e) {
      // Handle any errors saving the preference
      print('Error saving theme preference: $e');
    }
  }
  
  // Set specific theme mode
  Future<void> setDarkMode(bool isDarkMode) async {
    if (state.isDarkMode == isDarkMode) return; // No change needed
    
    try {
      // Update state
      state = ThemePreference(isDarkMode: isDarkMode);
      
      // Save preference to Hive
      final box = await Hive.openBox('preferences');
      await box.put('isDarkMode', isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }
}

// Provider for theme state management
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemePreference>((ref) {
  return ThemeNotifier();
});

// Provider for the actual ThemeData to use in MaterialApp
final appThemeProvider = Provider<ThemeData>((ref) {
  final themePreference = ref.watch(themeProvider);
  
  // Return dark or light theme based on preference
  if (themePreference.isDarkMode) {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.blue,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue,
        secondary: Colors.lightBlue,
      ),
    );
  } else {
    return ThemeData.light().copyWith(
      primaryColor: Colors.blue,
      colorScheme: ColorScheme.light(
        primary: Colors.blue,
        secondary: Colors.lightBlue,
      ),
    );
  }
});