# Copilot Instructions for Habitly

## Project Overview
- **Habitly** is a cross-platform Flutter app for habit tracking, supporting iOS and Android.
- Core features: custom habit creation, completion tracking, feedback submission, offline support with sync, and Firebase integration (Auth, Firestore).
- State management uses **Riverpod**; local storage uses **Hive**; HTTP via **Dio**; logging via **logger**.

## Architecture & Key Patterns
- **lib/models/**: Data models (e.g., `habit.dart` for habits, frequency, user linkage).
- **lib/services/**: App logic and integration:
  - `auth_service.dart`: Firebase Auth wrapper
  - `habit_storage_service.dart`/`habit_history_storage_service.dart`: Hive-based local storage
  - `sync_service.dart`: Handles offline/online sync between Hive and Firestore
  - `feedback_service.dart`: Sends feedback via HTTP (mock API)
  - `logger_service.dart`: Centralized logging
- **lib/providers/**: Riverpod providers for state, navigation, and service access.
- **lib/screens/**: UI screens, routed via a custom navigation provider and bottom navigation bar.
- **lib/widgets/**: Reusable UI components (e.g., habit cards, selectors).

## Data Flow & Sync
- Habits and history are stored locally (Hive) and synced to Firestore when online.
- `SyncService` listens for connectivity changes and triggers sync.
- User authentication state is managed via Riverpod and Firebase Auth.

## Developer Workflows
- **Setup:**
  - Replace placeholder Firebase config files (`google-services.json`, `GoogleService-Info.plist`, etc.) with your own.
  - Run `flutter pub get` to install dependencies.
  - Use `flutter run` to launch the app.
- **Testing:**
  - No custom test runner; use standard Flutter test commands.
- **Debugging:**
  - Logging is centralized via `logger_service.dart` (see `appLogger`).
  - Debug screens/components are available (see `debug_screen.dart`).

## Project Conventions
- All state is managed via Riverpod providers (see `lib/providers/`).
- Navigation is handled by a custom provider (`navigation_provider.dart`) and a bottom navigation bar.
- All persistent data access goes through service classes in `lib/services/`.
- Feedback is sent to a mock API (JSONPlaceholder) for demonstration.
- App initialization (Firebase, Hive, services) is handled in `main.dart` before UI loads.

## Integration Points
- **Firebase:** Auth and Firestore; config required for builds.
- **Hive:** Used for offline/local data; adapters registered in service init.
- **Dio:** Used for HTTP feedback submission.

## Examples
- To add a new screen, create it in `lib/screens/`, add a value to `NavigationScreen` enum, and update the navigation provider and main screen switch.
- To add a new persistent model, define it in `lib/models/`, register a Hive adapter, and update storage/sync services.

---

For more, see `README.md` and service/provider files for implementation details.
