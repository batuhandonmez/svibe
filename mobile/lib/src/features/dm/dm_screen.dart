import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colors.elevated,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
              width: 62,
              height: 38,
              child: CustomPaint(painter: _DmWavePainter(color: colors.orange)),
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
  late Future<List<DmMessage>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
  }

  @override
  void dispose() {
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
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Send a quiet signal',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _send,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(54, 54),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.near_me),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final DmMessage message;
  final bool mine;

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
          color: mine ? colors.blue : colors.elevated,
          border: Border.all(color: theme.colorScheme.outline),
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
                  color: mine ? Colors.white : colors.blue,
                  dense: true,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message.text ?? 'Voice message',
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
    final colors = theme.extension<SvibeColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.orange.withValues(alpha: 0.13),
          border: Border.all(color: colors.orange.withValues(alpha: 0.38)),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.graphic_eq, color: Colors.black),
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
      backgroundColor: Theme.of(context).extension<SvibeColors>()!.blue,
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
          const SizedBox(height: 6),
          Container(
            height: 86,
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
                      color: theme.extension<SvibeColors>()!.orange,
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
