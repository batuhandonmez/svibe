import 'package:flutter/material.dart';

import '../cast/cast_screen.dart';
import '../dm/dm_screen.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openDm() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DmInboxScreen()));
  }

  void _openCast() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CastScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [FeedScreen(onOpenDm: _openDm), const ProfileScreen()];
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CastActionButton(onPressed: _openCast),
      bottomNavigationBar: BottomAppBar(
        height: 82,
        color: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 9,
        child: Row(
          children: [
            Expanded(
              child: _ShellTab(
                icon: Icons.travel_explore_outlined,
                activeIcon: Icons.travel_explore,
                label: 'Feed',
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
            ),
            const SizedBox(width: 84),
            Expanded(
              child: _ShellTab(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastActionButton extends StatelessWidget {
  const _CastActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: FloatingActionButton(
        heroTag: 'svibe-cast',
        onPressed: onPressed,
        elevation: 0,
        backgroundColor: theme.colorScheme.tertiary,
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        child: const Icon(Icons.graphic_eq, size: 34),
      ),
    );
  }
}

class _ShellTab extends StatelessWidget {
  const _ShellTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? activeIcon : icon,
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
