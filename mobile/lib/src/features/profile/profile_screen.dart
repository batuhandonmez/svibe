import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Uint8List? _photoBytes;
  bool _isUploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final status = ref.watch(userStatusProvider);
    final statusValue = status.asData?.value;
    final user = auth.user;
    final theme = Theme.of(context);
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.username ?? 'Svibe';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditableAvatar(
                      username: user?.username ?? 'Svibe',
                      imageUrl: user?.profilePictureUrl,
                      bytes: _photoBytes,
                      isUploading: _isUploadingPhoto,
                      onTap: _pickAndUploadPhoto,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user?.username ?? 'svibe'}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _pickAndUploadPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Add photo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  user?.bio?.isNotEmpty == true
                      ? user!.bio!
                      : 'Seslerin profilinde yaşar; açık olanlar keşfe düşer.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                status.when(
                  data: (value) => Row(
                    children: [
                      _ProfileMetric(
                        label: 'Casts',
                        value: '${value?.dailyVibeCount ?? 0}',
                      ),
                      _ProfileMetric(
                        label: 'Privacy',
                        value: value?.isPrivate == true ? 'Private' : 'Public',
                      ),
                      _ProfileMetric(
                        label: 'DM',
                        value: _dmLabel(value?.messagePrivacy ?? 'everyone'),
                      ),
                    ],
                  ),
                  error: (_, __) => const Text('Status unavailable'),
                  loading: () => const LinearProgressIndicator(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsPanel(
            isPrivate: statusValue?.isPrivate ?? false,
            messagePrivacy: statusValue?.messagePrivacy ?? 'everyone',
            onPrivacyChanged: _setPrivacy,
            onDmChanged: _setDmPrivacy,
          ),
        ],
      ),
    );
  }

  String _dmLabel(String value) {
    return switch (value) {
      'followers' => 'Followers',
      'off' => 'Off',
      _ => 'Everyone',
    };
  }

  Future<void> _setPrivacy(bool value) async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    if (token == null) {
      return;
    }
    final updated = await ref.read(apiClientProvider).updateMe(
          token,
          isPrivate: value,
        );
    auth.replaceUser(updated);
    ref.invalidate(userStatusProvider);
  }

  Future<void> _setDmPrivacy(String value) async {
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    if (token == null) {
      return;
    }
    final updated = await ref.read(apiClientProvider).updateMe(
          token,
          messagePrivacy: value,
        );
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
      await ref.read(apiClientProvider).uploadProfilePhoto(
            token,
            bytes: bytes,
            filename: file.name,
          );
      final updated = await ref.read(apiClientProvider).me(token);
      ref.read(authControllerProvider).replaceUser(updated);
    } on SvibeApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
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
    final initial = username.isEmpty ? 'S' : username[0].toUpperCase();
    ImageProvider? image;
    if (bytes != null) {
      image = MemoryImage(bytes!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = NetworkImage(imageUrl!);
    }
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            backgroundImage: image,
            child: image == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          if (isUploading) const CircularProgressIndicator(strokeWidth: 2),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 3,
                ),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.black, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.isPrivate,
    required this.messagePrivacy,
    required this.onPrivacyChanged,
    required this.onDmChanged,
  });

  final bool isPrivate;
  final String messagePrivacy;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<String> onDmChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Private account'),
            subtitle: const Text('Gizli hesapların sesleri keşfe düşmez.'),
            value: isPrivate,
            onChanged: onPrivacyChanged,
          ),
          const Divider(height: 26),
          Text(
            'DM permissions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'everyone', label: Text('All')),
              ButtonSegment(value: 'followers', label: Text('Followers')),
              ButtonSegment(value: 'off', label: Text('Off')),
            ],
            selected: {messagePrivacy},
            onSelectionChanged: (value) => onDmChanged(value.first),
          ),
        ],
      ),
    );
  }
}
