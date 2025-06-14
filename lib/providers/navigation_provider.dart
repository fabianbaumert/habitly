import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavigationScreen {
  home,
  today,
  calendar,
  feedback,
  account,
  debug,
}

class NavigationNotifier extends StateNotifier<NavigationScreen> {
  NavigationNotifier() : super(NavigationScreen.today); // Set initial screen to Today

  void setScreen(NavigationScreen screen) {
    state = screen;
  }
}

final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationScreen>((ref) {
  return NavigationNotifier();
});