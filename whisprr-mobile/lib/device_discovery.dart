import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/local_network_service.dart';
import 'services/device_pairing_service.dart';
import 'services/connectivity_service.dart';

class DeviceDiscoverySheet extends StatefulWidget {
  const DeviceDiscoverySheet({super.key});

  @override
  State<DeviceDiscoverySheet> createState() => _DeviceDiscoverySheetState();
}

class _DeviceDiscoverySheetState extends State<DeviceDiscoverySheet> {
  late LocalNetworkService _networkService;
  late DevicePairingService _pairingService;

  @override
  void initState() {
    super.initState();
    _networkService = context.read<LocalNetworkService>();
    _pairingService = context.read<DevicePairingService>();
    _refreshDevices();
  }

  void _refreshDevices() async {
    await _networkService.refreshDevices();
  }

  void _pairDevice(String deviceId, String deviceName, String ipAddress) async {
    await _pairingService.pairDevice(deviceId, deviceName, ipAddress);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paired with $deviceName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocalNetworkService, ConnectivityService>(
      builder: (context, networkService, connectivity, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discover Devices',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshDevices,
                    ),
                  ],
                ),
              ),
              
              // Connection Status
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: connectivity.isWiFiConnected ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      connectivity.isWiFiConnected ? Icons.wifi : Icons.wifi_off,
                      color: connectivity.isWiFiConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connectivity.isWiFiConnected ? 'WiFi Connected' : 'WiFi Disconnected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            connectivity.currentWiFiName ?? 'No WiFi',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Available Devices List
              Expanded(
                child: networkService.discoveredDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No devices found'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _refreshDevices,
                              child: const Text('Scan Again'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: networkService.discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final deviceName = networkService.discoveredDevices.keys.elementAt(index);
                          final device = networkService.discoveredDevices[deviceName]!;
                          final isPaired = _pairingService.getPairedDevice(device.id) != null;

                          return ListTile(
                            leading: Icon(
                              Icons.smartphone,
                              color: isPaired ? Colors.green : Colors.grey,
                            ),
                            title: Text(deviceName),
                            subtitle: Text(device.ipAddress),
                            trailing: isPaired
                                ? const Chip(
                                    label: Text('Paired'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _pairDevice(
                                      device.id,
                                      deviceName,
                                      device.ipAddress,
                                    ),
                                    child: const Text('Pair'),
                                  ),
                          );
                        },
                      ),
              ),

              // Bottom action
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                        ),
                        child: const Text('Close', style: TextStyle(color: Colors.black)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Device settings dialog
class DeviceSettingsDialog extends StatefulWidget {
  const DeviceSettingsDialog({super.key});

  @override
  State<DeviceSettingsDialog> createState() => _DeviceSettingsDialogState();
}

class _DeviceSettingsDialogState extends State<DeviceSettingsDialog> {
  late TextEditingController _nameController;
  late DevicePairingService _pairingService;

  @override
  void initState() {
    super.initState();
    _pairingService = context.read<DevicePairingService>();
    _nameController = TextEditingController(text: _pairingService.localDeviceName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Device Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Device ID: ${_pairingService.localDeviceId.substring(0, 8)}...',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            _pairingService.setLocalDeviceName(_nameController.text);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device name updated')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
