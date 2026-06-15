import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/api/api_client.dart';
import '../../core/models/svibe_models.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(ref.watch(apiClientProvider));
  controller.restoreSession();
  return controller;
});

final userStatusProvider = FutureProvider.autoDispose<UserStatus?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final token = auth.token;
  if (token == null) {
    return null;
  }
  return ref.watch(apiClientProvider).status(token);
});

class AuthController extends ChangeNotifier {
  AuthController(this._api);

  final SvibeApiClient _api;

  bool isBooting = true;
  bool isLoading = false;
  String? error;
  String? token;
  UserProfile? user;

  bool get isAuthenticated => token != null && user != null;

  Future<void> restoreSession() async {
    isBooting = true;
    notifyListeners();
    final storedToken = await _api.readToken();
    if (storedToken == null) {
      isBooting = false;
      notifyListeners();
      return;
    }
    try {
      user = await _api.me(storedToken);
      token = storedToken;
      error = null;
    } on Object {
      await _api.clearToken();
      token = null;
      user = null;
    } finally {
      isBooting = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) {
    return _withLoading(() async {
      final session = await _api.login(username: username, password: password);
      token = session.accessToken;
      user = session.user;
    });
  }

  Future<bool> register({
    required String username,
    required String password,
    String? displayName,
  }) {
    return _withLoading(() async {
      final session = await _api.register(
        username: username,
        password: password,
        displayName: displayName,
      );
      token = session.accessToken;
      user = session.user;
    });
  }

  Future<void> logout() async {
    await _api.clearToken();
    token = null;
    user = null;
    error = null;
    notifyListeners();
  }

  void replaceUser(UserProfile profile) {
    user = profile;
    notifyListeners();
  }

  Future<bool> _withLoading(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on SvibeApiException catch (exception) {
      error = exception.message;
      return false;
    } on Object catch (exception) {
      error = kDebugMode
          ? 'Something went wrong: $exception'
          : 'Something went wrong. Try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
