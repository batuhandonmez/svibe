import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/svibe_models.dart';
import '../auth/auth_controller.dart';
import 'feed_providers.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final status = ref.watch(userStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Svibe'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _index = 0);
              ref.invalidate(feedProvider);
              ref.invalidate(userStatusProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            children: [
              status.when(
                data: (value) => _StatusRail(status: value),
                error: (_, __) => const _StatusRail(status: null),
                loading: () => const _StatusRail(status: null, loading: true),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: feed.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptyFeed();
                    }
                    final current = items[_index.clamp(0, items.length - 1)];
                    return Column(
                      children: [
                        Expanded(
                          child: _SoloVibeCard(
                            item: current,
                            position: _index + 1,
                            total: items.length,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DeckControls(
                          canGoBack: _index > 0,
                          canGoNext: _index < items.length - 1,
                          onBack: () => setState(() => _index--),
                          onNext: () => setState(() => _index++),
                        ),
                      ],
                    );
                  },
                  error: (error, _) => _ErrorState(message: error.toString()),
                  loading: () => const _FeedSkeleton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRail extends StatelessWidget {
  const _StatusRail({required this.status, this.loading = false});

  final UserStatus? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUpload = status?.canUploadVibe ?? false;
    final label = loading
        ? 'Checking signal'
        : canUpload
            ? 'Mic is open'
            : 'Listen-only';
    final count = status == null
        ? '--'
        : '${status!.dailyVibeCount}/${status!.dailyVibeLimit}';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            canUpload ? Icons.radio_button_checked : Icons.radio_button_off,
            color: canUpload ? theme.colorScheme.primary : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '$count casts',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoloVibeCard extends StatelessWidget {
  const _SoloVibeCard({
    required this.item,
    required this.position,
    required this.total,
  });

  final VibeFeedItem item;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listenText = item.listenStartedAt == null
        ? 'Hold attention for 3 seconds'
        : item.canSwipeNow
            ? 'Swipe window open'
            : 'Signal warming up';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  username: item.username,
                  imageUrl: item.profilePictureUrl,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.username,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$position of $total in the room',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isGoldenVoice)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'GOLD',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 72,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${item.duration}s anonymous-first voice',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              listenText,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: item.canSwipeNow ? 1 : item.listenStartedAt == null ? .08 : .58,
                backgroundColor: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckControls extends StatelessWidget {
  const _DeckControls({
    required this.canGoBack,
    required this.canGoNext,
    required this.onBack,
    required this.onNext,
  });

  final bool canGoBack;
  final bool canGoNext;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.keyboard_arrow_left),
            label: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.keyboard_arrow_right),
            label: const Text('Next voice'),
          ),
        ),
      ],
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.username,
    required this.radius,
    this.imageUrl,
    super.key,
  });

  final String username;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty ? 'S' : username[0].toUpperCase();
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * .82,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.graphic_eq, size: 46),
              const SizedBox(height: 14),
              Text(
                'The room is quiet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'One voice will appear here at a time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
