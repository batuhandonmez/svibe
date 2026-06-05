import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/api/api_client.dart';
import '../../core/motion/motion_trigger.dart';
import '../auth/auth_controller.dart';

class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key});

  @override
  ConsumerState<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends ConsumerState<CastScreen> {
  final _recorder = AudioRecorder();
  late final MotionTrigger _castMotion;
  double _pull = 0;
  bool _isArmed = false;
  bool _isUploading = false;
  bool _isRecording = false;
  PlatformFile? _audioFile;
  Uint8List? _recordedBytes;
  String? _recordedPath;
  int _duration = 15;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _castMotion = MotionTrigger(
      threshold: 16,
      onTrigger: () {
        if (!_isUploading && !_isRecording) {
          _cast();
        }
      },
    )..start();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _castMotion.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['aac', 'm4a', 'mp3', 'ogg', 'opus', 'wav', 'webm'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _audioFile = file;
      _recordedBytes = null;
      _recordedPath = null;
      _recordSeconds = 0;
      _duration = _duration.clamp(1, 30);
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _show('Microphone permission is needed to record.');
      return;
    }

    final path = await _recordPath();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = true;
      _audioFile = null;
      _recordedBytes = null;
      _recordedPath = null;
      _recordSeconds = 0;
      _duration = 1;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        return;
      }
      final next = _recordSeconds + 1;
      setState(() {
        _recordSeconds = next;
        _duration = next.clamp(1, 30);
      });
      if (next >= 30) {
        await _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) {
      return;
    }
    if (path == null) {
      setState(() => _isRecording = false);
      _show('Recording could not be saved.');
      return;
    }

    Uint8List? bytes;
    if (!kIsWeb) {
      bytes = await File(path).readAsBytes();
    }
    setState(() {
      _isRecording = false;
      _recordedPath = path;
      _recordedBytes = bytes;
      _audioFile = null;
      _duration = _recordSeconds.clamp(1, 30);
    });
  }

  Future<String> _recordPath() async {
    final filename = 'svibe_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (kIsWeb) {
      return filename;
    }
    final dir = await getTemporaryDirectory();
    return '${dir.path}${Platform.pathSeparator}$filename';
  }

  Future<void> _cast() async {
    if (_isRecording || _isUploading) {
      return;
    }
    final token = ref.read(authControllerProvider).token;
    final pickedBytes = _audioFile?.bytes;
    final pickedName = _audioFile?.name;
    final recordedBytes = _recordedBytes;
    final recordedPath = _recordedPath;

    Uint8List? bytes;
    String? filename;
    if (recordedBytes != null && recordedPath != null) {
      bytes = recordedBytes;
      filename = recordedPath.split(RegExp(r'[\\/]')).last;
    } else if (pickedBytes != null && pickedName != null) {
      bytes = Uint8List.fromList(pickedBytes);
      filename = pickedName;
    }

    if (token == null || bytes == null || filename == null) {
      _show('Record or choose an audio file first.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ref.read(apiClientProvider).uploadVibe(
            token,
            bytes: bytes,
            filename: filename,
            duration: _duration,
          );
      ref.invalidate(userStatusProvider);
      if (!mounted) {
        return;
      }
      _show('Voice casted. It can now enter public discovery.');
      setState(() {
        _audioFile = null;
        _recordedBytes = null;
        _recordedPath = null;
        _recordSeconds = 0;
        _duration = 15;
        _pull = 0;
        _isArmed = false;
      });
    } on SvibeApiException catch (exception) {
      if (mounted) {
        _show(exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cast')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: status.when(
            data: (value) {
              final canCast = value?.canUploadVibe ?? false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Throw a voice',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canCast
                        ? 'Record up to 30 seconds, then cast it like a line.'
                        : 'Your voice is locked. Find Golden Voice to speak.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  _RecordPanel(
                    isRecording: _isRecording,
                    seconds: _recordSeconds,
                    hasRecording: _recordedBytes != null,
                    enabled: canCast && !_isUploading,
                    onToggle: _toggleRecording,
                  ),
                  const SizedBox(height: 10),
                  _AudioPickerPanel(
                    file: _audioFile,
                    duration: _duration,
                    enabled: canCast && !_isUploading && !_isRecording,
                    onPick: _pickAudio,
                    onDurationChanged: (value) => setState(() => _duration = value),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GestureDetector(
                      onPanUpdate: canCast && !_isUploading && !_isRecording
                          ? (details) {
                              setState(() {
                                _pull = (_pull - details.delta.dy).clamp(0, 160);
                                _isArmed = _pull > 95;
                              });
                            }
                          : null,
                      onPanEnd: canCast && !_isUploading && !_isRecording
                          ? (_) {
                              if (_isArmed) {
                                _cast();
                              } else {
                                setState(() => _pull = 0);
                              }
                            }
                          : null,
                      child: _CastPad(
                        pull: _pull,
                        isArmed: _isArmed,
                        isUploading: _isUploading,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: canCast && !_isUploading && !_isRecording ? _cast : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Cast with button'),
                  ),
                ],
              );
            },
            error: (_, __) => const Center(child: Text('Cast state unavailable')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({
    required this.isRecording,
    required this.seconds,
    required this.hasRecording,
    required this.enabled,
    required this.onToggle,
  });

  final bool isRecording;
  final int seconds;
  final bool hasRecording;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: isRecording ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.fiber_manual_record : Icons.mic,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRecording
                  ? 'Recording ${seconds}s / 30s'
                  : hasRecording
                      ? 'Recording ready'
                      : 'Record a new voice',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(
            onPressed: enabled ? onToggle : null,
            child: Text(isRecording ? 'Stop' : 'Record'),
          ),
        ],
      ),
    );
  }
}

class _AudioPickerPanel extends StatelessWidget {
  const _AudioPickerPanel({
    required this.file,
    required this.duration,
    required this.enabled,
    required this.onPick,
    required this.onDurationChanged,
  });

  final PlatformFile? file;
  final int duration;
  final bool enabled;
  final VoidCallback onPick;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.audio_file, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file?.name ?? 'Or choose an audio file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: enabled ? onPick : null,
                child: const Text('Choose'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Duration'),
              Expanded(
                child: Slider(
                  value: duration.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${duration}s',
                  onChanged: enabled
                      ? (value) => onDurationChanged(value.round())
                      : null,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${duration}s',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CastPad extends StatelessWidget {
  const _CastPad({
    required this.pull,
    required this.isArmed,
    required this.isUploading,
  });

  final double pull;
  final bool isArmed;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, -pull),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: isArmed ? theme.colorScheme.primary : theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Icon(
                isUploading ? Icons.cloud_upload : Icons.graphic_eq,
                size: 58,
                color: isArmed ? Colors.black : theme.colorScheme.primary,
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 22,
            right: 22,
            child: Column(
              children: [
                LinearProgressIndicator(
                  minHeight: 8,
                  value: isUploading ? null : pull / 160,
                ),
                const SizedBox(height: 14),
                Text(
                  isUploading
                      ? 'Casting...'
                      : isArmed
                          ? 'Release to cast'
                          : 'Pull up, throw, or flick the phone',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
