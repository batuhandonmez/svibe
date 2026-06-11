import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;

  @override
  void dispose() {
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BrandLockup(colors: colors),
                  const SizedBox(height: 34),
                  Text(
                    _isRegister ? 'Find your signal' : 'Welcome back',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 0.98,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRegister
                        ? 'Pick a name and start listening.'
                        : 'Listen first. Speak when your signal opens.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.elevated,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AuthModeButton(
                            label: 'Log in',
                            selected: !_isRegister,
                            onTap: auth.isLoading
                                ? null
                                : () => setState(() => _isRegister = false),
                          ),
                        ),
                        Expanded(
                          child: _AuthModeButton(
                            label: 'Create',
                            selected: _isRegister,
                            onTap: auth.isLoading
                                ? null
                                : () => setState(() => _isRegister = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: colors.elevated,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
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
                        if (auth.error != null) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              auth.error!,
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
                              : Text(_isRegister ? 'Create account' : 'Log in'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DemoHint(colors: colors),
                ],
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
    if (_isRegister) {
      await auth.register(username: username, password: password);
    } else {
      await auth.login(username, password);
    }
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.colors});

  final SvibeColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: colors.berry,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.berry.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Text(
          'Svibe',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
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
          color: selected ? theme.colorScheme.onSurface : Colors.transparent,
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
  const _DemoHint({required this.colors});

  final SvibeColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
        ],
      ),
    );
  }
}
