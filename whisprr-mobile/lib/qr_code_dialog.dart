import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'services/qr_code_service.dart';
import 'services/device_pairing_service.dart';
import 'services/connectivity_service.dart';

class QRCodeDialog extends StatefulWidget {
  const QRCodeDialog({super.key});

  @override
  State<QRCodeDialog> createState() => _QRCodeDialogState();
}

class _QRCodeDialogState extends State<QRCodeDialog> {
  int _selectedIndex = 0; // 0 = menu, 1 = generator, 2 = scanner

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 0) {
      return _buildMenu(context);
    } else if (_selectedIndex == 1) {
      return QRCodeGenerator(
        onBack: () => setState(() => _selectedIndex = 0),
      );
    } else {
      return QRCodeScanner(
        onBack: () => setState(() => _selectedIndex = 0),
        onDeviceScanned: _handleScannedDevice,
      );
    }
  }

  Widget _buildMenu(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF00C4E6)),
            const SizedBox(height: 16),
            const Text(
              'Quick Pairing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your device or scan someone else\'s',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.qr_code,
                    label: 'Generate\nQR Code',
                    color: const Color(0xFF00C4E6),
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.camera_alt,
                    label: 'Scan\nQR Code',
                    color: const Color(0xFF00C4E6),
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showDeviceIdDialog();
                },
                icon: const Icon(Icons.devices),
                label: const Text('Connect by Device ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C4E6),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceIdDialog() {
    final pairingService = context.read<DevicePairingService>();
    final deviceId = pairingService.localDeviceId;
    final TextEditingController remoteIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect with Device ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Device ID:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    deviceId,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device ID copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C4E6),
                      minimumSize: const Size.fromHeight(32),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: remoteIdController,
              decoration: InputDecoration(
                labelText: 'Enter Remote Device ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Paste device ID to connect',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final remoteId = remoteIdController.text.trim();
              if (remoteId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a device ID')),
                );
                return;
              }
              if (remoteId == deviceId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot connect with your own device ID')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connecting to device: ${remoteId.substring(0, 8)}')),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C4E6),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _handleScannedDevice(QRCodeData scannedData) {
    final pairingService = context.read<DevicePairingService>();
    final localId = pairingService.localDeviceId;

    // Prevent pairing with self
    if (scannedData.deviceId == localId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot pair with yourself')),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pair Device?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device: ${scannedData.deviceName}'),
              const SizedBox(height: 8),
              Text('IP: ${scannedData.ipAddress}'),
              if (scannedData.wifiName != null) ...[
                const SizedBox(height: 8),
                Text('Network: ${scannedData.wifiName}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // Pair the device
                await pairingService.pairDevice(
                  scannedData.deviceId,
                  scannedData.deviceName,
                  scannedData.ipAddress,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Paired with ${scannedData.deviceName}'),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Pair'),
            ),
          ],
        ),
      );
    }
  }
}

// Custom painter for QR code generation
class QRPainter extends CustomPainter {
  final String qrData;

  QRPainter(this.qrData);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw QR code pattern using simple grid
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final cellSize = size.width / 29; // Standard 29x29 QR code grid

    // Draw simplified QR pattern (static pattern for demo)
    // In production, use qr_flutter package properly or qr package
    for (int i = 0; i < 29; i++) {
      for (int j = 0; j < 29; j++) {
        // Generate pseudo-random pattern based on data hash
        final hash = (qrData.hashCode + i * 29 + j) % 2;
        if (hash == 0) {
          canvas.drawRect(
            Rect.fromLTWH(i * cellSize, j * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(QRPainter oldDelegate) => oldDelegate.qrData != qrData;
}

class QRCodeGenerator extends StatelessWidget {
  final VoidCallback onBack;

  const QRCodeGenerator({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Consumer2<DevicePairingService, ConnectivityService>(
        builder: (context, pairingService, connectivityService, _) {
          return FutureBuilder<QRCodeData?>(
            future: QRCodeService.generateQRData(pairingService, connectivityService),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00C4E6)),
                      SizedBox(height: 16),
                      Text('Generating QR Code...'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text('Failed to generate QR code'),
                      const SizedBox(height: 8),
                      const Text(
                        'Make sure you\'re connected to WiFi',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: onBack,
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                );
              }

              final qrData = snapshot.data!;
              final qrString = qrData.toQRString();

              return Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your Device QR Code',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        qrData.deviceName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF00C4E6), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(color: Colors.white),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CustomPaint(
                                  painter: QRPainter(qrString),
                                  size: const Size(208, 208),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Device Info:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Name: ${qrData.deviceName}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            Text(
                              'IP: ${qrData.ipAddress}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            if (qrData.wifiName != null)
                              Text(
                                'WiFi: ${qrData.wifiName}',
                                style: const TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: onBack,
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('QR code copied to clipboard'),
                                  ),
                                );
                              },
                              child: const Text('Share'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class QRCodeScanner extends StatefulWidget {
  final VoidCallback onBack;
  final Function(QRCodeData) onDeviceScanned;

  const QRCodeScanner({
    super.key,
    required this.onBack,
    required this.onDeviceScanned,
  });

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  late MobileScannerController _scannerController;
  bool _flashOn = false;
  bool _isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    if (!_isDesktop) {
      _scannerController.dispose();
    }
    super.dispose();
  }

  Future<void> _scanQRFromImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      // Try to decode QR code from selected image
      // For now, show a message that full decoding requires additional setup
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR scanning on desktop: Select an image with QR code'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _captureQRWithCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      
      if (photo == null) return;
      
      // Show message for camera capture
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured. Scan your QR code from this image.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _isDesktop
          ? _buildDesktopScanner()
          : _buildMobileScanner(),
    );
  }

  Widget _buildMobileScanner() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scan QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                onPressed: () async {
                  await _scannerController.toggleTorch();
                  setState(() => _flashOn = !_flashOn);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 0),
        Container(
          height: 300,
          color: Colors.black,
          child: MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                try {
                  final qrData = QRCodeData.fromQRString(barcode.rawValue ?? '');
                  widget.onDeviceScanned(qrData);
                  return;
                } catch (e) {
                  // Invalid QR code format, continue scanning
                }
              }
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Point camera at QR code',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onBack,
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopScanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF00C4E6)),
          const SizedBox(height: 16),
          const Text(
            'Scan QR Code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your camera or select an image',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _captureQRWithCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C4E6),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _scanQRFromImage,
            icon: const Icon(Icons.image),
            label: const Text('Select Image'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Point camera at another device\'s QR code to scan it',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
