import 'package:flutter/material.dart';

class DmInboxScreen extends StatefulWidget {
  const DmInboxScreen({super.key});

  @override
  State<DmInboxScreen> createState() => _DmInboxScreenState();
}

class _DmInboxScreenState extends State<DmInboxScreen> {
  int? _selectedIndex;

  final _threads = const [
    DmThread(
      name: 'Mina',
      handle: '@mina',
      preview: 'left a 9s answer',
      time: '2m',
      unread: true,
      pulse: .82,
    ),
    DmThread(
      name: 'Arda',
      handle: '@arda',
      preview: 'waiting after your cast',
      time: '18m',
      unread: false,
      pulse: .44,
    ),
    DmThread(
      name: 'Nora',
      handle: '@nora',
      preview: 'sent a quiet reply',
      time: '1h',
      unread: false,
      pulse: .63,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex == null ? null : _threads[_selectedIndex!];

    return Scaffold(
      appBar: AppBar(title: const Text('Whispers')),
      body: selected == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Text(
                  'Voice-first DM',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Private threads feel like exchanged voice sparks, not chat rows.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < _threads.length; i++) ...[
                  _ThreadTile(
                    thread: _threads[i],
                    onTap: () => setState(() => _selectedIndex = i),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            )
          : ChatPlaceholder(
              thread: selected,
              onBack: () => setState(() => _selectedIndex = null),
            ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final DmThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: thread.unread
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _PulseAvatar(name: thread.name, pulse: thread.pulse),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        thread.time,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.graphic_eq,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${thread.handle} ${thread.preview}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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

class ChatPlaceholder extends StatelessWidget {
  const ChatPlaceholder({
    required this.thread,
    required this.onBack,
    super.key,
  });

  final DmThread thread;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 18, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              _PulseAvatar(name: thread.name, pulse: thread.pulse, compact: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      thread.handle,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            children: [
              _VoiceBubble(
                label: thread.preview,
                seconds: 9,
                mine: false,
                progress: thread.pulse,
              ),
              const _VoiceBubble(
                label: 'reply queued',
                seconds: 5,
                mine: true,
                progress: .36,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mic_none, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Hold to whisper',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: null,
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
    );
  }
}

class _PulseAvatar extends StatelessWidget {
  const _PulseAvatar({
    required this.name,
    required this.pulse,
    this.compact = false,
  });

  final String name;
  final double pulse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 58.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pulse,
            strokeWidth: compact ? 3 : 4,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.outline,
          ),
          CircleAvatar(
            radius: compact ? 16 : 22,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Text(
              name[0],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({
    required this.label,
    required this.seconds,
    required this.mine,
    required this.progress,
  });

  final String label;
  final int seconds;
  final bool mine;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 270,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary : theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(mine ? 22 : 6),
            bottomRight: Radius.circular(mine ? 6 : 22),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: mine ? Colors.black : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: mine ? Colors.black : null,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: mine
                          ? Colors.black.withValues(alpha: .16)
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${seconds}s',
              style: TextStyle(
                color: mine ? Colors.black : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DmThread {
  const DmThread({
    required this.name,
    required this.handle,
    required this.preview,
    required this.time,
    required this.unread,
    required this.pulse,
  });

  final String name;
  final String handle;
  final String preview;
  final String time;
  final bool unread;
  final double pulse;
}
