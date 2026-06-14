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
import '../dm/dm_screen.dart';

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
    with TickerProviderStateMixin {
  final _player = AudioPlayer();
  late final AnimationController _waveController;
  late final AnimationController _unlockController;
  StreamSubscription<ProcessingState>? _stateSubscription;
  VibeFeedItem? _item;
  bool _isLoading = true;
  bool _isLocked = true;
  bool _isAdvancing = false;
  bool _isSwipeSubmitting = false;
  String? _error;
  Timer? _unlockTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
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
    _unlockController.dispose();
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
    _unlockController.stop();
    _unlockController.reset();
    setState(() {
      _isLoading = true;
      _isLocked = true;
      _isSwipeSubmitting = false;
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
        _startUnlockCountdown();
        unawaited(
          _player.play().catchError((Object _) {
            // Browsers may block autoplay until the user taps. The listening
            // ritual still completes visually in the web demo.
          }),
        );
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

  void _startUnlockCountdown() {
    _unlockTimer?.cancel();
    const delay = Duration(seconds: 3);
    _unlockController.duration = delay;
    _unlockController.forward(from: 0);
    _unlockTimer = Timer(delay, () {
      if (mounted) {
        setState(() => _isLocked = false);
      }
    });
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
    if (item == null || token == null || _isLocked || _isSwipeSubmitting) {
      return;
    }
    setState(() {
      _isSwipeSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiClientProvider)
          .swipeVibe(token, item.id, direction: direction);
      if (!mounted) {
        return;
      }
      if (result.goldenVoiceUnlockPending) {
        setState(() => _isSwipeSubmitting = false);
        await _showGoldenVoiceRitual(item);
      } else {
        await _loadNext();
      }
    } on SvibeApiException catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception.message;
          _isSwipeSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmGoldenUnlock(VibeFeedItem item) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      return;
    }
    try {
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
    } on SvibeApiException catch (exception) {
      if (mounted) {
        setState(() => _error = exception.message);
      }
    }
  }

  Future<void> _showGoldenVoiceRitual(VibeFeedItem item) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Icon(Icons.graphic_eq),
        ),
        title: const Center(child: Text('svibe')),
        actions: [
          _DmButton(onPressed: widget.onOpenDm),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
          child: Column(
            children: [
              if (_error != null) _InlineError(message: _error!),
              if (_error != null) const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const _FeedSkeleton()
                    : _item == null
                    ? _EmptyFeed(onCast: widget.onOpenCast)
                    : _DiscoveryCard(
                        item: _item!,
                        player: _player,
                        waveController: _waveController,
                        unlockController: _unlockController,
                        isLocked: _isLocked || _isSwipeSubmitting,
                        onLike: () => _swipe('like'),
                        onDislike: () => _swipe('dislike'),
                        onOpenProfile: _openProfileIntent,
                        onTogglePlayback: _togglePlayback,
                      ),
              ),
            ],
          ),
        ),
      ),
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
              color: theme.colorScheme.onSurface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscoveryCard extends StatefulWidget {
  const _DiscoveryCard({
    required this.item,
    required this.player,
    required this.waveController,
    required this.unlockController,
    required this.isLocked,
    required this.onLike,
    required this.onDislike,
    required this.onOpenProfile,
    required this.onTogglePlayback,
  });

  final VibeFeedItem item;
  final AudioPlayer player;
  final Animation<double> waveController;
  final Animation<double> unlockController;
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
  Animation<double> get unlockController => widget.unlockController;
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
    final name = item.displayName?.isNotEmpty == true
        ? item.displayName!
        : item.username;
    final stamp = _drag.dx > 32
        ? _SwipeStampKind.like
        : _drag.dx < -32
        ? _SwipeStampKind.pass
        : null;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = math.min(constraints.maxHeight, 548.0);
          final cardWidth = math.min(constraints.maxWidth, 382.0);
          return Center(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Transform.translate(
                offset: Offset(_drag.dx, 0),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.extension<SvibeColors>()!.elevated,
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: .72,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.28
                                    : 0.08,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
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
                                  radius: 26,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      Text(
                                        '@${item.username}',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.isGoldenVoice) const _GoldenChip(),
                                if (!item.isGoldenVoice)
                                  _DurationPill(duration: item.duration),
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
                                  child: RepaintBoundary(
                                    child: _WaveStage(
                                      controller: waveController,
                                      active: playing,
                                      golden: item.isGoldenVoice,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                _InlineSignalIcon(
                                  icon: Icons.close,
                                  enabled: !isLocked,
                                  onTap: onDislike,
                                ),
                                Expanded(
                                  child: Text(
                                    isLocked ? 'LISTENING' : 'SWIPE',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.2,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                _InlineSignalIcon(
                                  icon: Icons.favorite_border,
                                  enabled: !isLocked,
                                  onTap: onLike,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _ProgressBar(player: player),
                          ],
                        ),
                      ),
                    ),
                    if (isLocked)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: unlockController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _CometBorderPainter(
                                    progress: unlockController.value,
                                    radius: AppTheme.cardRadius,
                                  ),
                                );
                              },
                            ),
                          ),
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
          );
        },
      ),
    );
  }
}

