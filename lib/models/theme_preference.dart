// Simple model to represent theme preference
class ThemePreference {
  final bool isDarkMode;

  ThemePreference({this.isDarkMode = false});

  // Method to toggle between light and dark mode
  ThemePreference toggle() {
    return ThemePreference(isDarkMode: !isDarkMode);
  }
}