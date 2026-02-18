import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityStatus {
  final bool isConnected;
  final bool isWiFi;
  final bool isMobile;
  final String? wifiName;
  final String? ipAddress;
  final DateTime lastUpdated;

  ConnectivityStatus({
    required this.isConnected,
    required this.isWiFi,
    required this.isMobile,
    this.wifiName,
    this.ipAddress,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  
  ConnectivityStatus _status = ConnectivityStatus(
    isConnected: false,
    isWiFi: false,
    isMobile: false,
  );

  ConnectivityStatus get status => _status;

  bool get isNetworkAvailable => _status.isConnected && _status.isWiFi;
  bool get isWiFiConnected => _status.isWiFi;
  String? get currentWiFiName => _status.wifiName;
  String? get currentIpAddress => _status.ipAddress;

  Future<void> initialize() async {
    try {
      // Check initial connectivity
      await _checkConnectivity();

      // Listen for connectivity changes
      _connectivity.onConnectivityChanged.listen(
        (result) {
          _handleConnectivityChange(result);
        },
      );

      print('✅ Connectivity service initialized');
    } catch (e) {
      print('❌ Failed to initialize connectivity: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(result);
    } catch (e) {
      print('❌ Error checking connectivity: $e');
    }
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    try {
      bool isConnected = result != ConnectivityResult.none;
      bool isWiFi = result == ConnectivityResult.wifi;
      bool isMobile = result == ConnectivityResult.mobile;

      String? wifiName;
      String? ipAddress;

      if (isWiFi && !kIsWeb) {
        // Network info not available on web
        try {
          // Would use NetworkInfoPlus here on mobile/desktop
          wifiName = null;
          ipAddress = null;
        } catch (e) {
          print('⚠️ Failed to get WiFi info: $e');
        }
      }

      _status = ConnectivityStatus(
        isConnected: isConnected,
        isWiFi: isWiFi,
        isMobile: isMobile,
        wifiName: wifiName?.replaceAll('"', ''),
        ipAddress: ipAddress,
      );

      notifyListeners();

      _logStatus();
    } catch (e) {
      print('❌ Error handling connectivity change: $e');
    }
  }

  void _logStatus() {
    if (_status.isWiFi) {
      print('📡 WiFi Connected');
      print('   Network: ${_status.wifiName}');
      print('   IP: ${_status.ipAddress}');
    } else if (_status.isMobile) {
      print('📱 Mobile data connected');
    } else {
      print('❌ No network connection');
    }
  }

  Future<bool> waitForWiFi({Duration timeout = const Duration(seconds: 10)}) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      if (isWiFiConnected) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkConnectivity();
    }

    print('⏱️ WiFi connection timeout');
    return false;
  }

  // Check if on same network (simple check - same WiFi SSID)
  Future<bool> isOnSameNetwork(String? otherWiFiName) async {
    if (currentWiFiName == null || otherWiFiName == null) {
      return false;
    }
    return currentWiFiName == otherWiFiName;
  }
}
