import 'package:logger/logger.dart';

/// A service that provides a centralized logger instance for the application.
class LoggerService {
  // Private static instance for singleton pattern
  static final LoggerService _instance = LoggerService._internal();
  
  // Factory constructor to return the singleton instance
  factory LoggerService() => _instance;
  
  // Private constructor for singleton
  LoggerService._internal();
  
  // Logger instance that will be used throughout the app
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to be displayed
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      printTime: true, // Should each log print contain a timestamp
    ),
  );
  
  // Get the logger instance
  Logger get getLogger => logger;
}

// Global access point for the logger
final appLogger = LoggerService().getLogger;