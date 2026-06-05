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
      preview: 'That Golden Voice clip was sharp.',
      time: '2m',
      unread: true,
    ),
    DmThread(
      name: 'Arda',
      handle: '@arda',
      preview: 'Send me the next cast when it drops.',
      time: '18m',
      unread: false,
    ),
    DmThread(
      name: 'Nora',
      handle: '@nora',
      preview: 'This app needs a night mode sound theme.',
      time: '1h',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex == null ? null : _threads[_selectedIndex!];

    return Scaffold(
      appBar: AppBar(title: const Text('DM')),
      body: selected == null
          ? ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final thread = _threads[index];
                return Card(
                  child: ListTile(
                    onTap: () => setState(() => _selectedIndex = index),
                    leading: CircleAvatar(
                      child: Text(thread.name[0]),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(thread.time),
                      ],
                    ),
                    subtitle: Text(thread.preview),
                    trailing: thread.unread
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                );
              },
            )
          : ChatPlaceholder(
              thread: selected,
              onBack: () => setState(() => _selectedIndex = null),
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
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child: ListTile(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(thread.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(thread.handle),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Bubble(text: thread.preview, mine: false),
              const _Bubble(
                text: 'DM backend is next. The UI path is ready.',
                mine: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Messaging API coming next',
              suffixIcon: IconButton(
                tooltip: 'Send',
                onPressed: null,
                icon: const Icon(Icons.send),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: mine ? Colors.black : null),
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
  });

  final String name;
  final String handle;
  final String preview;
  final String time;
  final bool unread;
}
