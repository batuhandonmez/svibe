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
            tooltip: 'Edit profile',
            onPressed: user == null ? null : () => _showEditProfile(user),
            icon: const Icon(Icons.edit_outlined),
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
            _ProfileHeader(
              username: user?.username ?? 'svibe',
              displayName: displayName,
              bio: user?.bio,
              profilePictureUrl: user?.profilePictureUrl,
              photoBytes: _photoBytes,
              isUploadingPhoto: _isUploadingPhoto,
              status: status.asData?.value,
              onPhotoTap: _pickAndUploadPhoto,
              onEditTap: user == null ? null : () => _showEditProfile(user),
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
                    color: colors.elevated,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'public signal',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
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

  Future<void> _showEditProfile(UserProfile user) async {
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _EditProfileSheet(user: user),
    );
    if (updated == null || !mounted) {
      return;
    }
    ref.read(authControllerProvider).replaceUser(updated);
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.username,
    required this.displayName,
    required this.onPhotoTap,
    required this.isUploadingPhoto,
    this.bio,
    this.profilePictureUrl,
    this.photoBytes,
    this.status,
    this.onEditTap,
  });

  final String username;
  final String displayName;
  final String? bio;
  final String? profilePictureUrl;
  final Uint8List? photoBytes;
  final bool isUploadingPhoto;
  final UserStatus? status;
  final VoidCallback onPhotoTap;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBio = bio?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _EditableHeroAvatar(
              username: username,
              imageUrl: profilePictureUrl,
              bytes: photoBytes,
              isUploading: isUploadingPhoto,
              onTap: onPhotoTap,
            ),
            const SizedBox(width: 16),
            Expanded(child: _StatsRow(status: status)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '@$username',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          resolvedBio?.isNotEmpty == true
              ? resolvedBio!
              : 'One-card discovery, private signals, cast-ready.',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPhotoTap,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditTap,
                icon: const Icon(Icons.tune),
                label: const Text('Profile'),
              ),
            ),
          ],
        ),
      ],
    );
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
    final colors = theme.extension<SvibeColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.border, width: 8),
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.34 : 0.14,
                  ),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipOval(
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : ProfileAvatar(
                      username: username,
                      imageUrl: imageUrl,
                      radius: 47,
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.berry,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.user.displayName ?? '');
    _bio = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(apiClientProvider)
          .updateMe(
            token,
            displayName: _displayName.text.trim(),
            bio: _bio.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } on SvibeApiException catch (exception) {
      if (mounted) {
        setState(() => _error = exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.berry.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.badge_outlined, color: colors.berry),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit profile',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _displayName,
            textInputAction: TextInputAction.next,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 4,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'Bio',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isSaving ? 'Saving' : 'Save profile'),
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
    final colors = theme.extension<SvibeColors>()!;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.elevated,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
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
    final colors = theme.extension<SvibeColors>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
        color: colors.elevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                  '${vibe.duration}s - ${vibe.swipeRightCount} likes',
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
            color: vibe.isGoldenVoice ? colors.lime : colors.berry,
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
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
