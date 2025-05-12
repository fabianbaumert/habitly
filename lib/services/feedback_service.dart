import 'package:dio/dio.dart';
import 'package:habitly/services/logger_service.dart';

class FeedbackService {
  final Dio _dio = Dio();
  
  // JSONPlaceholder provides a free mock API service that works with POST requests
  final String _mockApiUrl = 'https://jsonplaceholder.typicode.com/posts';
  
  // Send feedback to the mock API
  Future<bool> sendFeedback(String feedback, String? userEmail) async {
    try {
      appLogger.i('Sending feedback to JSONPlaceholder mock API');
      
      // Create the request payload
      final Map<String, dynamic> data = {
        'title': 'Feedback from ${userEmail ?? 'anonymous user'}',
        'body': feedback,
        'userId': userEmail != null ? userEmail.hashCode % 10 + 1 : 1, // JSONPlaceholder expects userId 1-10
      };
      
      // Make actual POST request to JSONPlaceholder
      final response = await _dio.post(_mockApiUrl, data: data);
      
      // JSONPlaceholder returns status 201 for successful creation
      if (response.statusCode == 201) {
        appLogger.i('Feedback sent successfully to mock API with id: ${response.data['id']}');
        return true;
      } else {
        appLogger.w('Unexpected response from mock API: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      appLogger.e('Error sending feedback: $e');
      return false;
    }
  }
}