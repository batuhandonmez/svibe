import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/motion/motion_trigger.dart';
import '../../core/models/svibe_models.dart';
import '../auth/auth_controller.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  VibeFeedItem? _item;
  bool _isLoading = true;
  bool _isLocked = true;
  String? _error;
  Timer? _unlockTimer;
  Timer? _autoplayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNext());
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _autoplayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNext() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    if (token == null) {
      return;
    }
    _unlockTimer?.cancel();
    _autoplayTimer?.cancel();
    setState(() {
      _isLoading = true;
      _isLocked = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final next = await api.discoverNext(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _item = next;
        _isLoading = false;
      });
      if (next != null) {
        await api.startListening(token, next.id);
        _unlockTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isLocked = false);
          }
        });
        _autoplayTimer = Timer(Duration(seconds: next.duration.clamp(4, 30)), () {
          if (mounted) {
            _loadNext();
          }
        });
      }
    } on SvibeApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _swipe(String direction) async {
    final item = _item;
    final token = ref.read(authControllerProvider).token;
    if (item == null || token == null || _isLocked) {
      return;
    }
    _autoplayTimer?.cancel();
    try {
      final result = await ref
          .read(apiClientProvider)
          .swipeVibe(token, item.id, direction: direction);
      if (!mounted) {
        return;
      }
      if (result.goldenVoiceUnlockPending) {
        await _showGoldenVoiceRitual(item);
      } else {
        await _loadNext();
      }
    } on SvibeApiException catch (exception) {
      if (mounted) {
        setState(() => _error = exception.message);
      }
    }
  }

  Future<void> _confirmGoldenUnlock(VibeFeedItem item) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      return;
    }
    await ref.read(apiClientProvider).swipeVibe(
          token,
          item.id,
          direction: 'like',
          goldenUnlockConfirmed: true,
        );
    ref.invalidate(userStatusProvider);
    await _loadNext();
  }

  Future<void> _showGoldenVoiceRitual(VibeFeedItem item) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _GoldenVoiceSheet(
          onUnlock: () async {
            Navigator.of(context).pop();
            await _confirmGoldenUnlock(item);
          },
        );
      },
    );
  }

  void _openProfileIntent() {
    final item = _item;
    if (item == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ProfilePreview(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userStatusProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Svibe'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadNext,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            children: [
              status.when(
                data: (value) => _StatusRail(status: value),
                error: (_, __) => const _StatusRail(status: null),
                loading: () => const _StatusRail(status: null, loading: true),
              ),
              const SizedBox(height: 14),
              if (_error != null) _InlineError(message: _error!),
              if (_error != null) const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const _FeedSkeleton()
                    : _item == null
                        ? const _EmptyFeed()
                        : _DiscoveryCard(
                            item: _item!,
                            isLocked: _isLocked,
                            onLike: () => _swipe('like'),
                            onDislike: () => _swipe('dislike'),
                            onOpenProfile: _openProfileIntent,
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
    final privacy = status?.isPrivate == true ? 'Private' : 'Public';
    final count = status == null
        ? '--'
        : '${status!.dailyVibeCount}/${status!.dailyVibeLimit}';
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            canUpload ? Icons.mic : Icons.hearing,
            color: canUpload ? theme.colorScheme.primary : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading ? 'Checking signal' : privacy,
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

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.item,
    required this.isLocked,
    required this.onLike,
    required this.onDislike,
    required this.onOpenProfile,
  });

  final VibeFeedItem item;
  final bool isLocked;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item.displayName?.isNotEmpty == true
        ? item.displayName!
        : item.username;
    return GestureDetector(
      onTap: onOpenProfile,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 180) {
          onLike();
        } else if (velocity < -180) {
          onDislike();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) {
          onOpenProfile();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(10),
        ),
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
                        name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '@${item.username}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isGoldenVoice)
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              ],
            ),
            const Spacer(),
            _WaveDisc(isLocked: isLocked),
            const Spacer(),
            Text(
              isLocked ? 'Listen first' : 'Choose the signal',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLocked
                  ? '3 saniye dolunca like/dislike açılır.'
                  : 'Sola pass, sağa like, yukarı profil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLocked ? null : onDislike,
                    icon: const Icon(Icons.close),
                    label: const Text('Pass'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLocked ? null : onLike,
                    icon: const Icon(Icons.favorite),
                    label: const Text('Like'),
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

class _WaveDisc extends StatelessWidget {
  const _WaveDisc({required this.isLocked});

  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Center(
          child: Container(
            width: 138,
            height: 138,
            decoration: BoxDecoration(
              color: isLocked
                  ? theme.colorScheme.surface
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary),
            ),
            child: Icon(
              isLocked ? Icons.lock_clock : Icons.graphic_eq,
              color: isLocked ? theme.colorScheme.primary : Colors.black,
              size: 56,
            ),
          ),
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
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.black,
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
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 46),
            const SizedBox(height: 14),
            Text(
              'No public voices yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Açık hesaplardan yeni bir ses düştüğünde burada tek tek akar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _GoldenVoiceSheet extends StatefulWidget {
  const _GoldenVoiceSheet({required this.onUnlock});

  final Future<void> Function() onUnlock;

  @override
  State<_GoldenVoiceSheet> createState() => _GoldenVoiceSheetState();
}

class _GoldenVoiceSheetState extends State<_GoldenVoiceSheet> {
  late final MotionTrigger _shakeMotion;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _shakeMotion = MotionTrigger(
      threshold: 20,
      onTrigger: _unlock,
    )..start();
  }

  @override
  void dispose() {
    _shakeMotion.stop();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_isUnlocking) {
      return;
    }
    setState(() => _isUnlocking = true);
    await widget.onUnlock();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shake your vibe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Golden Voice found. Shake the phone to unlock, or use the fallback.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isUnlocking ? null : _unlock,
            icon: const Icon(Icons.vibration),
            label: Text(_isUnlocking ? 'Unlocking...' : 'Unlock voice'),
          ),
        ],
      ),
    );
  }
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({required this.item});

  final VibeFeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item.displayName?.isNotEmpty == true
        ? item.displayName!
        : item.username;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfileAvatar(
                username: item.username,
                imageUrl: item.profilePictureUrl,
                radius: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '@${item.username}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Follow'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('DM'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
