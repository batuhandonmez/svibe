import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/api/api_client.dart';
import '../../core/motion/motion_trigger.dart';
import '../../core/models/svibe_models.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({
    required this.onOpenDm,
    required this.onOpenCast,
    super.key,
  });

  final VoidCallback onOpenDm;
  final VoidCallback onOpenCast;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late final AnimationController _waveController;
  StreamSubscription<ProcessingState>? _stateSubscription;
  VibeFeedItem? _item;
  bool _isLoading = true;
  bool _isLocked = true;
  bool _isAdvancing = false;
  String? _error;
  Timer? _unlockTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _stateSubscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !_isAdvancing) {
        _loadNext();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNext());
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _stateSubscription?.cancel();
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadNext() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null || _isAdvancing) {
      return;
    }
    _isAdvancing = true;
    _unlockTimer?.cancel();
    setState(() {
      _isLoading = true;
      _isLocked = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final next = await api.discoverNext(token);
      await _player.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _item = next;
        _isLoading = false;
      });
      if (next != null) {
        await api.startListening(token, next.id);
        await _player.setUrl(next.audioUrl);
        await _player.play();
        _unlockTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isLocked = false);
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
    } on PlayerException catch (_) {
      if (mounted) {
        setState(() {
          _error = 'This voice could not be played.';
          _isLoading = false;
        });
      }
    } finally {
      _isAdvancing = false;
    }
  }

  Future<void> _togglePlayback() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _swipe(String direction) async {
    final item = _item;
    final token = ref.read(authControllerProvider).token;
    if (item == null || token == null || _isLocked) {
      return;
    }
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
    await ref
        .read(apiClientProvider)
        .swipeVibe(
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _ProfilePreview(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userStatusProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Svibe'),
        actions: [
          _CastButton(onPressed: widget.onOpenCast),
          const SizedBox(width: 8),
          _DmButton(onPressed: widget.onOpenDm),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
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
                        player: _player,
                        waveController: _waveController,
                        isLocked: _isLocked,
                        onLike: () => _swipe('like'),
                        onDislike: () => _swipe('dislike'),
                        onOpenProfile: _openProfileIntent,
                        onTogglePlayback: _togglePlayback,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                'Discovery signal active',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CastButton extends StatelessWidget {
  const _CastButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    return IconButton.filled(
      tooltip: 'Cast',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.orange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          side: BorderSide(color: theme.colorScheme.onSurface, width: 1.5),
        ),
      ),
      icon: const Icon(Icons.near_me),
    );
  }
}

class _DmButton extends StatelessWidget {
  const _DmButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          tooltip: 'DM',
          onPressed: onPressed,
          icon: const Icon(Icons.mail_outline),
        ),
        Positioned(
          right: 7,
          top: 8,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: theme.extension<SvibeColors>()!.berry,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
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
    final colors = theme.extension<SvibeColors>()!;
    final canUpload = status?.canUploadVibe ?? false;
    final privacy = status?.isPrivate == true ? 'Private' : 'Public';
    final count = status == null
        ? '--'
        : '${status!.dailyVibeCount}/${status!.dailyVibeLimit}';
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: canUpload ? colors.lime : colors.lilac,
              shape: BoxShape.circle,
            ),
            child: Icon(
              canUpload ? Icons.graphic_eq : Icons.hearing,
              color: Colors.black,
              size: 17,
            ),
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

class _DiscoveryCard extends StatefulWidget {
  const _DiscoveryCard({
    required this.item,
    required this.player,
    required this.waveController,
    required this.isLocked,
    required this.onLike,
    required this.onDislike,
    required this.onOpenProfile,
    required this.onTogglePlayback,
  });

  final VibeFeedItem item;
  final AudioPlayer player;
  final Animation<double> waveController;
  final bool isLocked;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onOpenProfile;
  final VoidCallback onTogglePlayback;

  @override
  State<_DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<_DiscoveryCard> {
  Offset _drag = Offset.zero;

  VibeFeedItem get item => widget.item;
  AudioPlayer get player => widget.player;
  Animation<double> get waveController => widget.waveController;
  bool get isLocked => widget.isLocked;
  VoidCallback get onLike => widget.onLike;
  VoidCallback get onDislike => widget.onDislike;
  VoidCallback get onOpenProfile => widget.onOpenProfile;
  VoidCallback get onTogglePlayback => widget.onTogglePlayback;

  void _resetDrag() {
    if (mounted) {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    final name = item.displayName?.isNotEmpty == true
        ? item.displayName!
        : item.username;
    final stamp = _drag.dx > 32
        ? _SwipeStampKind.like
        : _drag.dx < -32
        ? _SwipeStampKind.pass
        : null;
    final rotation = (_drag.dx / 900).clamp(-0.10, 0.10);
    return GestureDetector(
      onTap: onOpenProfile,
      onPanUpdate: isLocked
          ? null
          : (details) {
              setState(() {
                _drag = Offset(
                  (_drag.dx + details.delta.dx).clamp(-130.0, 130.0),
                  (_drag.dy + details.delta.dy).clamp(-70.0, 70.0),
                );
              });
            },
      onPanCancel: _resetDrag,
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        if (_drag.dx > 88 || velocity.dx > 360) {
          _resetDrag();
          onLike();
        } else if (_drag.dx < -88 || velocity.dx < -360) {
          _resetDrag();
          onDislike();
        } else if (!isLocked && (_drag.dy < -52 || velocity.dy < -300)) {
          _resetDrag();
          onOpenProfile();
        } else {
          _resetDrag();
        }
      },
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(_drag.dx, _drag.dy)
                ..rotateZ(rotation),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.24
                                : 0.08,
                          ),
                          blurRadius: 26,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ProfileAvatar(
                              username: item.username,
                              imageUrl: item.profilePictureUrl,
                              radius: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '@${item.username} - ${item.duration}s',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.isGoldenVoice)
                              _GoldenChip(color: colors.orange),
                          ],
                        ),
                        const Spacer(),
                        StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing =
                                snapshot.data?.playing ?? player.playing;
                            return InkWell(
                              borderRadius: BorderRadius.circular(180),
                              onTap: onTogglePlayback,
                              child: _WaveStage(
                                controller: waveController,
                                active: playing,
                                golden: item.isGoldenVoice,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        Text(
                          isLocked ? 'Signal opening' : 'Signal open',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLocked
                              ? 'The first three seconds are for listening.'
                              : item.isGoldenVoice
                              ? 'Golden Voice is awake.'
                              : 'Ready for your read.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ListenGate(player: player, isLocked: isLocked),
                        const SizedBox(height: 12),
                        _ProgressBar(player: player),
                      ],
                    ),
                  ),
                  if (stamp != null)
                    Positioned(
                      top: 92,
                      left: stamp == _SwipeStampKind.pass ? 24 : null,
                      right: stamp == _SwipeStampKind.like ? 24 : null,
                      child: _SwipeStamp(
                        kind: stamp,
                        opacity: (_drag.dx.abs() / 120).clamp(0.0, 1.0),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SignalButton(
                icon: Icons.close,
                enabled: !isLocked,
                color: theme.colorScheme.surface,
                foreground: theme.colorScheme.onSurface,
                border: theme.colorScheme.outline,
                onTap: onDislike,
              ),
              const SizedBox(width: 24),
              _SignalButton(
                icon: Icons.favorite,
                enabled: !isLocked,
                color: colors.berry,
                foreground: Colors.white,
                onTap: onLike,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SwipeStampKind { like, pass }

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.kind, required this.opacity});

  final _SwipeStampKind kind;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SvibeColors>()!;
    final isLike = kind == _SwipeStampKind.like;
    final color = isLike
        ? colors.berry
        : Theme.of(context).colorScheme.onSurface;
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: isLike ? -0.16 : 0.16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isLike
                ? colors.berry.withValues(alpha: 0.14)
                : Theme.of(context).colorScheme.surface,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Text(
            isLike ? 'LIKE' : 'PASS',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListenGate extends StatelessWidget {
  const _ListenGate({required this.player, required this.isLocked});

  final AudioPlayer player;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final seconds = snapshot.data?.inMilliseconds ?? 0;
        final progress = (seconds / 3000).clamp(0.0, 1.0);
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: isLocked ? progress : 1,
                minHeight: 8,
                color: isLocked ? colors.lilac : colors.lime,
                backgroundColor: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLocked ? Icons.hearing : Icons.bolt,
                  size: 16,
                  color: isLocked ? colors.lilac : colors.lime,
                ),
                const SizedBox(width: 6),
                Text(
                  isLocked ? 'listening gate' : 'choice unlocked',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GoldenChip extends StatelessWidget {
  const _GoldenChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'GOLD',
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WaveStage extends StatelessWidget {
  const _WaveStage({
    required this.controller,
    required this.active,
    required this.golden,
  });

  final Animation<double> controller;
  final bool active;
  final bool golden;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SvibeColors>()!;
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(280, 210),
            painter: _WavePainter(
              tick: controller.value,
              color: golden ? colors.lime : colors.berry,
              active: active,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.tick,
    required this.color,
    required this.active,
  });

  final double tick;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final center = size.height / 2;
    const bars = 29;
    final gap = size.width / (bars - 1);
    for (var i = 0; i < bars; i++) {
      final pulse = active
          ? math.sin((tick * math.pi * 2) + i * .72).abs()
          : .2;
      final height = 20 + pulse * (i.isEven ? 92 : 72);
      final x = i * gap;
      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.tick != tick ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.duration ?? Duration.zero;
        final total = duration.inMilliseconds;
        final progress = total <= 0
            ? 0.0
            : (position.inMilliseconds / total).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.outline,
          ),
        );
      },
    );
  }
}

class _SignalButton extends StatelessWidget {
  const _SignalButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.foreground,
    required this.onTap,
    this.border,
  });

  final IconData icon;
  final bool enabled;
  final Color color;
  final Color foreground;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .38,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Icon(icon, color: foreground, size: 33),
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
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).extension<SvibeColors>()!.lilac,
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
            const Icon(Icons.radar, size: 48),
            const SizedBox(height: 14),
            Text(
              'No public voices yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'New public vibes will flow here one by one.',
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
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
    _shakeMotion = MotionTrigger(threshold: 20, onTrigger: _unlock)..start();
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
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shake your vibe',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Golden Voice found. Shake the phone to unlock your signal.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          _GoldenRitualCard(color: colors.orange),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isUnlocking ? null : _unlock,
            icon: const Icon(Icons.graphic_eq),
            label: Text(_isUnlocking ? 'Unlocking...' : 'Unlock manually'),
          ),
        ],
      ),
    );
  }
}

class _GoldenRitualCard extends StatelessWidget {
  const _GoldenRitualCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 184,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _GoldenRitualPainter())),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.ink,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(Icons.vibration, size: 46, color: color),
          ),
          Positioned(
            right: 24,
            top: 24,
            child: Icon(Icons.auto_awesome, color: AppTheme.ink),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: Icon(Icons.auto_awesome, color: AppTheme.ink),
          ),
        ],
      ),
    );
  }
}

class _GoldenRitualPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.ink.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final inset = 18.0 + i * 22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset * .55,
            size.width - inset * 2,
            size.height - inset * 1.1,
          ),
          const Radius.circular(38),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldenRitualPainter oldDelegate) => false;
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
          Center(
            child: ProfileAvatar(
              username: item.username,
              imageUrl: item.profilePictureUrl,
              radius: 42,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '@${item.username}',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'likes',
                  value: '${item.swipeRightCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(label: 'duration', value: '${item.duration}s'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'signal',
                  value: item.isGoldenVoice ? 'Gold' : 'Public',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.extension<SvibeColors>()!.elevated,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
