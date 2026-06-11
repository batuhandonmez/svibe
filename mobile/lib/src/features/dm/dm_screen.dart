import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/api/api_client.dart';
import '../../core/models/svibe_models.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';

class DmInboxScreen extends ConsumerStatefulWidget {
  const DmInboxScreen({super.key});

  @override
  ConsumerState<DmInboxScreen> createState() => _DmInboxScreenState();
}

class _DmInboxScreenState extends ConsumerState<DmInboxScreen> {
  DmThread? _selectedThread;

  @override
  Widget build(BuildContext context) {
    if (_selectedThread != null) {
      return _DmThreadView(
        thread: _selectedThread!,
        onBack: () => setState(() => _selectedThread = null),
      );
    }
    return _DmInbox(
      onThreadSelected: (thread) => setState(() => _selectedThread = thread),
    );
  }
}

class _DmInbox extends ConsumerWidget {
  const _DmInbox({required this.onThreadSelected});

  final ValueChanged<DmThread> onThreadSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final token = auth.token;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('DM')),
      body: token == null
          ? const Center(child: Text('Log in to see messages.'))
          : FutureBuilder<List<DmThread>>(
              future: ref.read(apiClientProvider).dmThreads(token),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _DmError(message: snapshot.error.toString());
                }
                final threads = snapshot.data ?? [];
                if (threads.isEmpty) {
                  return _EmptyDm(theme: theme);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  itemCount: threads.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _InboxHeader(theme: theme);
                    }
                    final thread = threads[index - 1];
                    return _ThreadTile(
                      thread: thread,
                      onTap: () => onThreadSelected(thread),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final DmThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final peerName = thread.peer.displayName?.isNotEmpty == true
        ? thread.peer.displayName!
        : thread.peer.username;
    final preview = thread.lastMessage?.text ?? 'No messages yet';
    final colors = theme.extension<SvibeColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: Row(
          children: [
            _DmAvatar(peer: thread.peer, compact: false),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 54,
              height: 32,
              child: CustomPaint(painter: _DmWavePainter(color: colors.berry)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmThreadView extends ConsumerStatefulWidget {
  const _DmThreadView({required this.thread, required this.onBack});

  final DmThread thread;
  final VoidCallback onBack;

  @override
  ConsumerState<_DmThreadView> createState() => _DmThreadViewState();
}

class _DmThreadViewState extends ConsumerState<_DmThreadView> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  late Future<List<DmMessage>> _messagesFuture;
  StreamSubscription<ProcessingState>? _audioStateSubscription;
  bool _isSendingAudio = false;
  bool _isRecording = false;
  String? _playingMessageId;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
    _audioStateSubscription = _audioPlayer.processingStateStream.listen((
      state,
    ) {
      if (state == ProcessingState.completed && mounted) {
        setState(() => _playingMessageId = null);
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioStateSubscription?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<List<DmMessage>> _loadMessages() {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      return Future.value([]);
    }
    return ref.read(apiClientProvider).dmMessages(token, widget.thread.id);
  }

  Future<void> _send() async {
    final token = ref.read(authControllerProvider).token;
    final text = _controller.text.trim();
    if (token == null || text.isEmpty) {
      return;
    }
    _controller.clear();
    await ref
        .read(apiClientProvider)
        .sendDmMessage(token, widget.thread.id, text: text);
    setState(() => _messagesFuture = _loadMessages());
  }

  Future<void> _toggleVoiceDm() async {
    if (_isSendingAudio) {
      return;
    }
    if (kIsWeb) {
      await _pickAudioMessage();
      return;
    }
    if (_isRecording) {
      await _stopAndSendRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _pickAudioMessage() async {
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
    if (file == null || bytes == null) {
      return;
    }
    await _sendAudioBytes(bytes, filename: file.name, duration: 30);
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _show('Microphone permission is needed for voice DM.');
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
        await _stopAndSendRecording();
      }
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) {
      return;
    }
    setState(() => _isRecording = false);
    if (path == null) {
      _show('Recording could not be saved.');
      return;
    }
    final bytes = await File(path).readAsBytes();
    await _sendAudioBytes(
      bytes,
      filename: path.split(RegExp(r'[\\/]')).last,
      duration: _recordSeconds.clamp(1, 30),
    );
  }

  Future<void> _sendAudioBytes(
    List<int> bytes, {
    required String filename,
    required int duration,
  }) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null || _isSendingAudio) {
      return;
    }
    setState(() => _isSendingAudio = true);
    try {
      await ref
          .read(apiClientProvider)
          .sendDmAudio(
            token,
            widget.thread.id,
            bytes: bytes,
            filename: filename,
            duration: duration,
          );
      if (mounted) {
        setState(() => _messagesFuture = _loadMessages());
      }
    } on SvibeApiException catch (exception) {
      if (mounted) {
        _show(exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingAudio = false);
      }
    }
  }

  Future<String> _recordPath() async {
    final filename = 'svibe_dm_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final dir = await getTemporaryDirectory();
    return '${dir.path}${Platform.pathSeparator}$filename';
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleAudioPlayback(DmMessage message) async {
    final audioUrl = message.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      return;
    }
    try {
      if (_playingMessageId == message.id && _audioPlayer.playing) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() => _playingMessageId = null);
        }
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(audioUrl);
      if (mounted) {
        setState(() => _playingMessageId = message.id);
      }
      await _audioPlayer.play();
    } on PlayerException {
      if (mounted) {
        _show('Voice DM could not be played.');
        setState(() => _playingMessageId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final peerName = widget.thread.peer.displayName?.isNotEmpty == true
        ? widget.thread.peer.displayName!
        : widget.thread.peer.username;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Row(
          children: [
            _DmAvatar(peer: widget.thread.peer, compact: true),
            const SizedBox(width: 10),
            Expanded(child: Text(peerName)),
          ],
        ),
      ),
      body: Column(
        children: [
          _ThreadSignalHeader(thread: widget.thread),
          Expanded(
            child: FutureBuilder<List<DmMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'First whisper is still waiting.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      mine: message.senderId == auth.user?.id,
                      playing: _playingMessageId == message.id,
                      onPlayAudio: () => _toggleAudioPlayback(message),
                    );
                  },
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _controller,
            isRecording: _isRecording,
            recordSeconds: _recordSeconds,
            isSendingAudio: _isSendingAudio,
            onVoiceTap: _toggleVoiceDm,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isRecording,
    required this.recordSeconds,
    required this.isSendingAudio,
    required this.onVoiceTap,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isRecording;
  final int recordSeconds;
  final bool isSendingAudio;
  final VoidCallback onVoiceTap;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: colors.elevated,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.24 : 0.08,
              ),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Voice DM',
              onPressed: isSendingAudio ? null : onVoiceTap,
              icon: isSendingAudio
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isRecording ? Icons.stop_circle_outlined : Icons.mic),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isRecording
                      ? 'Recording ${recordSeconds}s'
                      : 'Send a quiet signal',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.near_me),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.playing,
    required this.onPlayAudio,
  });

  final DmMessage message;
  final bool mine;
  final bool playing;
  final VoidCallback onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.onSurface : colors.elevated,
          border: Border.all(
            color: mine ? Colors.transparent : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(mine ? 24 : 8),
            bottomRight: Radius.circular(mine ? 8 : 24),
          ),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              height: 26,
              child: CustomPaint(
                painter: _DmWavePainter(
                  color: mine ? Colors.white : colors.berry,
                  dense: true,
                ),
              ),
            ),
            const SizedBox(height: 7),
            if (message.audioUrl != null)
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                onTap: onPlayAudio,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      color: mine ? Colors.white : colors.berry,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      playing ? 'Playing voice' : 'Play voice',
                      style: TextStyle(
                        color: mine
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                message.text ?? '',
                style: TextStyle(
                  color: mine ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThreadSignalHeader extends StatelessWidget {
  const _ThreadSignalHeader({required this.thread});

  final DmThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.graphic_eq, color: theme.colorScheme.surface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private signal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Permission-aware, voice-first thread',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmAvatar extends StatelessWidget {
  const _DmAvatar({required this.peer, required this.compact});

  final DmPeer peer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 18.0 : 24.0;
    final initial = peer.username.isEmpty
        ? 'S'
        : peer.username[0].toUpperCase();
    if (peer.profilePictureUrl != null && peer.profilePictureUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(peer.profilePictureUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).extension<SvibeColors>()!.berry,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Direct signals',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 74,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.extension<SvibeColors>()!.elevated,
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _DmWavePainter(
                      color: theme.extension<SvibeColors>()!.berry,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDm extends StatelessWidget {
  const _EmptyDm({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.markunread_mailbox_outlined, size: 46),
            const SizedBox(height: 14),
            Text(
              'No private signals',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When a profile accepts DM, the thread appears here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmError extends StatelessWidget {
  const _DmError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DmWavePainter extends CustomPainter {
  const _DmWavePainter({required this.color, this.dense = false});

  final Color color;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = dense ? 3 : 4;
    final bars = dense ? 14 : 18;
    final center = size.height / 2;
    for (var i = 0; i < bars; i++) {
      final ratio = i / (bars - 1);
      final wave = (0.35 + (i % 5) * 0.15).clamp(0.0, 1.0);
      final h = size.height * (0.24 + wave * 0.58);
      final x = ratio * size.width;
      canvas.drawLine(
        Offset(x, center - h / 2),
        Offset(x, center + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DmWavePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dense != dense;
  }
}
