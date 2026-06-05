import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../feed/feed_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final status = ref.watch(userStatusProvider);
    final user = auth.user;

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(
                        username: user?.username ?? 'Svibe',
                        imageUrl: user?.profilePictureUrl,
                        radius: 42,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.username ?? 'Svibe user',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.isVip == true ? 'Founder voice' : 'Listener',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  status.when(
                    data: (value) => Row(
                      children: [
                        _ProfileMetric(
                          label: 'Casts',
                          value: '${value?.dailyVibeCount ?? 0}',
                        ),
                        _ProfileMetric(
                          label: 'Limit',
                          value: '${value?.dailyVibeLimit ?? 0}',
                        ),
                        _ProfileMetric(
                          label: 'Mode',
                          value: value?.isMuted == true ? 'Muted' : 'Open',
                        ),
                      ],
                    ),
                    error: (_, __) => const Text('Status unavailable'),
                    loading: () => const LinearProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: const [
                _ProfileAction(
                  icon: Icons.image_outlined,
                  title: 'Profile photo',
                  subtitle: 'URL based for now; upload comes later.',
                ),
                Divider(height: 1),
                _ProfileAction(
                  icon: Icons.graphic_eq,
                  title: 'Your voice archive',
                  subtitle: 'Personal vibe history will live here.',
                ),
                Divider(height: 1),
                _ProfileAction(
                  icon: Icons.shield_outlined,
                  title: 'Account safety',
                  subtitle: 'Token based session is active.',
                ),
              ],
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
