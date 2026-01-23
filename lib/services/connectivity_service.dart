import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor internet connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Stream controller for broadcasting connectivity changes
  final _connectivityController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Stream of connectivity status (true = connected, false = disconnected)
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity status
    await checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _updateConnectivityStatus(result);
      },
    );
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);
      return _isConnected;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  /// Update connectivity status based on results
  void _updateConnectivityStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    
    // Check if result indicates connectivity
    _isConnected = result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;

    // Broadcast status change
    if (wasConnected != _isConnected) {
      _connectivityController.add(_isConnected);
      
      if (_isConnected) {
        print('📶 Internet connection restored');
      } else {
        print('📵 Internet connection lost');
      }
    }
  }

  /// Get detailed connectivity information
  Future<String> getConnectivityType() async {
    final result = await _connectivity.checkConnectivity();
    
    if (result == ConnectivityResult.none) {
      return 'No Connection';
    } else if (result == ConnectivityResult.wifi) {
      return 'WiFi';
    } else if (result == ConnectivityResult.mobile) {
      return 'Mobile Data';
    } else if (result == ConnectivityResult.ethernet) {
      return 'Ethernet';
    } else if (result == ConnectivityResult.vpn) {
      return 'VPN';
    } else if (result == ConnectivityResult.bluetooth) {
      return 'Bluetooth';
    } else {
      return 'Other';
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
