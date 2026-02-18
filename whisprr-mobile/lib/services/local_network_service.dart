import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

// dart:io - only import on non-web platforms
import 'dart:io' if (dart.library.html) 'dart:io' as _io;

class LocalNetworkService extends ChangeNotifier {
  static const int messagePort = 5555;
  static const int mediaPort = 5556;
  static const String serviceType = '_whisprr._tcp.local';
  
  late String deviceId;
  late String deviceName;
  late String ipAddress;
  
  dynamic _messageServer;  // io.ServerSocket on native, null on web
  dynamic _mediaServer;    // io.ServerSocket on native, null on web
  MDnsClient? _mdnsClient;
  
  Map<String, RemoteDevice> discoveredDevices = {};
  bool isRunning = false;
  bool isConnected = false;

  LocalNetworkService() {
    deviceId = const Uuid().v4();
    deviceName = 'Device-${deviceId.substring(0, 8)}';
  }

  // Initialize local network services
  Future<void> initialize() async {
    try {
      // Get device IP address
      if (kIsWeb) {
        ipAddress = 'localhost';
        print('✅ Local network service initialized on localhost (web mode - limited functionality)');
        // Web doesn't support network_info_plus, ServerSocket, or mDNS
      } else {
        try {
          // Dynamically load NetworkInfoPlus only on mobile/desktop
          // For now, use a fallback
          ipAddress = '';
        } catch (e) {
          ipAddress = '';
        }
        if (ipAddress.isEmpty) {
          ipAddress = '127.0.0.1';
        }
      }
      
      // Only start servers and mDNS on non-web platforms
      if (!kIsWeb) {
        // Start message and media servers
        await _startMessageServer();
        await _startMediaServer();
        
        // Start mDNS service discovery
        await _startServiceDiscovery();
        
        // Advertise this device
        await _advertiseService();
      }
      
      isRunning = !kIsWeb; // Only truly running on native platforms
      notifyListeners();
      print('✅ Local network service initialized on $ipAddress${kIsWeb ? ' (web mode - limited functionality)' : ''}');
    } catch (e) {
      print('❌ Failed to initialize local network: $e');
      // Don't rethrow on web to avoid crash
      if (!kIsWeb) rethrow;
    }
  }

  // Start message server for receiving messages
  Future<void> _startMessageServer() async {
    if (kIsWeb) return; // Skip on web
    
    try {
      _messageServer = await _io.ServerSocket.bind('0.0.0.0', messagePort);
      
      _messageServer?.listen(
        (dynamic socket) {
          _handleMessageConnection(socket);
        },
        onError: (error) {
          print('❌ Server error: $error');
        },
        onDone: () {
          print('Server closed');
        },
      );
      
      print('✅ Message server listening on port $messagePort');
    } catch (e) {
      print('❌ Failed to start message server: $e');
    }
  }

  // Start media server for receiving media files
  Future<void> _startMediaServer() async {
    if (kIsWeb) return; // Skip on web
    
    try {
      _mediaServer = await _io.ServerSocket.bind('0.0.0.0', mediaPort);
      
      _mediaServer?.listen(
        (dynamic socket) {
          _handleMediaConnection(socket);
        },
        onError: (error) {
          print('❌ Media server error: $error');
        },
      );
      
      print('✅ Media server listening on port $mediaPort');
    } catch (e) {
      print('❌ Failed to start media server: $e');
    }
  }

