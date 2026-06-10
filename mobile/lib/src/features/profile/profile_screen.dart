import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/models/svibe_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/auth_controller.dart';
import '../feed/feed_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Uint8List? _photoBytes;
  bool _isUploadingPhoto = false;
  Future<List<VibeFeedItem>>? _vibesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vibesFuture ??= _loadVibes();
  }

  Future<List<VibeFeedItem>> _loadVibes() {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      return Future.value([]);
    }
    return ref.read(apiClientProvider).myVibes(token);
  }

  void _refreshVibes() {
    setState(() => _vibesFuture = _loadVibes());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final status = ref.watch(userStatusProvider);
    final user = auth.user;
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    final themeMode = ref.watch(themeControllerProvider).mode;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.username ?? 'Svibe';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh vibes',
            onPressed: _refreshVibes,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshVibes(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
          children: [
            Center(
              child: _EditableHeroAvatar(
                username: user?.username ?? 'Svibe',
                imageUrl: user?.profilePictureUrl,
                bytes: _photoBytes,
                isUploading: _isUploadingPhoto,
                onTap: _pickAndUploadPhoto,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${user?.username ?? 'svibe'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.bio?.isNotEmpty == true
                  ? user!.bio!
                  : 'Your public vibes enter discovery. Private mode keeps them close.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            status.when(
              data: (value) => _StatsRow(status: value),
              error: (_, __) => const Text('Status unavailable'),
              loading: () => const LinearProgressIndicator(),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _pickAndUploadPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Change profile photo'),
            ),
            const SizedBox(height: 18),
            _SettingsPanel(
              isPrivate: status.asData?.value?.isPrivate ?? false,
              messagePrivacy:
                  status.asData?.value?.messagePrivacy ?? 'everyone',
              themeMode: themeMode,
              onPrivacyChanged: _setPrivacy,
              onDmChanged: _setDmPrivacy,
              onThemeModeChanged: (value) =>
                  ref.read(themeControllerProvider).setMode(value),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Text(
                  'Vibes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.lime,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'public signal',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<VibeFeedItem>>(
              future: _vibesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final vibes = snapshot.data ?? [];
                if (vibes.isEmpty) {
                  return _EmptyVibes(onCastHint: () {});
                }
                return Column(
                  children: [
                    for (final vibe in vibes) ...[
                      _VibeRow(vibe: vibe),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrivacy(bool value) async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    if (token == null) {
      return;
    }
    final updated = await ref
        .read(apiClientProvider)
        .updateMe(token, isPrivate: value);
    auth.replaceUser(updated);
    ref.invalidate(userStatusProvider);
  }

  Future<void> _setDmPrivacy(String value) async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    if (token == null) {
      return;
    }
    final updated = await ref
        .read(apiClientProvider)
        .updateMe(token, messagePrivacy: value);
    auth.replaceUser(updated);
    ref.invalidate(userStatusProvider);
  }

  Future<void> _pickAndUploadPhoto() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1200,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _photoBytes = bytes;
      _isUploadingPhoto = true;
    });
    try {
      await ref
          .read(apiClientProvider)
          .uploadProfilePhoto(token, bytes: bytes, filename: file.name);
      final updated = await ref.read(apiClientProvider).me(token);
      ref.read(authControllerProvider).replaceUser(updated);
    } on SvibeApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }
}

class _EditableHeroAvatar extends StatelessWidget {
  const _EditableHeroAvatar({
    required this.username,
    required this.onTap,
    required this.isUploading,
    this.imageUrl,
    this.bytes,
  });

  final String username;
  final String? imageUrl;
  final Uint8List? bytes;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline, width: 2),
            ),
            child: ClipOval(
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : ProfileAvatar(
                      username: username,
                      imageUrl: imageUrl,
                      radius: 66,
                    ),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 6,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.status});

  final UserStatus? status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProfileMetric(
          label: 'Followers',
          value: '${status?.followersCount ?? 0}',
        ),
        _ProfileMetric(
          label: 'Following',
          value: '${status?.followingCount ?? 0}',
        ),
        _ProfileMetric(label: 'Vibes', value: '${status?.vibesCount ?? 0}'),
      ],
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.isPrivate,
    required this.messagePrivacy,
    required this.themeMode,
    required this.onPrivacyChanged,
    required this.onDmChanged,
    required this.onThemeModeChanged,
  });

  final bool isPrivate;
  final String messagePrivacy;
  final ThemeMode themeMode;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<String> onDmChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Private account',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Private vibes stay out of discovery.'),
            value: isPrivate,
            onChanged: onPrivacyChanged,
          ),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'DM privacy',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'everyone', label: Text('All')),
              ButtonSegment(value: 'followers', label: Text('Followers')),
              ButtonSegment(value: 'off', label: Text('Off')),
            ],
            selected: {messagePrivacy},
            onSelectionChanged: (values) => onDmChanged(values.first),
          ),
          const Divider(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.phone_iphone, size: 18),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (values) => onThemeModeChanged(values.first),
          ),
        ],
      ),
    );
  }
}

class _VibeRow extends StatelessWidget {
  const _VibeRow({required this.vibe});

  final VibeFeedItem vibe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 46,
            child: CustomPaint(
              painter: _MiniWavePainter(
                color: vibe.isGoldenVoice ? colors.lime : colors.berry,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vibe.isGoldenVoice ? 'Golden voice' : 'Public vibe',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${vibe.duration}s · ${vibe.swipeRightCount} likes',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            vibe.isGoldenVoice ? Icons.auto_awesome : Icons.favorite,
            color: vibe.isGoldenVoice ? colors.orange : colors.berry,
          ),
        ],
      ),
    );
  }
}

class _MiniWavePainter extends CustomPainter {
  const _MiniWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = 0; i < 11; i++) {
      final h = 12 + (i % 5) * 7.0;
      final x = i * size.width / 10;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _EmptyVibes extends StatelessWidget {
  const _EmptyVibes({required this.onCastHint});

  final VoidCallback onCastHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.graphic_eq, size: 42),
          const SizedBox(height: 10),
          Text(
            'No vibes yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cast your first voice to fill this profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