enum _SwipeStampKind { like, pass }

class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.duration});

  final int duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: .72),
        ),
      ),
      child: Text(
        '0:${duration.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.kind, required this.opacity});

  final _SwipeStampKind kind;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLike = kind == _SwipeStampKind.like;
    final color = theme.colorScheme.onSurface;
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: isLike ? -0.16 : 0.16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isLike
                ? theme.colorScheme.onSurface.withValues(alpha: 0.10)
                : theme.colorScheme.surface,
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

class _CometBorderPainter extends CustomPainter {
  const _CometBorderPainter({required this.progress, required this.radius});

  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final base = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, base);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }
    final metric = metrics.first;
    final length = metric.length;
    final head = (progress.clamp(0.0, 1.0) * length) % length;
    final cometLength = length * .18;
    final trailPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Colors.white],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: .88);

    void drawSegment(double start, double end) {
      if (end <= start) {
        return;
      }
      canvas.drawPath(metric.extractPath(start, end), trailPaint);
    }

    final start = head - cometLength;
    if (start < 0) {
      drawSegment(length + start, length);
      drawSegment(0, head);
    } else {
      drawSegment(start, head);
    }

    final tangent = metric.getTangentForOffset(head);
    if (tangent != null) {
      final glow = Paint()
        ..color = Colors.white.withValues(alpha: .92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(tangent.position, 3.8, glow);
      canvas.drawCircle(tangent.position, 1.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CometBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.radius != radius;
  }
}

class _GoldenChip extends StatelessWidget {
  const _GoldenChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .72),
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'RARE',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(170, 112),
            painter: _WavePainter(
              tick: controller.value,
              color: theme.colorScheme.onSurface,
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
      ..strokeWidth = 4.2;
    final center = size.height / 2;
    const bars = 17;
    final gap = size.width / (bars - 1);
    for (var i = 0; i < bars; i++) {
      final pulse = active
          ? math.sin((tick * math.pi * 2) + i * .72).abs()
          : .38;
      final distance = (i - (bars - 1) / 2).abs();
      final envelope = 1 - (distance / ((bars - 1) / 2)) * .58;
      final height = 22 + pulse * 52 * envelope;
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
            minHeight: 3,
            color: theme.colorScheme.onSurface.withValues(alpha: .62),
            backgroundColor: theme.colorScheme.outline.withValues(alpha: .42),
          ),
        );
      },
    );
  }
}

class _InlineSignalIcon extends StatelessWidget {
  const _InlineSignalIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      tooltip: enabled ? null : 'Listen first',
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        color: color.withValues(alpha: enabled ? .88 : .28),
        size: 30,
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
      backgroundColor: Theme.of(context).extension<SvibeColors>()!.blue,
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
  const _EmptyFeed({required this.onCast});

  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(26, 34, 26, 28),
          decoration: BoxDecoration(
            color: theme.extension<SvibeColors>()!.elevated,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Icon(
                  Icons.graphic_eq,
                  size: 42,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No public voices yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The feed will stay quiet until public vibes are ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCast,
                icon: const Icon(Icons.mic_external_on),
                label: const Text('Cast first signal'),
              ),
            ],
          ),
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
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const _GoldenRitualCard(),
          const SizedBox(height: 24),
          Text(
            'shake to unlock connection',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rare voice found. Shake your phone, or use the manual fallback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isUnlocking ? null : _unlock,
            icon: const Icon(Icons.vibration),
            label: Text(_isUnlocking ? 'Unlocking...' : 'Tap to unlock'),
          ),
          const SizedBox(height: 10),
          Text(
            'Manual unlock keeps the ritual accessible on every device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldenRitualCard extends StatelessWidget {
  const _GoldenRitualCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).extension<SvibeColors>()!.elevated,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _GoldenRitualPainter())),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .16),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.vibration,
              size: 46,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Positioned(
            right: 28,
            top: 28,
            child: Icon(
              Icons.graphic_eq,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Positioned(
            left: 28,
            bottom: 28,
            child: Icon(
              Icons.graphic_eq,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
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

class _ProfilePreview extends ConsumerStatefulWidget {
  const _ProfilePreview({required this.item});

  final VibeFeedItem item;

  @override
  ConsumerState<_ProfilePreview> createState() => _ProfilePreviewState();
}

class _ProfilePreviewState extends ConsumerState<_ProfilePreview> {
  bool _isStartingDm = false;

  VibeFeedItem get item => widget.item;

  Future<void> _startDm() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null || _isStartingDm) {
      return;
    }
    setState(() => _isStartingDm = true);
    try {
      final thread = await ref
          .read(apiClientProvider)
          .createDmThread(token, item.userId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DmInboxScreen(initialThread: thread),
        ),
      );
    } on SvibeApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingDm = false);
      }
    }
  }

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
                  value: item.isGoldenVoice ? 'Rare' : 'Public',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isStartingDm ? null : _startDm,
            icon: _isStartingDm
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline),
            label: Text(_isStartingDm ? 'Opening...' : 'Message'),
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
