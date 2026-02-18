import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// path_provider and dart:io are only available on native platforms
import 'package:path_provider/path_provider.dart' as pp;
import 'dart:io' if (dart.library.html) 'package:splash_screen/src/io_stub.dart' as io;

class LocalMessage {
  final String id;
  final String fromDeviceId;
  final String fromDeviceName;
  final String toContact;
  final String text;
  final String messageType;
  final DateTime timestamp;
  final bool isSent;
  String? mediaPath;

  LocalMessage({
    required this.id,
    required this.fromDeviceId,
    required this.fromDeviceName,
    required this.toContact,
    required this.text,
    required this.messageType,
    required this.timestamp,
    required this.isSent,
    this.mediaPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromDeviceId': fromDeviceId,
    'fromDeviceName': fromDeviceName,
    'toContact': toContact,
    'text': text,
    'messageType': messageType,
    'timestamp': timestamp.toIso8601String(),
    'isSent': isSent,
    'mediaPath': mediaPath,
  };

  factory LocalMessage.fromJson(Map<String, dynamic> json) => LocalMessage(
    id: json['id'] as String,
    fromDeviceId: json['fromDeviceId'] as String,
    fromDeviceName: json['fromDeviceName'] as String,
    toContact: json['toContact'] as String,
    text: json['text'] as String,
    messageType: json['messageType'] as String? ?? 'text',
    timestamp: DateTime.parse(json['timestamp'] as String),
    isSent: json['isSent'] as bool? ?? true,
    mediaPath: json['mediaPath'] as String?,
  );
}

class MediaFile {
  final String id;
  final String fileName;
  final String mediaType; // voice, image, video, document
  final String filePath;
  final int fileSize;
  final DateTime uploadedAt;
  final String deviceId;

  MediaFile({
    required this.id,
    required this.fileName,
    required this.mediaType,
    required this.filePath,
    required this.fileSize,
    required this.uploadedAt,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'mediaType': mediaType,
    'filePath': filePath,
    'fileSize': fileSize,
    'uploadedAt': uploadedAt.toIso8601String(),
    'deviceId': deviceId,
  };

  factory MediaFile.fromJson(Map<String, dynamic> json) => MediaFile(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    mediaType: json['mediaType'] as String,
    filePath: json['filePath'] as String,
    fileSize: json['fileSize'] as int,
    uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    deviceId: json['deviceId'] as String,
  );
}

class MessageMediaService extends ChangeNotifier {
  static const String _messagesKey = 'local_messages';
  static const String _mediaKey = 'local_media';
  
  late SharedPreferences _prefs;
  late dynamic _appDir;      // io.Directory on native, null on web
  late dynamic _messagesDir;  // io.Directory on native, null on web
  late dynamic _mediaDir;     // io.Directory on native, null on web
  late dynamic _voiceDir;     // io.Directory on native, null on web
  
  List<LocalMessage> messages = [];
  List<MediaFile> mediaFiles = [];
  
  bool isInitialized = false;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Only initialize file-based storage on native platforms
      if (!kIsWeb) {
        _appDir = await pp.getApplicationDocumentsDirectory();
        
        // Create necessary directories
        _messagesDir = io.Directory('${_appDir.path}/messages');
        _mediaDir = io.Directory('${_appDir.path}/media');
        _voiceDir = io.Directory('${_appDir.path}/voice_recordings');
        
        for (final dir in [_messagesDir, _mediaDir, _voiceDir]) {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        }
        
        // Load existing data
        _loadMessages();
        _loadMediaFiles();
      }
      
      isInitialized = true;
      notifyListeners();
      print('✅ Message/Media service initialized');
      if (!kIsWeb) print('📁 App directory: ${_appDir.path}');
    } catch (e) {
      print('❌ Failed to initialize message service: $e');
      rethrow;
    }
  }

  // Get voice recording directory
  String get voiceRecordingPath => _voiceDir?.path ?? '';

  // Save incoming message
  Future<LocalMessage> saveIncomingMessage({
    required String id,
    required String fromDeviceId,
    required String fromDeviceName,
    required String toContact,
    required String text,
    required String messageType,
    String? mediaPath,
  }) async {
    try {
      final message = LocalMessage(
        id: id,
        fromDeviceId: fromDeviceId,
        fromDeviceName: fromDeviceName,
        toContact: toContact,
        text: text,
        messageType: messageType,
        timestamp: DateTime.now(),
        isSent: false,
        mediaPath: mediaPath,
      );

      messages.add(message);
      await _saveMessages();
      notifyListeners();
      print('✅ Message saved: ${message.id}');
      return message;
    } catch (e) {
      print('❌ Failed to save message: $e');
      rethrow;
    }
  }

