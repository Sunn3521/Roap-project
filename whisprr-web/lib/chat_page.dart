import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'dart:async';
// dart:io is not available on web; use a stub there
import 'dart:io' if (dart.library.html) 'package:splash_screen/src/io_stub.dart' as io;
import 'home_screen.dart';
import 'poll_creator.dart';
import 'services/local_network_service.dart';
import 'services/device_pairing_service.dart';
import 'services/message_media_service.dart';

class ChatPage extends StatefulWidget {
  final Contact contact;

  const ChatPage({super.key, required this.contact});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final Record _record = Record();
  bool _isRecording = false;
  late FocusNode _focusNode;
  Offset? _recordingStartPosition;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _binHovered = false;
  Offset _dragOffset = Offset.zero;
  late AnimationController _returnAnimController;
  Animation<Offset>? _returnAnimation;
  
  // Local networking
  late LocalNetworkService _networkService;
  late DevicePairingService _pairingService;
  late MessageMediaService _messagingService;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _returnAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize services
    _networkService = context.read<LocalNetworkService>();
    _pairingService = context.read<DevicePairingService>();
    _messagingService = context.read<MessageMediaService>();
  }

  @override
  void dispose() {
    _controller.dispose();
    _record.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _returnAnimController.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    setState(() => _messages.add({'from': 'me', 'text': text}));
    _controller.clear();
    
    // Save to local storage
    final messageId = const Uuid().v4();
    await _messagingService.saveOutgoingMessage(
      id: messageId,
      fromDeviceId: _pairingService.localDeviceId,
      fromDeviceName: _pairingService.localDeviceName,
      toContact: widget.contact.name,
      text: text,
      messageType: 'text',
    );
    
    // Send to paired devices
    for (final device in _pairingService.pairedDevices) {
      if (device.isOnline) {
        await _networkService.sendMessage(
          device.deviceId,
          widget.contact.name,
          text,
          messageType: 'text',
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (!mounted) return;
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _messages.add({
            'from': 'me',
            'text': '📎 ${file.name}',
            'type': 'file',
            'fileName': file.name,
            'filePath': file.path ?? '',
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void _createPoll() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const PollCreator(),
    );

    if (!mounted) return;
    
    if (result != null) {
      final question = result['question'] as String;
      final options = result['options'] as List<String>;
      setState(() {
        _messages.add({
          'from': 'me',
          'text': '📊 Poll: $question',
          'type': 'poll',
          'question': question,
          'options': options.join(' | '),
        });
      });
    }
  }

  Future<void> _takeCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Use camera source on all platforms (mobile and desktop)
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (!mounted) return;
      
      if (photo != null) {
        setState(() {
          _messages.add({
            'from': 'me',
            'text': '📷 Photo',
            'type': 'camera',
            'filePath': photo.path,
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added to message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing camera: $e')),
        );
      }
    }
  }

  Future<String?> _saveRecordingFile(String sourcePath, String fileName) async {
    try {
      // Use the messaging service's voice recording directory
      final targetDir = _messagingService.voiceRecordingPath;
      final dir = io.Directory(targetDir);
      
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final String savedPath = '$targetDir/$fileName.m4a';
      final sourceFile = io.File(sourcePath);
      
      if (await sourceFile.exists()) {
        await sourceFile.copy(savedPath);
        return savedPath;
      }
      return sourcePath;
    } catch (e) {
      return sourcePath;
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        await _record.start();
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration += 100;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording({bool deleteRecording = false}) async {
    try {
      _recordingTimer?.cancel();
      final recordedPath = await _record.stop();
      
      // Delete the recording if requested
      if (deleteRecording && recordedPath != null) {
        try {
          final file = io.File(recordedPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Silently fail if file deletion has issues
        }
        
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
          _dragOffset = Offset.zero;
          _binHovered = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording deleted')),
          );
        }
      } else if (!deleteRecording && recordedPath != null) {
        // Save recording to persistent location
        final fileName = const Uuid().v4();
        final savedPath = await _saveRecordingFile(recordedPath, fileName);
        
        // Save to local messaging service
        final messageId = const Uuid().v4();
        await _messagingService.saveOutgoingMessage(
          id: messageId,
          fromDeviceId: _pairingService.localDeviceId,
          fromDeviceName: _pairingService.localDeviceName,
          toContact: widget.contact.name,
          text: '🎤 Voice message',
          messageType: 'voice',
          mediaPath: savedPath ?? recordedPath,
        );
        
        // Send to paired devices via network
        final voiceFile = io.File(savedPath ?? recordedPath);
        if (await voiceFile.exists()) {
          final voiceData = await voiceFile.readAsBytes();
          for (final device in _pairingService.pairedDevices) {
            if (device.isOnline) {
              await _networkService.sendMedia(
                device.deviceId,
                widget.contact.name,
                voiceData,
                '$fileName.m4a',
                'voice',
              );
            }
          }
        }
        
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
          _dragOffset = Offset.zero;
          _messages.add({
            'from': 'me',
            'text': '🎤 Voice message',
            'type': 'voice',
            'path': savedPath ?? recordedPath,
            'duration': (_recordingDuration ~/ 1000).toString(),
          });
        });
      } else {
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
          _dragOffset = Offset.zero;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording: $e')),
        );
      }
    }
  }

  void _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _record.stop();
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting recording: $e')),
        );
      }
    }
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onLongPressStart: (details) {
        if (!_isRecording) {
          // Set recording start position to a fixed point (right side of message box)
          setState(() {
            _recordingStartPosition = Offset(
              MediaQuery.of(context).size.width - 50,
              MediaQuery.of(context).size.height - 80,
            );
          });
          _startRecording();
        }
      },
      child: FloatingActionButton(
        onPressed: _controller.text.trim().isEmpty ? null : _send,
        mini: true,
        backgroundColor: const Color(0xFF00C4E6),
        child: const Icon(Icons.send, color: Colors.white),
      ),
    );
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void _animateAndStopRecording() async {
    if (_binHovered) {
      // Delete the recording
      await _stopRecording(deleteRecording: true);
    } else {
      // Animate back to origin, then save
      _returnAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
        CurvedAnimation(parent: _returnAnimController, curve: Curves.easeOut),
      );
      _returnAnimation!.addListener(() {
        if (mounted) {
          setState(() {
            _dragOffset = _returnAnimation!.value;
          });
        }
      });
      _returnAnimController.forward(from: 0.0);
      
      // Wait for animation to complete before saving
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await _stopRecording(deleteRecording: false);
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00C4E6)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takeCamera();
              },
            ),
            if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) ...[
              ListTile(
                leading: const Icon(Icons.videocam, color: Color(0xFF00C4E6)),
                title: const Text('Record Video'),
                onTap: () {
                  Navigator.pop(context);
                  _recordVideo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFF00C4E6)),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotoFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF00C4E6)),
                title: const Text('Contact'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact picker not yet implemented')));
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF00C4E6)),
              title: const Text('Files'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll, color: Color(0xFF00C4E6)),
              title: const Text('Poll'),
              onTap: () {
                Navigator.pop(context);
                _createPoll();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
      
      if (!mounted) return;
      
      if (photo != null) {
        setState(() {
          _messages.add({
            'from': 'me',
            'text': '📷 Photo',
            'type': 'camera',
            'filePath': photo.path,
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo from gallery added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking photo: $e')),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);
      
      if (!mounted) return;
      
      if (video != null) {
        setState(() {
          _messages.add({
            'from': 'me',
            'text': '🎥 Video',
            'type': 'video',
            'filePath': video.path,
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video added to message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording video: $e')),
        );
      }
    }
  }

  Widget _buildMediaMessage(Map<String, String> msg, String? type) {
    final filePath = msg['filePath'] ?? '';
    if (filePath.isEmpty) {
      return Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white));
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (type == 'camera')
          if (!kIsWeb)
            Image.file(
              io.File(filePath) as dynamic,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            )
          else
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.image, size: 48, color: Colors.black38)),
            )
        else
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.videocam, size: 80, color: Colors.white70),
            ),
          ),
        const SizedBox(height: 8),
        Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(child: Text(widget.contact.name[0])),
            const SizedBox(width: 12),
            Text(widget.contact.name),
          ],
        ),
        backgroundColor: const Color(0xFF00C4E6),
      ),
      body: Focus(
        onKeyEvent: (node, event) {
          if (event.physicalKey == PhysicalKeyboardKey.keyM) {
            if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlRight)) {
              _toggleRecording();
              return KeyEventResult.handled;
            }
          }
          if (event.physicalKey == PhysicalKeyboardKey.keyS) {
            if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlRight)) {
              if (_isRecording) {
                _cancelRecording();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('No messages yet. Say hi to ${widget.contact.name}!', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['from'] == 'me';
                      final messageType = msg['type'];
                      
                      Widget messageWidget;
                      if (messageType == 'voice') {
                        messageWidget = VoiceMessageWidget(filePath: msg['path'] ?? '');
                      } else if (messageType == 'camera' || messageType == 'video') {
                        messageWidget = _buildMediaMessage(msg, messageType);
                      } else {
                        messageWidget = Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87));
                      }
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isMe ? const Color(0xFF00C4E6) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                          child: messageWidget,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Stack(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF00C4E6), size: 28),
                        onPressed: _showAttachmentMenu,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          readOnly: _isRecording,
                          textInputAction: TextInputAction.send,
                          onTap: () {
                            if (defaultTargetPlatform == TargetPlatform.android ||
                                defaultTargetPlatform == TargetPlatform.iOS) {
                              SystemChannels.textInput.invokeMethod('TextInput.show');
                            }
                          },
                          decoration: InputDecoration(
                            hintText: _isRecording ? '' : 'Message ${widget.contact.name}',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            prefixIcon: _isRecording
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${(_recordingDuration ~/ 1000).toString().padLeft(2, '0')}s',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        ...List.generate(10, (index) {
                                          const barDuration = 6000;
                                          final barsToFill = (_recordingDuration / barDuration).ceil();
                                          final isFilled = index < barsToFill;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 1),
                                            child: Container(
                                              width: 3,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: isFilled ? const Color(0xFF00C4E6) : Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  )
                                : null,
                            suffixIcon: !_isRecording
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, color: Color(0xFF00C4E6), size: 22),
                                      onPressed: _takeCamera,
                                    ),
                                  )
                                : null,
                          ),
                          onSubmitted: (_) {
                            if (defaultTargetPlatform == TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.macOS ||
                                defaultTargetPlatform == TargetPlatform.linux) {
                              if (!_isRecording) {
                                _send();
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Placeholder for send button position
                      if (!_isRecording) _buildSendButton(),
                    ],
                  ),
                  // Draggable recording button with pointer tracking and animation
                  if (_isRecording)
                    AnimatedPositioned(
                      right: 8 + _dragOffset.dx,
                      bottom: 8 + _dragOffset.dy,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.linear,
                      child: Listener(
                        onPointerMove: (event) {
                          if (_isRecording && _recordingStartPosition != null) {
                            final screenSize = MediaQuery.of(context).size;
                            final centerX = screenSize.width / 2;
                            final centerY = screenSize.height / 2;
                            
                            final newOffset = Offset(
                              event.position.dx - _recordingStartPosition!.dx,
                              event.position.dy - _recordingStartPosition!.dy,
                            );
                            
                            // Calculate current mic button position
                            final micCenterX = (screenSize.width - 50) + newOffset.dx;
                            final micCenterY = (screenSize.height - 80) + newOffset.dy;
                            
                            // Distance to center delete circle
                            final dx = micCenterX - centerX;
                            final dy = micCenterY - centerY;
                            final distanceSquared = dx * dx + dy * dy;
                            
                            setState(() {
                              _dragOffset = newOffset;
                              _binHovered = distanceSquared < 14400; // 120^2 squared radius
                            });
                          }
                        },
                        onPointerUp: (event) {
                          if (_isRecording && _recordingStartPosition != null) {
                            // Trigger delete or save animation
                            _animateAndStopRecording();
                          }
                        },
                        child: FloatingActionButton(
                          onPressed: () {
                            if (_isRecording) {
                              _toggleRecording();
                            }
                          },
                          mini: true,
                          backgroundColor: _binHovered ? Colors.red : const Color(0xFF00C4E6),
                          child: Icon(
                            _binHovered ? Icons.delete : Icons.mic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
            if (_isRecording)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _binHovered ? Colors.red : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
          ],
        ),
        ),
    );
  }
}

class VoiceMessageWidget extends StatefulWidget {
  final String filePath;

  const VoiceMessageWidget({super.key, required this.filePath});

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
    _audioPlayer.durationStream.listen((newDuration) {
      if (mounted && newDuration != null) {
        setState(() => _duration = newDuration);
      }
    });
    _audioPlayer.positionStream.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (widget.filePath.isEmpty) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // Try to set file path with proper error handling
        final file = io.File(widget.filePath);
        if (await file.exists()) {
          await _audioPlayer.setFilePath(widget.filePath);
          await _audioPlayer.play();
        } else {
          // Try as direct path
          await _audioPlayer.setFilePath(widget.filePath);
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error playing audio. File may not be available.')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: Colors.white,
            size: 28,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _playAudio,
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDuration(_position),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            SizedBox(
              width: 100,
              height: 4,
              child: LinearProgressIndicator(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds / _duration.inMilliseconds
                    : 0,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_duration),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
