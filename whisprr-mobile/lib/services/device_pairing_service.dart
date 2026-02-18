import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class PairedDevice {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  bool isOnline;
  DateTime lastSeen;

  PairedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    this.isOnline = false,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'ipAddress': ipAddress,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
    deviceId: json['deviceId'] as String,
    deviceName: json['deviceName'] as String,
    ipAddress: json['ipAddress'] as String,
    lastSeen: DateTime.parse(json['lastSeen'] as String? ?? DateTime.now().toIso8601String()),
  );
}

class DevicePairingService extends ChangeNotifier {
  static const String _pairedDevicesKey = 'paired_devices';
  static const String _deviceNameKey = 'device_name';
  static const String _deviceIdKey = 'device_id';
  
  late SharedPreferences _prefs;
  late String _localDeviceId;
  late String _localDeviceName;
  
  List<PairedDevice> pairedDevices = [];
  bool isInitialized = false;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Get or create device ID
      _localDeviceId = _prefs.getString(_deviceIdKey) ?? const Uuid().v4();
      await _prefs.setString(_deviceIdKey, _localDeviceId);
      
      // Get or set device name
      _localDeviceName = _prefs.getString(_deviceNameKey) ?? 'Device-${_localDeviceId.substring(0, 8)}';
      
      // Load paired devices
      _loadPairedDevices();
      
      isInitialized = true;
      notifyListeners();
      print('✅ Device pairing service initialized');
    } catch (e) {
      print('❌ Failed to initialize pairing service: $e');
      rethrow;
    }
  }

  String get localDeviceId => _localDeviceId;
  String get localDeviceName => _localDeviceName;

  // Load paired devices from storage
  void _loadPairedDevices() {
    try {
      final json = _prefs.getString(_pairedDevicesKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        pairedDevices = list
            .map((item) => PairedDevice.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      print('✅ Loaded ${pairedDevices.length} paired devices');
    } catch (e) {
      print('⚠️ Error loading paired devices: $e');
      pairedDevices = [];
    }
  }

  // Save paired devices to storage
  Future<void> _savePairedDevices() async {
    try {
      final json = jsonEncode(pairedDevices.map((d) => d.toJson()).toList());
      await _prefs.setString(_pairedDevicesKey, json);
    } catch (e) {
      print('❌ Error saving paired devices: $e');
    }
  }

  // Add new paired device
  Future<void> pairDevice(String deviceId, String deviceName, String ipAddress) async {
    try {
      // Check if already paired
      if (pairedDevices.any((d) => d.deviceId == deviceId)) {
        print('⚠️ Device already paired: $deviceId');
        return;
      }

      final device = PairedDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        isOnline: true,
      );

      pairedDevices.add(device);
      await _savePairedDevices();
      notifyListeners();
      print('✅ Device paired: $deviceName ($deviceId)');
    } catch (e) {
      print('❌ Failed to pair device: $e');
    }
  }

  // Remove paired device
  Future<void> unpairDevice(String deviceId) async {
    try {
      pairedDevices.removeWhere((d) => d.deviceId == deviceId);
      await _savePairedDevices();
      notifyListeners();
      print('✅ Device unpaired: $deviceId');
    } catch (e) {
      print('❌ Failed to unpair device: $e');
    }
  }

  // Update device online status
  void updateDeviceStatus(String deviceId, bool isOnline) {
    final device = pairedDevices.firstWhere(
      (d) => d.deviceId == deviceId,
      orElse: () => PairedDevice(
        deviceId: deviceId,
        deviceName: 'Unknown',
        ipAddress: '0.0.0.0',
      ),
    );
    
    if (pairedDevices.contains(device)) {
      device.isOnline = isOnline;
      device.lastSeen = DateTime.now();
      notifyListeners();
    }
  }

  // Get paired device by ID
  PairedDevice? getPairedDevice(String deviceId) {
    try {
      return pairedDevices.firstWhere((d) => d.deviceId == deviceId);
    } catch (e) {
      return null;
    }
  }

  // Rename device
  Future<void> setLocalDeviceName(String newName) async {
    try {
      _localDeviceName = newName;
      await _prefs.setString(_deviceNameKey, newName);
      notifyListeners();
      print('✅ Device name changed to: $newName');
    } catch (e) {
      print('❌ Failed to change device name: $e');
    }
  }
}
