# 📱 Habitly – Habit Tracker App

**Habitly** is a minimalistic and clean mobile app that helps users build and maintain positive habits. Built with Flutter for both **iOS** and **Android**, it provides features like habit tracking, completion overviews, and feedback submission – all powered by modern tools like Firebase, Riverpod, Hive and Dio.

---

## 🎬 Demo

👉 Watch a demo of the app in action: [YouTube Video](https://www.youtube.com/watch?v=9Bt1FFMwBes)
[![Habitly App Demo](https://img.youtube.com/vi/9Bt1FFMwBes/0.jpg)](https://www.youtube.com/watch?v=9Bt1FFMwBes)

---

## ✨ Features

- ✅ Create and track custom habits
- 📊 View daily/weekly/monthly completion overviews
- 📝 Submit feedback directly through the app (currently uses JSONPlaceholder API)
- 🌐 Works offline with local sync using Hive
- 🎯 Clean, minimal design with bottom navigation
- ☁️ Full integration with Firebase (Auth, Firestore)

---

## 🛠️ Tech Stack

- **Flutter** – Cross-platform app development
- **Firebase** – Auth, Firestore
- **Riverpod** – State management
- **Hive** – Lightweight local storage
- **Dio** – HTTP client for feedback
- **Flutter Launcher Icons** / **Splash** – App branding

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK
- Firebase CLI (for setup)
- VS Code / Android Studio / Xcode

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/habitly.git
   cd habitly
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   This project requires Firebase for authentication and data storage. The repository includes placeholder files that you need to replace with your own Firebase configuration:
   
   a. Create a new Firebase project at [firebase.google.com](https://firebase.google.com)
   
   b. Add Android and iOS apps to your Firebase project with the package name `com.example.habitly` (or your custom package name)
   
   c. Download the config files and replace the placeholders:
   
   - Copy `google-services.json` to `android/app/`
   - Copy `GoogleService-Info.plist` to `ios/Runner/`
   - Copy `firebase.json` to the project root (or update based on `firebase.placeholder.json`)
   - Copy `.firebaserc` to the project root (or update based on `.firebaserc.placeholder`)
   - Update `lib/firebase_options.dart` with your Firebase configuration
   
   You can use the provided `.placeholder` files as templates for the required format.
   
   d. Enable Firebase Authentication and Firestore in your Firebase project

4. **Run the app**
   ```bash
   flutter run
   ```

---