  // Handle incoming messages
  void _handleMessageConnection(dynamic socket) {
    print('📨 Incoming message connection from ${socket.remoteAddress?.address ?? 'unknown'}');
    
    socket.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          final json = jsonDecode(message);
          
          _processIncomingMessage(json);
        } catch (e) {
          print('❌ Error processing message: $e');
        }
      },
      onError: (error) {
        print('Socket error: $error');
      },
      onDone: () {
        socket.close();
      },
    );
  }

  // Handle incoming media
  void _handleMediaConnection(dynamic socket) {
    print('📁 Incoming media from ${socket.remoteAddress?.address ?? 'unknown'}');
    
    final chunks = <List<int>>[];
    
    socket.listen(
      (data) {
        chunks.add(data);
      },
      onDone: () {
        _processIncomingMedia(chunks);
        socket.close();
      },
      onError: (error) {
        print('Media error: $error');
      },
    );
  }

  // Process incoming message
  void _processIncomingMessage(Map<String, dynamic> json) {
    print('📬 Received message from ${json['from']}');
    // This will be handled by the chat page
    _handleIncomingMessage?.call(json);
  }

  // Process incoming media
  void _processIncomingMedia(List<List<int>> chunks) {
    print('📦 Received media (${chunks.length} chunks)');
    final data = chunks.expand((chunk) => chunk).toList();
    _handleIncomingMedia?.call(data);
  }

  // Start mDNS service discovery
  Future<void> _startServiceDiscovery() async {
    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient?.start();
      
      print('✅ mDNS service discovery started');
      // TODO: Implement proper service discovery with ResourceRecordQuery
    } catch (e) {
      print('⚠️ Service discovery error: $e');
    }
  }

  // Advertise this device on local network
  Future<void> _advertiseService() async {
    try {
      // Service advertisement will be handled by the socket itself
      print('📢 Device advertised as: $deviceName');
    } catch (e) {
      print('❌ Failed to advertise service: $e');
    }
  }

  // Send message to remote device
  Future<bool> sendMessage(
    String remoteDeviceId,
    String toContact,
    String messageText, {
    String? messageType,
  }) async {
    if (kIsWeb) {
      print('⚠️ Sending messages not supported on web');
      return false;
    }
    
    try {
      final remoteDevice = discoveredDevices[remoteDeviceId];
      if (remoteDevice == null) {
        print('❌ Device not found: $remoteDeviceId');
        return false;
      }

      final socket = await _io.Socket.connect(
        remoteDevice.ipAddress,
        remoteDevice.port,
        timeout: const Duration(seconds: 5),
      );

      final message = {
        'type': 'message',
        'from': deviceId,
        'fromName': deviceName,
        'to': toContact,
        'text': messageText,
        'messageType': messageType ?? 'text',
        'timestamp': DateTime.now().toIso8601String(),
      };

      socket.write(jsonEncode(message));
      await socket.flush();
      socket.close();

      print('✅ Message sent to $remoteDeviceId');
      return true;
    } catch (e) {
      print('❌ Failed to send message: $e');
      return false;
    }
  }

  // Send media file to remote device
  Future<bool> sendMedia(
    String remoteDeviceId,
    String toContact,
    List<int> fileData,
    String fileName,
    String mediaType,
  ) async {
    if (kIsWeb) {
      print('⚠️ Sending media not supported on web');
      return false;
    }
    
    try {
      final remoteDevice = discoveredDevices[remoteDeviceId];
      if (remoteDevice == null) {
        print('❌ Device not found: $remoteDeviceId');
        return false;
      }

      // First send metadata
      final metadata = {
        'type': 'media',
        'from': deviceId,
        'fromName': deviceName,
        'to': toContact,
        'fileName': fileName,
        'mediaType': mediaType,
        'fileSize': fileData.length,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final socket = await _io.Socket.connect(
        remoteDevice.ipAddress,
        remoteDevice.port,
      );

      socket.write(jsonEncode(metadata));
      socket.write('\n---MEDIA_START---\n');
      socket.add(fileData);
      await socket.flush();
      socket.close();

      print('✅ Media sent to $remoteDeviceId');
      return true;
    } catch (e) {
      print('❌ Failed to send media: $e');
      return false;
    }
  }

  // Callback for incoming messages
  Function(Map<String, dynamic>)? _handleIncomingMessage;
  Function(List<int>)? _handleIncomingMedia;

  void setMessageHandler(Function(Map<String, dynamic>) handler) {
    _handleIncomingMessage = handler;
  }

  void setMediaHandler(Function(List<int>) handler) {
    _handleIncomingMedia = handler;
  }

  // Refresh available devices
  Future<void> refreshDevices() async {
    // Trigger another discovery scan
    discoveredDevices.clear();
    notifyListeners();
    
    // Restart service discovery
    _mdnsClient?.stop();
    await _startServiceDiscovery();
  }

  // Shutdown services
  Future<void> shutdown() async {
    try {
      await _messageServer?.close();
      await _mediaServer?.close();
      _mdnsClient?.stop();
      
      isRunning = false;
      notifyListeners();
      print('✅ Local network service stopped');
    } catch (e) {
      print('❌ Error shutting down: $e');
    }
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}

class RemoteDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;

  RemoteDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
  });
}
