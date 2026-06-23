import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/svibe_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/auth_controller.dart';
import '../cast/cast_screen.dart';
import '../dm/dm_screen.dart';
import '../feed/feed_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.refreshTick = 0, super.key});

  final int refreshTick;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _archivePlayer = AudioPlayer();
  StreamSubscription<ProcessingState>? _archivePlayerSub;
  Uint8List? _photoBytes;
  bool _isUploadingPhoto = false;
  Future<List<VibeFeedItem>>? _vibesFuture;
  String? _playingVibeId;

  @override
  void initState() {
    super.initState();
    _archivePlayerSub = _archivePlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && mounted) {
        setState(() => _playingVibeId = null);
      }
    });
  }

  @override
  void dispose() {
    _archivePlayerSub?.cancel();
    _archivePlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vibesFuture ??= _loadVibes();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _refreshVibes();
    }
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
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.username ?? 'Svibe';

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          tooltip: 'Log out',
          onPressed: () => ref.read(authControllerProvider).logout(),
          icon: const Icon(Icons.menu),
        ),
        title: const Center(child: Text('svibe')),
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DmInboxScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshVibes(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 32, 26, 132),
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
              onSettingsTap: () => _showSettingsSheet(status.asData?.value),
            ),
            const SizedBox(height: 46),
            const Row(
              children: [
                Icon(Icons.graphic_eq, color: Color(0xFFE8E4DE), size: 24),
                SizedBox(width: 12),
                Text(
                  'Recent Archives',
                  style: TextStyle(
                    color: Color(0xFFF0ECE6),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
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
                  return _EmptyVibes(
                    onCastHint: () async {
                      final didCast = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => const CastScreen(),
                        ),
                      );
                      if (didCast == true && context.mounted) {
                        _refreshVibes();
                      }
                    },
                  );
                }
                return _RecentArchiveList(
                  vibes: vibes,
                  playingVibeId: _playingVibeId,
                  onPlay: _playArchive,
                  onDelete: _deleteArchive,
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

  Future<void> _showSettingsSheet(UserStatus? status) async {
    final themeMode = ref.read(themeControllerProvider).mode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _SettingsPanel(
          isPrivate: status?.isPrivate ?? false,
          messagePrivacy: status?.messagePrivacy ?? 'everyone',
          themeMode: themeMode,
          onPrivacyChanged: _setPrivacy,
          onDmChanged: _setDmPrivacy,
          onThemeModeChanged: (value) =>
              ref.read(themeControllerProvider).setMode(value),
        ),
      ),
    );
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

  Future<void> _playArchive(VibeFeedItem vibe) async {
    try {
      if (_playingVibeId == vibe.id && _archivePlayer.playing) {
        await _archivePlayer.pause();
        if (mounted) {
          setState(() => _playingVibeId = null);
        }
        return;
      }
      await _archivePlayer.stop();
      await _archivePlayer.setUrl(vibe.audioUrl);
      if (mounted) {
        setState(() => _playingVibeId = vibe.id);
      }
      await _archivePlayer.play();
    } on Object {
      if (mounted) {
        setState(() => _playingVibeId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This archive could not be played.')),
        );
      }
    }
  }

  Future<void> _deleteArchive(VibeFeedItem vibe) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this vibe?'),
        content: const Text('This removes it from your profile and discovery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      if (_playingVibeId == vibe.id) {
        await _archivePlayer.stop();
        setState(() => _playingVibeId = null);
      }
      await ref.read(apiClientProvider).deleteVibe(token, vibe.id);
      _refreshVibes();
      ref.invalidate(userStatusProvider);
    } on SvibeApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
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
    required this.onSettingsTap,
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
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Color(0xFFF0ECE6),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Color(0xFFC0BBB4),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          resolvedBio?.isNotEmpty == true
              ? resolvedBio!
              : 'Sound designer & ambient explorer. Curating field recordings and late-night thoughts. Listening more than speaking.',
          style: const TextStyle(
            color: Color(0xFFE6E1DA),
            fontSize: 19,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        _StatsRow(status: status),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onEditTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2928),
                  foregroundColor: const Color(0xFFF0ECE6),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton(
                onPressed: onSettingsTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF0ECE6),
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: Color(0xFF2E2C2B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Settings'),
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
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF252525), width: 5),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF111111), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .42),
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
                      radius: 56,
                    ),
            ),
          ),
          Positioned(
            right: 5,
            bottom: 12,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D2CC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF111111), width: 2),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
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
        const SizedBox(width: 42),
        _ProfileMetric(
          label: 'Following',
          value: '${status?.followingCount ?? 0}',
        ),
        const SizedBox(width: 42),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF0ECE6),
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC0BBB4),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

class _RecentArchiveList extends StatelessWidget {
  const _RecentArchiveList({
    required this.vibes,
    required this.playingVibeId,
    required this.onPlay,
    required this.onDelete,
  });

  final List<VibeFeedItem> vibes;
  final String? playingVibeId;
  final ValueChanged<VibeFeedItem> onPlay;
  final ValueChanged<VibeFeedItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < vibes.length; i++) ...[
          _ArchiveTile(
            vibe: vibes[i],
            isPlaying: playingVibeId == vibes[i].id,
            onPlay: () => onPlay(vibes[i]),
            onDelete: () => onDelete(vibes[i]),
          ),
          if (i != vibes.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.vibe,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  final VibeFeedItem vibe;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = vibe.isGoldenVoice
        ? 'Rare archive'
        : vibe.displayName?.trim().isNotEmpty == true
        ? vibe.displayName!.trim()
        : 'Voice archive';
    return Container(
      height: 82,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1C1B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF252322)),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: onPlay,
            style: IconButton.styleFrom(
              backgroundColor: isPlaying
                  ? const Color(0xFFE2DED6)
                  : const Color(0xFF2B2928),
              fixedSize: const Size(58, 58),
            ),
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: isPlaying
                  ? const Color(0xFF111111)
                  : const Color(0xFFE8E4DE),
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEDE9E3),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 116,
                  height: 18,
                  child: CustomPaint(
                    painter: _MiniWavePainter(color: const Color(0xFF8B8781)),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _duration(vibe.duration),
            style: const TextStyle(
              color: Color(0xFFD0CBC4),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            tooltip: 'Delete vibe',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFC0BBB4)),
          ),
        ],
      ),
    );
  }

  String _duration(int seconds) {
    final safe = seconds <= 0 ? 42 : seconds;
    return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
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
      ..strokeWidth = 3.5;
    const bars = 13;
    for (var i = 0; i < bars; i++) {
      final h = size.height * (0.24 + (i % 6) * 0.10);
      final x = i * size.width / (bars - 1);
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
    final colors = theme.extension<SvibeColors>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: colors.elevated,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: const Icon(Icons.graphic_eq, size: 36),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onCastHint,
            icon: const Icon(Icons.mic_external_on),
            label: const Text('Cast first vibe'),
          ),
        ],
      ),
    );
  }
}