  // Save outgoing message
  Future<LocalMessage> saveOutgoingMessage({
    required String id,
    required String fromDeviceId,
    required String fromDeviceName,
    required String toContact,
    required String text,
    required String messageType,
    String? mediaPath,
  }) async {
    try {
      final message = LocalMessage(
        id: id,
        fromDeviceId: fromDeviceId,
        fromDeviceName: fromDeviceName,
        toContact: toContact,
        text: text,
        messageType: messageType,
        timestamp: DateTime.now(),
        isSent: true,
        mediaPath: mediaPath,
      );

      messages.add(message);
      await _saveMessages();
      notifyListeners();
      print('✅ Outgoing message saved: ${message.id}');
      return message;
    } catch (e) {
      print('❌ Failed to save outgoing message: $e');
      rethrow;
    }
  }

  // Save media file
  Future<MediaFile> saveMediaFile({
    required String id,
    required String fileName,
    required String mediaType,
    required List<int> fileData,
    required String deviceId,
  }) async {
    try {
      String targetDir = _mediaDir.path;
      if (mediaType == 'voice') {
        targetDir = _voiceDir.path;
      }

      final filePath = '$targetDir/$fileName';
      final file = io.File(filePath);
      await file.writeAsBytes(fileData);

      final mediaFile = MediaFile(
        id: id,
        fileName: fileName,
        mediaType: mediaType,
        filePath: filePath,
        fileSize: fileData.length,
        uploadedAt: DateTime.now(),
        deviceId: deviceId,
      );

      mediaFiles.add(mediaFile);
      await _saveMediaFiles();
      notifyListeners();
      print('✅ Media file saved: $fileName (${fileData.length} bytes)');
      return mediaFile;
    } catch (e) {
      print('❌ Failed to save media file: $e');
      rethrow;
    }
  }

  // Get messages for contact
  List<LocalMessage> getMessagesFor(String contactName) {
    return messages.where((m) => m.toContact == contactName).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Get media of specific type
  List<MediaFile> getMediaByType(String mediaType) {
    return mediaFiles.where((m) => m.mediaType == mediaType).toList();
  }

  // Get media file by ID
  MediaFile? getMediaFile(String id) {
    try {
      return mediaFiles.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  // Read media file
  Future<List<int>?> readMediaFile(String id) async {
    try {
      final mediaFile = getMediaFile(id);
      if (mediaFile == null) return null;

      final file = io.File(mediaFile.filePath);
      if (!await file.exists()) {
        print('❌ Media file not found: ${mediaFile.filePath}');
        return null;
      }

      return await file.readAsBytes();
    } catch (e) {
      print('❌ Error reading media file: $e');
      return null;
    }
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      final message = messages.firstWhere((m) => m.id == messageId);
      
      // Delete associated media
      if (message.mediaPath != null) {
        final mediaFile = io.File(message.mediaPath!);
        if (await mediaFile.exists()) {
          await mediaFile.delete();
        }
      }

      messages.removeWhere((m) => m.id == messageId);
      await _saveMessages();
      notifyListeners();
      print('✅ Message deleted: $messageId');
    } catch (e) {
      print('❌ Failed to delete message: $e');
    }
  }

  // Get storage stats
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      int totalSize = 0;
      int mediaCount = 0;
      int voiceCount = 0;

      for (final file in mediaFiles) {
        totalSize += file.fileSize;
        if (file.mediaType == 'voice') {
          voiceCount++;
        } else {
          mediaCount++;
        }
      }

      return {
        'totalMessages': messages.length,
        'totalMediaSize': totalSize,
        'mediaFileCount': mediaCount,
        'voiceMessageCount': voiceCount,
        'storagePath': _appDir.path,
      };
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return {};
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      messages.clear();
      mediaFiles.clear();
      
      // Delete directories
      for (final dir in [_messagesDir, _mediaDir, _voiceDir]) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
        }
      }

      await _prefs.remove(_messagesKey);
      await _prefs.remove(_mediaKey);
      
      notifyListeners();
      print('✅ All local data cleared');
    } catch (e) {
      print('❌ Error clearing data: $e');
    }
  }

  // Private methods
  void _loadMessages() {
    try {
      final json = _prefs.getString(_messagesKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        messages = list
            .map((item) => LocalMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      print('✅ Loaded ${messages.length} messages');
    } catch (e) {
      print('⚠️ Error loading messages: $e');
      messages = [];
    }
  }

  void _loadMediaFiles() {
    try {
      final json = _prefs.getString(_mediaKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        mediaFiles = list
            .map((item) => MediaFile.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      print('✅ Loaded ${mediaFiles.length} media files');
    } catch (e) {
      print('⚠️ Error loading media files: $e');
      mediaFiles = [];
    }
  }

  Future<void> _saveMessages() async {
    try {
      final json = jsonEncode(messages.map((m) => m.toJson()).toList());
      await _prefs.setString(_messagesKey, json);
    } catch (e) {
      print('❌ Error saving messages: $e');
    }
  }

  Future<void> _saveMediaFiles() async {
    try {
      final json = jsonEncode(mediaFiles.map((m) => m.toJson()).toList());
      await _prefs.setString(_mediaKey, json);
    } catch (e) {
      print('❌ Error saving media files: $e');
    }
  }
}
