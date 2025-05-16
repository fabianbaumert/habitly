import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/services/logger_service.dart';

enum NetworkStatus {
  online,
  offline,
}

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();
  // Use dynamic type for the subscription to handle any result type
  StreamSubscription? _subscription;

  Stream<NetworkStatus> get status => _controller.stream;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    await _checkConnection();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (dynamic result) {
        if (result is ConnectivityResult) {
          // Handle as a single value
          if (result == ConnectivityResult.none) {
            _controller.sink.add(NetworkStatus.offline);
            appLogger.i('Connection status: Offline');
          } else {
            _controller.sink.add(NetworkStatus.online);
            appLogger.i('Connection status: Online');
          }
        } else if (result is List) {
          // Handle as a list - use the first connectivity result if available
          final status = result.isNotEmpty && 
              result.first is ConnectivityResult && 
              result.first != ConnectivityResult.none
                ? NetworkStatus.online
                : NetworkStatus.offline;
          _controller.sink.add(status);
          appLogger.i('Connection status: ${status == NetworkStatus.online ? "Online" : "Offline"}');
        }
      },
    );
  }

  Future<void> _checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        _controller.sink.add(NetworkStatus.offline);
        appLogger.i('Initial connection status: Offline');
      } else {
        _controller.sink.add(NetworkStatus.online);
        appLogger.i('Initial connection status: Online');
      }
    } catch (e) {
      appLogger.e('Error checking network connectivity: $e');
      _controller.sink.add(NetworkStatus.offline);
    }
  }

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<NetworkStatus> getNetworkStatus() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.none 
        ? NetworkStatus.offline 
        : NetworkStatus.online;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

// Provider for the connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for the current network status
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.status;
});

// Provider to check if device is online
final isOnlineProvider = Provider<bool>((ref) {
  final networkStatusAsync = ref.watch(networkStatusProvider);
  return networkStatusAsync.when(
    data: (status) => status == NetworkStatus.online,
    loading: () => true, // Optimistically assume online while loading
    error: (_, __) => false,
  );
});
