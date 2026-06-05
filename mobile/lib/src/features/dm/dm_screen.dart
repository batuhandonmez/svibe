import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/svibe_models.dart';
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
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
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
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
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
    await ref.read(apiClientProvider).sendDmMessage(
          token,
          widget.thread.id,
          text: text,
        );
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
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
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
                      hintText: 'Write a quiet reply',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _send,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(54, 52),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.arrow_upward),
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
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary : theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message.text ?? 'Voice message',
          style: TextStyle(
            color: mine ? Colors.black : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
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
    final initial = peer.username.isEmpty ? 'S' : peer.username[0].toUpperCase();
    if (peer.profilePictureUrl != null && peer.profilePictureUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(peer.profilePictureUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
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
            'Private signals',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'DM permissions come from each profile: everyone, followers, or off.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
              'Bir profil DM kabul ediyorsa konuşma burada görünür.',
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
