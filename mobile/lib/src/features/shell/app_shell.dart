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
    final pages = [
      FeedScreen(onOpenDm: _openDm, onOpenCast: _openCast),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: pages),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Center(
                child: _GlassNav(
                  index: _index,
                  onFeed: () => setState(() => _index = 0),
                  onProfile: () => setState(() => _index = 1),
                  onCast: _openCast,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassNav extends StatelessWidget {
  const _GlassNav({
    required this.index,
    required this.onFeed,
    required this.onProfile,
    required this.onCast,
  });

  final int index;
  final VoidCallback onFeed;
  final VoidCallback onProfile;
  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 306,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF181817).withValues(alpha: .86)
                    : Colors.white.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF32302E)
                      : const Color(0xFFE4E0D8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? .42 : .13),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavIcon(
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore,
                      selected: index == 0,
                      onTap: onFeed,
                    ),
                  ),
                  const SizedBox(width: 86),
                  Expanded(
                    child: _NavIcon(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      selected: index == 1,
                      onTap: onProfile,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 0, child: _CenterCastButton(onTap: onCast)),
        ],
      ),
    );
  }
}

class _CenterCastButton extends StatelessWidget {
  const _CenterCastButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFFE5E1D8) : const Color(0xFF171615),
            shape: BoxShape.circle,
            border: Border.all(
              color: dark ? const Color(0xFF101010) : Colors.white,
              width: 7,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .48 : .20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.mic_external_on,
            color: dark ? const Color(0xFF111111) : const Color(0xFFF2EFE8),
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFE3DFD7) : const Color(0xFF171615);
    final muted = dark ? const Color(0xFFA9A49C) : const Color(0xFF77716B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? foreground.withValues(alpha: dark ? .10 : .08)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? activeIcon : icon,
              color: selected ? foreground : muted,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}
