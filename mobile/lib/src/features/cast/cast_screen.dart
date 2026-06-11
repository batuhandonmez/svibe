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
import '../../core/theme/app_theme.dart';
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
      await ref
          .read(apiClientProvider)
          .uploadVibe(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userStatusProvider);
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: status.when(
            data: (value) {
              final canCast = value?.canUploadVibe ?? false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CastHeader(canCast: canCast, colors: colors),
                  const SizedBox(height: 14),
                  _RecordPanel(
                    isRecording: _isRecording,
                    seconds: _recordSeconds,
                    hasRecording: _recordedBytes != null,
                    enabled: canCast && !_isUploading,
                    onToggle: _toggleRecording,
                  ),
                  const SizedBox(height: 12),
                  _AudioPickerPanel(
                    file: _audioFile,
                    duration: _duration,
                    enabled: canCast && !_isUploading && !_isRecording,
                    onPick: _pickAudio,
                    onDurationChanged: (value) =>
                        setState(() => _duration = value),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GestureDetector(
                      onPanUpdate: canCast && !_isUploading && !_isRecording
                          ? (details) {
                              setState(() {
                                _pull = (_pull - details.delta.dy).clamp(
                                  0,
                                  160,
                                );
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
                        canCast: canCast,
                        isEnabled: canCast && !_isRecording,
                        onCast: _cast,
                      ),
                    ),
                  ),
                ],
              );
            },
            error: (_, __) =>
                const Center(child: Text('Cast state unavailable')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

class _CastHeader extends StatelessWidget {
  const _CastHeader({required this.canCast, required this.colors});

  final bool canCast;
  final SvibeColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: canCast
                  ? colors.orange
                  : colors.muted.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.onSurface, width: 2),
            ),
            child: Icon(
              canCast ? Icons.near_me : Icons.lock_outline,
              color: canCast ? Colors.black : theme.colorScheme.onSurface,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canCast ? 'Cast a signal' : 'Signal locked',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  canCast
                      ? 'Record up to 30 seconds, then throw it into discovery.'
                      : 'Find and unlock a Golden Voice to speak again.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final colors = theme.extension<SvibeColors>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: isRecording ? colors.berry : colors.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isRecording
                  ? colors.berry.withValues(alpha: 0.16)
                  : colors.blue.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRecording ? Icons.fiber_manual_record : Icons.mic,
              color: isRecording ? colors.berry : colors.blue,
            ),
          ),
          const SizedBox(width: 12),
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
          OutlinedButton(
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
    final colors = theme.extension<SvibeColors>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.lilac.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.audio_file, color: colors.lilac),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file?.name ?? 'Or choose an audio file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton(
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
                  activeColor: colors.berry,
                  inactiveColor: colors.border,
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
    required this.canCast,
    required this.isEnabled,
    required this.onCast,
  });

  final double pull;
  final bool isArmed;
  final bool isUploading;
  final bool canCast;
  final bool isEnabled;
  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    final progress = (pull / 160).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: colors.elevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CastTrajectoryPainter(
                color: canCast
                    ? colors.orange.withValues(alpha: 0.45)
                    : colors.border,
                progress: progress,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -pull),
            child: Container(
              width: 142,
              height: 142,
              decoration: BoxDecoration(
                color: isArmed ? colors.orange : theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isArmed ? Colors.black : colors.orange,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.orange.withValues(
                      alpha: isArmed ? 0.35 : 0.16,
                    ),
                    blurRadius: isArmed ? 30 : 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                isUploading ? Icons.cloud_upload : Icons.near_me,
                size: 56,
                color: isArmed ? Colors.black : colors.orange,
              ),
            ),
          ),
          Positioned(
            bottom: 26,
            left: 22,
            right: 22,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: isUploading ? null : progress,
                    color: colors.orange,
                    backgroundColor: colors.border,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  !canCast
                      ? 'Locked'
                      : isUploading
                      ? 'Casting'
                      : isArmed
                      ? 'Release'
                      : 'Pull up or flick',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manual cast stays ready.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: FilledButton.tonal(
              onPressed: isEnabled && !isUploading ? onCast : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: colors.blue.withValues(alpha: 0.14),
                foregroundColor: colors.blue,
              ),
              child: const Icon(Icons.send, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastTrajectoryPainter extends CustomPainter {
  const _CastTrajectoryPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * (0.08 + 0.18 * (1 - progress)),
        size.width * 0.82,
        size.height * 0.34,
      );
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = color.withValues(alpha: 0.85);
    for (final factor in const [0.24, 0.48, 0.72]) {
      canvas.drawCircle(
        Offset(size.width * factor, size.height * (0.78 - factor * 0.55)),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CastTrajectoryPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
