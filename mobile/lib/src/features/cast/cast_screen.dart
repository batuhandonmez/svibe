import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
  final _previewPlayer = AudioPlayer();
  late final MotionTrigger _castMotion;
  bool _isUploading = false;
  bool _isRecording = false;
  bool _isStoppingRecording = false;
  Uint8List? _recordedBytes;
  String? _recordedPath;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _castMotion = MotionTrigger(
      threshold: 16,
      onTrigger: () {
        if (!_isUploading && !_isRecording && _recordedBytes != null) {
          unawaited(_cast());
        }
      },
    )..start();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _castMotion.stop();
    _recorder.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isUploading || _isRecording || _isStoppingRecording) {
      return;
    }
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _show('Microphone permission is needed to record.');
        return;
      }

      final path = await _recordPath();
      await _previewPlayer.stop();
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
        _recordedBytes = null;
        _recordedPath = null;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          return;
        }
        final next = _recordSeconds + 1;
        setState(() => _recordSeconds = next);
        if (next >= 30) {
          await _stopRecording();
        }
      });
    } on Object {
      if (mounted) {
        _show('Recording could not start. Check microphone permission.');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _isStoppingRecording) {
      return;
    }
    _recordTimer?.cancel();
    _isStoppingRecording = true;
    try {
      final path = await _recorder.stop();
      if (!mounted) {
        return;
      }
      setState(() => _isRecording = false);

      if (path == null) {
        _show('Recording could not be saved.');
        return;
      }

      Uint8List? bytes;
      if (!kIsWeb) {
        bytes = await File(path).readAsBytes();
      }
      setState(() {
        _recordedPath = path;
        _recordedBytes = bytes;
      });
    } on Object {
      if (mounted) {
        setState(() => _isRecording = false);
        _show('Recording could not be saved.');
      }
    } finally {
      _isStoppingRecording = false;
    }
  }

  Future<void> _toggleRecordButton() async {
    if (_isUploading || _isStoppingRecording) {
      return;
    }
    if (kIsWeb) {
      await _pickAudioFallback();
      return;
    }
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<String> _recordPath() async {
    final filename = 'svibe_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (kIsWeb) {
      return filename;
    }
    final dir = await getTemporaryDirectory();
    return '${dir.path}${Platform.pathSeparator}$filename';
  }

  Future<void> _pickAudioFallback() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'aac',
        'm4a',
        'mp3',
        'ogg',
        'opus',
        'wav',
        'webm',
      ],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) {
      return;
    }
    setState(() {
      _recordedBytes = bytes;
      _recordedPath = file.path ?? file.name;
      _recordSeconds = 30;
    });
  }

  Future<void> _togglePreview() async {
    final path = _recordedPath;
    if (path == null || kIsWeb) {
      _show('Audio preview is available in the Android app.');
      return;
    }
    if (_previewPlayer.playing) {
      await _previewPlayer.pause();
      return;
    }
    await _previewPlayer.setFilePath(path);
    await _previewPlayer.play();
  }

  Future<void> _recordAgain() async {
    await _previewPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _recordedBytes = null;
      _recordedPath = null;
      _recordSeconds = 0;
    });
    await _startRecording();
  }

  Future<void> _cast() async {
    final bytes = _recordedBytes;
    final path = _recordedPath;
    if (bytes == null || path == null) {
      if (kIsWeb) {
        _show('Browser recording is limited here. Use audio fallback.');
      } else {
        _show('Hold the mic to record first.');
      }
      return;
    }
    await _castBytes(
      bytes,
      filename: path.split(RegExp(r'[\\/]')).last,
      duration: _recordSeconds.clamp(1, 30),
    );
  }

  Future<void> _castBytes(
    Uint8List bytes, {
    required String filename,
    required int duration,
  }) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null || _isUploading) {
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ref
          .read(apiClientProvider)
          .uploadVibe(
            token,
            bytes: bytes,
            filename: filename,
            duration: duration,
          );
      ref.invalidate(userStatusProvider);
      await _previewPlayer.stop();
      if (!mounted) {
        return;
      }
      _show('Voice casted.');
      setState(() {
        _recordedBytes = null;
        _recordedPath = null;
        _recordSeconds = 0;
      });
      Navigator.of(context).pop(true);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: status.when(
          data: (value) {
            final canCast = value?.canUploadVibe ?? false;
            return Stack(
              children: [
                const Positioned.fill(child: _CastBackdrop()),
                Positioned(
                  top: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'svibe',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFF2F0EB),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 18,
                  child: _RoundIconButton(
                    tooltip: 'Close',
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 98, 28, 34),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        Text(
                          _isRecording
                              ? 'RECORDING'
                              : _isUploading
                              ? 'CASTING'
                              : _recordedBytes != null
                              ? 'READY'
                              : 'STANDBY',
                          style: const TextStyle(
                            color: Color(0xFFC9C6C0),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formattedTime(_recordSeconds),
                          style: const TextStyle(
                            color: Color(0xFF8E8A86),
                            fontSize: 56,
                            fontWeight: FontWeight.w300,
                            height: 1,
                          ),
                        ),
                        const Spacer(flex: 2),
                        SizedBox(
                          height: 28,
                          width: 260,
                          child: CustomPaint(
                            painter: _CastWavePainter(
                              active: _isRecording || _isUploading,
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        Text(
                          canCast
                              ? _recordedBytes != null
                                    ? 'Shake your vibe to cast, or use the button'
                                    : kIsWeb
                                    ? 'Tap to choose an audio file'
                                    : 'Tap to record, tap again to preview'
                              : 'Find a Golden Voice to speak again',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF918D88),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_recordedBytes != null && !_isRecording)
                          _PreviewActions(
                            player: _previewPlayer,
                            uploading: _isUploading,
                            onPreview: _togglePreview,
                            onRecordAgain: _recordAgain,
                            onCast: _cast,
                          )
                        else
                          GestureDetector(
                            onTap: canCast ? _toggleRecordButton : null,
                            onLongPressStart: canCast
                                ? (_) => _startRecording()
                                : null,
                            onLongPressEnd: canCast
                                ? (_) => _stopRecording()
                                : null,
                            child: _RecordButton(
                              enabled: canCast,
                              recording: _isRecording,
                              uploading: _isUploading,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          error: (_, __) => const Center(child: Text('Cast state unavailable')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  String _formattedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}

class _PreviewActions extends StatelessWidget {
  const _PreviewActions({
    required this.player,
    required this.uploading,
    required this.onPreview,
    required this.onRecordAgain,
    required this.onCast,
  });

  final AudioPlayer player;
  final bool uploading;
  final VoidCallback onPreview;
  final VoidCallback onRecordAgain;
  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? player.playing;
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploading ? null : onPreview,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    label: Text(playing ? 'Pause' : 'Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploading ? null : onRecordAgain,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-record'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: uploading ? null : onCast,
          icon: uploading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(uploading ? 'Casting...' : 'Cast this vibe'),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF202020),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF292929)),
          ),
          child: Icon(icon, color: const Color(0xFFE6E3DD), size: 28),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.enabled,
    required this.recording,
    required this.uploading,
  });

  final bool enabled;
  final bool recording;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFEAE6DE)
        : const Color(0xFF6F6A66);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: recording ? 118 : 104,
      height: recording ? 118 : 104,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        shape: BoxShape.circle,
        border: Border.all(
          color: recording ? const Color(0xFFEAE6DE) : const Color(0xFF3A3836),
          width: recording ? 5 : 8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .58),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: uploading
          ? const Padding(
              padding: EdgeInsets.all(34),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(
              recording ? Icons.stop : Icons.mic_none,
              color: foreground,
              size: 42,
            ),
    );
  }
}

class _CastBackdrop extends StatelessWidget {
  const _CastBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, .16),
          radius: 1.05,
          colors: [
            const Color(0xFF252525).withValues(alpha: .58),
            const Color(0xFF151515).withValues(alpha: .74),
            const Color(0xFF101010),
          ],
          stops: const [0, .42, 1],
        ),
      ),
    );
  }
}

class _CastWavePainter extends CustomPainter {
  const _CastWavePainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(active ? 0xFFE8E5DF : 0xFF343331)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const bars = 42;
    final center = size.height / 2;
    for (var i = 0; i < bars; i++) {
      final phase = i / (bars - 1);
      final envelope = math.sin(math.pi * phase);
      final irregular = .45 + ((i * 7) % 11) / 16;
      final height = 4 + envelope * irregular * (active ? 22 : 12);
      final x = phase * size.width;
      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CastWavePainter oldDelegate) {
    return oldDelegate.active != active;
  }
}
