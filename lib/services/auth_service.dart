import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitly/services/logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the current user
  User? get currentUser => _auth.currentUser;

  // Returns auth state changes as a Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      appLogger.i('User signed in: ${result.user?.uid}');
      return result;
    } catch (e) {
      appLogger.e('Login error: $e');
      rethrow; // Propagate the error for handling in the UI
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      appLogger.i('User registered: ${result.user?.uid}');
      return result;
    } catch (e) {
      appLogger.e('Registration error: $e');
      rethrow; // Propagate the error for handling in the UI
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Perform Firebase sign out
      await _auth.signOut();
      appLogger.i('User signed out');
    } catch (e) {
      appLogger.e('Sign out error: $e');
      rethrow;
    }
  }
}