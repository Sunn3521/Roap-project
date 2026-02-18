import 'dart:convert';
import 'device_pairing_service.dart';
import 'connectivity_service.dart';

class QRCodeData {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final String? wifiName;
  final DateTime generatedAt;

  QRCodeData({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    this.wifiName,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  // Convert to JSON string for QR code
  String toQRString() {
    return jsonEncode({
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ipAddress': ipAddress,
      'wifiName': wifiName,
      'timestamp': generatedAt.toIso8601String(),
    });
  }

  // Parse QR string back to object
  factory QRCodeData.fromQRString(String qrString) {
    try {
      final json = jsonDecode(qrString) as Map<String, dynamic>;
      return QRCodeData(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        ipAddress: json['ipAddress'] as String,
        wifiName: json['wifiName'] as String?,
        generatedAt: DateTime.parse(json['timestamp'] as String),
      );
    } catch (e) {
      throw FormatException('Invalid QR code data: $e');
    }
  }

  @override
  String toString() => 'Device: $deviceName ($deviceId) @ $ipAddress';
}

class QRCodeService {
  static Future<QRCodeData?> generateQRData(
    DevicePairingService pairingService,
    ConnectivityService connectivityService,
  ) async {
    try {
      // Get current device info
      final deviceId = pairingService.localDeviceId;
      final deviceName = pairingService.localDeviceName;
      final ipAddress = connectivityService.currentIpAddress ?? '0.0.0.0';
      final wifiName = connectivityService.currentWiFiName;

      if (!connectivityService.isWiFiConnected) {
        print('⚠️ Not connected to WiFi');
        return null;
      }

      return QRCodeData(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        wifiName: wifiName,
      );
    } catch (e) {
      print('❌ Error generating QR data: $e');
      return null;
    }
  }

  static bool validateQRData(String qrString) {
    try {
      QRCodeData.fromQRString(qrString);
      return true;
    } catch (e) {
      print('❌ Invalid QR code: $e');
      return false;
    }
  }
}
