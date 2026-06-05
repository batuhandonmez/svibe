import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _photoUrl = TextEditingController();
  bool _isRegister = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.graphic_eq, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Svibe',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    _isRegister ? 'Create your voice' : 'Welcome back',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Listen first. Speak when the room lets you in.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _photoUrl,
                      decoration: const InputDecoration(
                        labelText: 'Profile photo URL',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                  ],
                  if (auth.error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      auth.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegister ? 'Create account' : 'Log in'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Already have an account? Log in'
                          : 'New here? Create account',
                    ),
                  ),
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
      await auth.register(
        username: username,
        password: password,
        profilePictureUrl: _photoUrl.text.trim(),
      );
    } else {
      await auth.login(username, password);
    }
  }
}
