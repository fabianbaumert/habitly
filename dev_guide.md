# 📱 Habitly Dev Guide (with GitHub Copilot Agent)

This document contains a structured list of prompts and implementation steps for building the Habitly mobile app (habit tracker) using Flutter, Firebase, Hive, Riverpod, Dio, and GitHub Copilot Agent.

---

Keep this in mind for every Step:
- Just do the things mentioned in the steps. dont do something that i didnt mentioned - Just do the things mentioned in the steps and make them work.
- when you write code make it as simple, easy and readable as possible.

---

## DONE ✅ 1. Project Setup: Create Flutter App & Add Dependencies

```
Create a new Flutter project named `habitly` using null safety. Add the following dependencies to `pubspec.yaml`:
- firebase_core, firebase_auth, cloud_firestore, firebase_messaging
- flutter_riverpod
- hive, hive_flutter
- dio
- intl
Also initialize Hive and Firebase properly in the `main.dart` file.
```

---

## DONE ✅ 2. Firebase Initialization

```
Initialize Firebase in the main.dart file. Ensure FirebaseAuth, Firestore, and Firebase Cloud Messaging are ready to use. Also initialize Hive and register adapters if needed.
```

---

## DONE ✅ 3. Firebase Authentication (Email)

```
Create a user authentication system using FirebaseAuth with the following options:
- Email/password login and registration
- NO google or apple sign in
Use Riverpod to manage the auth state and redirect users to the home screen after successful login.
```

---

## DONE ✅ 4. Drawer Navigation with Main Screens

```
Implement a drawer-based navigation layout with the following pages:
- Home (Habit overview)
- Calendar View
- Feedback
- Settings
Use Flutter's Drawer widget and maintain state via Riverpod.
```

---

## ✅ DONE 5. Global State Management (Riverpod)

```
Create Riverpod providers for the following:
- Firebase user state
- List of habits (fetched from Firestore or Hive)
- App theme (light/dark mode)
- Notification preferences
```

---

## DONE ✅ 6. Habit Creation and Management

```
Create a UI screen for users to add a new habit with:
- Custom habit name
- Daily goal (optional)
- Reminder time (TimeOfDay)
Store the data locally in Hive and sync to Firestore.
```

---

## DONE ✅ 7. Home Screen with Habit Overview

```
Build a home screen that displays a list of current habits.
Each item should show:
- Habit name
- Progress bar or percentage
- Option to mark today's progress
Retrieve data using Riverpod and sync changes with Firebase + Hive.
```

---

## DONE ✅ 8. Habit Detail & Progress View

```
Create a detail view for each habit showing:
- Progress history (daily/weekly overview)
- Option to edit or delete the habit
- A small calendar view with completed days
```

---

## DONE ✅ 9. Calendar View

```
Implement a calendar screen that visually shows daily progress for all habits.
Highlight days where all goals were achieved.
Use a third-party calendar package or build a custom calendar grid.
```

---

## ✅ DONE 10. Feedback Form (with Dio)

```
Create a feedback form screen with a multi-line text field.
When submitted, send the feedback using Dio to a mock API endpoint;
```

---

## ✅ 11. Push Notifications (flutter_local_storage)

```
Enable push notifications with local notifications and the package flutter_local_storage.
Send daily reminders at the user-defined time for each habit.
Ask for notification permissions on first app launch.
dont use firebase messaging.
```

---

## ✅ 12. Offline Support and Auto Sync

```
Store all habit and progress data locally with Hive.
Automatically sync with Firebase when internet becomes available.
If there is a conflict between local and remote, use the most recent data automatically.
```

---

## ✅ 13. Notification Preferences

```
Let users configure the frequency and time of reminders for each habit.
Save this setting in Hive and Firestore, and use it to schedule notifications.
```

---

## ✅ 14. Theming and User Preferences

```
Allow toggling between light and dark theme in the Settings screen.
Save the selected theme in Hive and manage it with Riverpod.
```

---

## ✅ 15. Final Polish: Add App Icon, Splash Screen, Clean Up Code

```
Add a custom app icon and splash screen for both iOS and Android using flutter_native_splash and flutter_launcher_icons.
Run flutter analyze and flutter test to check for issues.
```

Additionaly:
- user Logger for logging


---

Happy building! 🚀
