import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/svibe_models.dart';
import '../auth/auth_controller.dart';
import 'feed_providers.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final status = ref.watch(userStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Svibe'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(feedProvider);
              ref.invalidate(userStatusProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          ref.invalidate(userStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            status.when(
              data: (value) => _StatusStrip(status: value),
              error: (_, __) => const _StatusStrip(status: null),
              loading: () => const _StatusStrip(status: null, loading: true),
            ),
            const SizedBox(height: 16),
            feed.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyFeed();
                }
                return Column(
                  children: [
                    for (final item in items) ...[
                      VibeCard(item: item),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
              error: (error, _) => _ErrorState(message: error.toString()),
              loading: () => const _FeedSkeleton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, this.loading = false});

  final UserStatus? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUpload = status?.canUploadVibe ?? false;
    final label = loading
        ? 'Checking status'
        : canUpload
            ? 'Ready to cast'
            : 'Listen mode';
    final sublabel = status == null
        ? 'Backend status will appear here.'
        : '${status!.dailyVibeCount}/${status!.dailyVibeLimit} casts left';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              canUpload ? Icons.mic : Icons.hearing,
              color: canUpload ? theme.colorScheme.primary : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class VibeCard extends StatelessWidget {
  const VibeCard({required this.item, super.key});

  final VibeFeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listenState = item.listenStartedAt == null
        ? 'Tap to start listening'
        : item.canSwipeNow
            ? 'Swipe is unlocked'
            : 'Fuse is burning';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  username: item.username,
                  imageUrl: item.profilePictureUrl,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.username,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${item.duration}s voice note',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isGoldenVoice)
                  Tooltip(
                    message: 'Golden Voice',
                    child: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Play',
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: item.canSwipeNow ? 1 : item.listenStartedAt == null ? 0 : .55,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item.swipeRightCount}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.favorite, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    listenState,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: item.canSwipeNow ? () {} : null,
                  icon: const Icon(Icons.keyboard_arrow_right),
                  label: const Text('Swipe'),
                ),
              ],
            ),
          ],
        ),
      ),
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
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(imageUrl!));
    }
    return CircleAvatar(
      radius: radius,
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * .85, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: SizedBox(
              height: 148,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.graphic_eq, size: 42),
            const SizedBox(height: 12),
            Text(
              'No active voices yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'When people cast a vibe, it will land here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
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
