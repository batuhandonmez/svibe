import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  String? _localError;

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.extension<SvibeColors>()!;
    final isDark = theme.brightness == Brightness.dark;
    final contentWidth = (MediaQuery.sizeOf(context).width - 48)
        .clamp(0.0, 382.0)
        .toDouble();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: colors.elevated.withValues(alpha: .18),
              blurRadius: 160,
              spreadRadius: 18,
              offset: const Offset(0, -120),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _BrandLockup(colors: colors)),
                    const SizedBox(height: 44),
                    Text(
                      _isRegister ? 'Find your signal' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isRegister
                          ? 'Pick a name and start listening.'
                          : 'Listen first. Speak when your signal opens.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.elevated.withValues(alpha: .74),
                        border: Border.all(
                          color: colors.border.withValues(alpha: .8),
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _AuthModeButton(
                              label: 'Log in',
                              selected: !_isRegister,
                              onTap: auth.isLoading
                                  ? null
                                  : () => setState(() {
                                      _isRegister = false;
                                      _localError = null;
                                    }),
                            ),
                          ),
                          Expanded(
                            child: _AuthModeButton(
                              label: 'Create',
                              selected: _isRegister,
                              onTap: auth.isLoading
                                  ? null
                                  : () => setState(() {
                                      _isRegister = true;
                                      _localError = null;
                                    }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: colors.elevated.withValues(alpha: .88),
                        border: Border.all(
                          color: colors.border.withValues(alpha: .8),
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.22 : 0.07,
                            ),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_isRegister) ...[
                            TextField(
                              controller: _displayName,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Display name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          if (_localError != null || auth.error != null) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _localError ?? auth.error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: auth.isLoading ? null : _submit,
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isRegister ? 'Create account' : 'Log in',
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DemoHint(
                      colors: colors,
                      enabled: !auth.isLoading,
                      onTap: _loginDemo,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'API: ${defaultApiBaseUrl()}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: .66,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider);
    final username = _username.text.trim();
    final password = _password.text;
    final displayName = _displayName.text.trim();
    final validationError = _validate(username, password, displayName);
    if (validationError != null) {
      setState(() => _localError = validationError);
      return;
    }
    setState(() => _localError = null);
    if (_isRegister) {
      await auth.register(
        username: username,
        password: password,
        displayName: displayName,
      );
    } else {
      await auth.login(username, password);
    }
  }

  String? _validate(String username, String password, String displayName) {
    if (username.length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (_isRegister && displayName.isEmpty) {
      return 'Display name is required.';
    }
    return null;
  }

  Future<void> _loginDemo() async {
    if (ref.read(authControllerProvider).isLoading) {
      return;
    }
    setState(() {
      _isRegister = false;
      _localError = null;
      _displayName.clear();
      _username.text = 'demo_user';
      _password.text = 'demo12345';
    });
    await ref.read(authControllerProvider).login('demo_user', 'demo12345');
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.colors});

  final SvibeColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: colors.elevated,
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.graphic_eq,
            color: theme.colorScheme.onSurface,
            size: 29,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'svibe',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
      ],
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.onSurface.withValues(alpha: .92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? theme.colorScheme.surface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint({
    required this.colors,
    required this.enabled,
    required this.onTap,
  });

  final SvibeColors colors;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : .55,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.elevated,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.key_outlined, color: colors.berry),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Demo: demo_user / demo12345',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
