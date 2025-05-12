import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/services/feedback_service.dart';

// Provider for the feedback service
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

// States for feedback submission
enum FeedbackSubmissionState {
  initial,
  submitting,
  success,
  error,
}

// Provider to manage feedback submission state
final feedbackSubmissionStateProvider = StateProvider<FeedbackSubmissionState>(
    (ref) => FeedbackSubmissionState.initial);

// Feedback submission notifier to properly handle async operations
class FeedbackSubmissionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return false; // Initial state
  }

  Future<bool> submitFeedback(String feedback) async {
    // Set state to loading
    ref.read(feedbackSubmissionStateProvider.notifier).state = 
        FeedbackSubmissionState.submitting;
    
    try {
      state = const AsyncValue.loading();
      
      // Get the current user's email
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email;
      
      // Get the feedback service and send feedback
      final feedbackService = ref.read(feedbackServiceProvider);
      appLogger.i('Submitting feedback through FeedbackSubmissionNotifier');
      final result = await feedbackService.sendFeedback(feedback, userEmail);
      
      // Update state based on result
      ref.read(feedbackSubmissionStateProvider.notifier).state = 
          result ? FeedbackSubmissionState.success : FeedbackSubmissionState.error;
      
      // Update the AsyncNotifier state
      state = AsyncValue.data(result);
      return result;
    } catch (e) {
      // Log the error
      appLogger.e('Error in FeedbackSubmissionNotifier: $e');
      
      // Update state to error
      ref.read(feedbackSubmissionStateProvider.notifier).state = FeedbackSubmissionState.error;
      
      // Update the AsyncNotifier state with the error
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

// Provider for the FeedbackSubmissionNotifier
final feedbackSubmissionProvider = AsyncNotifierProvider<FeedbackSubmissionNotifier, bool>(
  () => FeedbackSubmissionNotifier(),
);