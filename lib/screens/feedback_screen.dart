import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/feedback_provider.dart';
import 'package:habitly/providers/navigation_provider.dart';
import 'package:habitly/services/logger_service.dart';
import 'package:habitly/widgets/app_drawer.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    // Reset feedback submission state when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedbackSubmissionStateProvider.notifier).state = FeedbackSubmissionState.initial;
    });
  }
  
  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set the current screen in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationProvider.notifier).setScreen(NavigationScreen.feedback);
    });

    // Get current feedback submission state
    final submissionState = ref.watch(feedbackSubmissionStateProvider);
  
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Feedback'),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'We value your feedback!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please share your thoughts, suggestions, or report any issues you encountered while using Habitly.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _feedbackController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter your feedback here...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter some feedback';
                  }
                  if (value.trim().length < 5) {
                    return 'Feedback must be at least 5 characters';
                  }
                  return null;
                },
                enabled: submissionState != FeedbackSubmissionState.submitting,
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(submissionState),
              if (submissionState == FeedbackSubmissionState.success)
                _buildSuccessMessage(),
              if (submissionState == FeedbackSubmissionState.error)
                _buildErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(FeedbackSubmissionState state) {
    return ElevatedButton(
      onPressed: state == FeedbackSubmissionState.submitting
          ? null
          : _submitFeedback,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: state == FeedbackSubmissionState.submitting
            ? const CircularProgressIndicator()
            : const Text('Submit Feedback', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Thank you for your feedback! We appreciate your input.',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: const Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Something went wrong. Please try again later.',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    // Validate form
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    appLogger.i('User submitting feedback');
    
    // Get feedback text
    final feedback = _feedbackController.text.trim();
    
    // Submit feedback using the new notifier method
    final success = await ref.read(feedbackSubmissionProvider.notifier).submitFeedback(feedback);
    
    if (success && mounted) {
      // Clear the form if submission was successful
      _feedbackController.clear();
    }
  }
}