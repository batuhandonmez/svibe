import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/app_shell.dart';

class SvibeApp extends ConsumerWidget {
  const SvibeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider).mode;
    return MaterialApp(
      title: 'Svibe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode == ThemeMode.light
          ? ThemeMode.light
          : ThemeMode.dark,
      builder: (context, child) => _MobileViewport(child: child),
      home: const AuthGate(),
    );
  }
}

class _MobileViewport extends StatelessWidget {
  const _MobileViewport({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < 520) {
      return child ?? const SizedBox.shrink();
    }

    return ColoredBox(
      color: const Color(0xFF202020),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(
                size: Size(430, media.size.height),
                padding: media.padding.copyWith(left: 0, right: 0),
                viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.isBooting) {
      return const Scaffold(
        key: ValueKey('booting'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAuthenticated) {
      return const AppShell(key: ValueKey('app-shell'));
    }

    return const AuthScreen(key: ValueKey('auth-screen'));
  }
}
