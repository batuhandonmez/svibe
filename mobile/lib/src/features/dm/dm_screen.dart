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
import '../../core/models/svibe_models.dart';
import '../auth/auth_controller.dart';

class DmInboxScreen extends ConsumerStatefulWidget {
  const DmInboxScreen({this.initialThread, super.key});

  final DmThread? initialThread;

  @override
  ConsumerState<DmInboxScreen> createState() => _DmInboxScreenState();
}

class _DmInboxScreenState extends ConsumerState<DmInboxScreen> {
  DmThread? _selectedThread;

  @override
  void initState() {
    super.initState();
    _selectedThread = widget.initialThread;
  }

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
    final token = ref.watch(authControllerProvider).token;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            _InboxTopBar(
              onBack: () => Navigator.of(context).maybePop(),
              onNewMessage: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Open a profile from the feed to start a DM.',
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: token == null
                  ? const _CenteredMessage(message: 'Log in to see messages.')
                  : FutureBuilder<List<DmThread>>(
                      future: ref.read(apiClientProvider).dmThreads(token),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _CenteredMessage(
                            message: snapshot.error.toString(),
                          );
                        }
                        final threads = snapshot.data ?? [];
                        if (threads.isEmpty) {
                          return const _EmptyDm();
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                          itemCount: threads.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: _SearchField(),
                              );
                            }
                            final thread = threads[index - 1];
                            return _ThreadTile(
                              thread: thread,
                              unread: index == 1,
                              onTap: () => onThreadSelected(thread),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTopBar extends StatelessWidget {
  const _InboxTopBar({required this.onBack, required this.onNewMessage});

  final VoidCallback onBack;
  final VoidCallback onNewMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF211F1F))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFFEDEAE4),
              size: 28,
            ),
          ),
          const Expanded(
            child: Text(
              'Messages',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF3F0EA),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'New message',
            onPressed: onNewMessage,
            icon: const Icon(
              Icons.edit_square,
              color: Color(0xFFEDEAE4),
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF232222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF302E2D)),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFFC9C5BE), size: 28),
          SizedBox(width: 12),
          Text(
            'Search conversations...',
            style: TextStyle(
              color: Color(0xFF8F8A84),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.unread,
    required this.onTap,
  });

  final DmThread thread;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final peerName = _peerName(thread.peer);
    final last = thread.lastMessage;
    final hasAudio = last?.audioUrl?.isNotEmpty == true;
    final preview = hasAudio ? 'Sent a vibe' : last?.text ?? 'No messages yet';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DmAvatar(peer: thread.peer, radius: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE8E4DE),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (hasAudio) ...[
                        const _TinyWaveIcon(),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB8B3AD),
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeTime(thread.updatedAt),
                  style: const TextStyle(
                    color: Color(0xFFBDB8B1),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (unread)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7E4DE),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
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
  bool _isSendingText = false;
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
    if (token == null || text.isEmpty || _isSendingText) {
      return;
    }
    setState(() => _isSendingText = true);
    try {
      await ref
          .read(apiClientProvider)
          .sendDmMessage(token, widget.thread.id, text: text);
      if (mounted) {
        _controller.clear();
        setState(() => _messagesFuture = _loadMessages());
      }
    } on SvibeApiException catch (exception) {
      if (mounted) {
        _show(exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingText = false);
      }
    }
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
    final peerName = _peerName(widget.thread.peer);
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            _ConversationTopBar(onBack: widget.onBack),
            _ConversationHeader(peer: widget.thread.peer, peerName: peerName),
            Expanded(
              child: FutureBuilder<List<DmMessage>>(
                future: _messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _CenteredMessage(
                      message:
                          'Messages could not load. Pull back and try again.',
                    );
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return const _EmptyConversation();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _DateDivider(label: 'TODAY, 2:45 PM');
                      }
                      final message = messages[index - 1];
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
              isSendingText: _isSendingText,
              isSendingAudio: _isSendingAudio,
              onVoiceTap: _toggleVoiceDm,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTopBar extends StatelessWidget {
  const _ConversationTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF211F1F))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.menu, color: Color(0xFFD9D5CF), size: 28),
          ),
          const Expanded(
            child: Text(
              'svibe',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF2EFE8),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.chat_bubble_outline,
            color: Color(0xFFD9D5CF),
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.peer, required this.peerName});

  final DmPeer peer;
  final String peerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1C1C))),
      ),
      child: Column(
        children: [
          _DmAvatar(peer: peer, radius: 48),
          const SizedBox(height: 14),
          Text(
            peerName,
            style: const TextStyle(
              color: Color(0xFFF1EEE8),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Active now',
            style: TextStyle(
              color: Color(0xFFC6C0B9),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
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
    required this.isSendingText,
    required this.isSendingAudio,
    required this.onVoiceTap,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isRecording;
  final int recordSeconds;
  final bool isSendingText;
  final bool isSendingAudio;
  final VoidCallback onVoiceTap;
  final VoidCallback onSend;

  bool get _busy => isSendingText || isSendingAudio;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        final icon = isSendingText
            ? null
            : hasText
            ? Icons.arrow_upward
            : isRecording
            ? Icons.stop
            : Icons.mic;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Attach',
                onPressed: _busy ? null : () {},
                icon: const Icon(Icons.add, color: Color(0xFFD5D0C8), size: 30),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !_busy,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Color(0xFFEDEAE4),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: isRecording
                        ? 'Recording ${recordSeconds}s'
                        : 'Type a message...',
                    hintStyle: const TextStyle(color: Color(0xFF77716C)),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2A2827)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0DCD4)),
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _busy ? null : (hasText ? onSend : onVoiceTap),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: hasText
                        ? const Color(0xFFE8E4DE)
                        : const Color(0xFF3A3836),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .24),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _busy && !isRecording
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          icon,
                          color: hasText
                              ? const Color(0xFF111111)
                              : const Color(0xFFE8E4DE),
                          size: 28,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF807A74),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
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
    final audio = message.audioUrl?.isNotEmpty == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: audio
            ? const EdgeInsets.fromLTRB(12, 10, 14, 10)
            : const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF3A3837) : const Color(0xFF232222),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: audio
            ? InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onPlayAudio,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF31302F),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: const Color(0xFFECE8E0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 76,
                      height: 36,
                      child: CustomPaint(painter: _AudioBubbleWavePainter()),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '0:42',
                      style: TextStyle(
                        color: Color(0xFFDAD5CE),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                message.text ?? '',
                style: const TextStyle(
                  color: Color(0xFFEDE9E3),
                  fontSize: 17,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _DmAvatar extends StatelessWidget {
  const _DmAvatar({required this.peer, required this.radius});

  final DmPeer peer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = peer.username.isEmpty
        ? 'S'
        : peer.username[0].toUpperCase();
    if (peer.profilePictureUrl != null && peer.profilePictureUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF222120),
        backgroundImage: NetworkImage(peer.profilePictureUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2D2B2A),
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xFFEAE6DE),
          fontWeight: FontWeight.w900,
          fontSize: radius * .72,
        ),
      ),
    );
  }
}

class _TinyWaveIcon extends StatelessWidget {
  const _TinyWaveIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _MiniWavePainter()),
    );
  }
}

class _EmptyDm extends StatelessWidget {
  const _EmptyDm();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(message: 'No active conversations.');
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(message: 'Start the conversation.');
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB9B4AD),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MiniWavePainter extends CustomPainter {
  const _MiniWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCD8D0)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (.15 + i * .18);
      final h = size.height * (.32 + (i % 3) * .18);
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AudioBubbleWavePainter extends CustomPainter {
  const _AudioBubbleWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCD8D0)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    const bars = 15;
    for (var i = 0; i < bars; i++) {
      final phase = i / (bars - 1);
      final h = size.height * (.22 + math.sin(math.pi * phase) * .62);
      final x = phase * size.width;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _peerName(DmPeer peer) {
  return peer.displayName?.trim().isNotEmpty == true
      ? peer.displayName!.trim()
      : peer.username;
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) {
    return '${math.max(1, diff.inMinutes)}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d';
  }
  return '${time.month}/${time.day}';
}
