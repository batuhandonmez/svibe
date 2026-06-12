import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/svibe_models.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

String defaultApiBaseUrl() {
  if (_apiBaseUrl.isNotEmpty) {
    return _apiBaseUrl;
  }
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final apiClientProvider = Provider<SvibeApiClient>((ref) {
  return SvibeApiClient(
    Dio(
      BaseOptions(
        baseUrl: defaultApiBaseUrl(),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    ),
    ref.watch(secureStorageProvider),
  );
});

class SvibeApiClient {
  SvibeApiClient(this._dio, this._storage);

  static const tokenKey = 'svibe_access_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<String?> readToken() {
    return _storage.read(key: tokenKey);
  }

  Future<void> saveToken(String token) {
    return _storage.write(key: tokenKey, value: token);
  }

  Future<void> clearToken() {
    return _storage.delete(key: tokenKey);
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    final response = await _post(
      '/auth/register',
      data: {'username': username, 'password': password},
    );
    final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
    await saveToken(session.accessToken);
    return session;
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
    await saveToken(session.accessToken);
    return session;
  }

  Future<UserProfile> me(String token) async {
    final response = await _get('/auth/me', token: token);
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserStatus> status(String token) async {
    final response = await _get('/users/me/status', token: token);
    return UserStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<VibeFeedItem>> feed(String token) async {
    final response = await _get('/vibes', token: token);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => VibeFeedItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VibeFeedItem>> myVibes(String token) async {
    final response = await _get('/vibes/mine', token: token);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => VibeFeedItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<VibeFeedItem?> discoverNext(String token) async {
    final response = await _get('/vibes/discover/next', token: token);
    final data = response.data as Map<String, dynamic>;
    final item = data['item'];
    if (item is! Map<String, dynamic>) {
      return null;
    }
    return VibeFeedItem.fromJson(item);
  }

  Future<void> startListening(String token, String vibeId) async {
    await _post('/vibes/$vibeId/listen/start', token: token);
  }

  Future<SwipeResult> swipeVibe(
    String token,
    String vibeId, {
    required String direction,
    bool goldenUnlockConfirmed = false,
  }) async {
    final response = await _post(
      '/vibes/$vibeId/swipe',
      token: token,
      data: {
        'direction': direction,
        'golden_unlock_confirmed': goldenUnlockConfirmed,
      },
    );
    return SwipeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> updateMe(
    String token, {
    String? displayName,
    String? bio,
    bool? isPrivate,
    String? messagePrivacy,
  }) async {
    final response = await _patch(
      '/users/me',
      token: token,
      data: {
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (isPrivate != null) 'is_private': isPrivate,
        if (messagePrivacy != null) 'message_privacy': messagePrivacy,
      },
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> uploadProfilePhoto(
    String token, {
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _post(
      '/users/me/photo',
      token: token,
      data: FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    final data = response.data as Map<String, dynamic>;
    return data['profile_picture_url'] as String;
  }

  Future<void> uploadVibe(
    String token, {
    required List<int> bytes,
    required String filename,
    required int duration,
  }) async {
    await _post(
      '/vibes',
      token: token,
      data: FormData.fromMap({
        'duration': duration,
        'audio': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
  }

  Future<List<DmThread>> dmThreads(String token) async {
    final response = await _get('/dm/threads', token: token);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => DmThread.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DmMessage>> dmMessages(String token, String threadId) async {
    final response = await _get('/dm/threads/$threadId/messages', token: token);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => DmMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DmMessage> sendDmMessage(
    String token,
    String threadId, {
    required String text,
  }) async {
    final response = await _post(
      '/dm/threads/$threadId/messages',
      token: token,
      data: {'text': text},
    );
    return DmMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DmMessage> sendDmAudio(
    String token,
    String threadId, {
    required List<int> bytes,
    required String filename,
    required int duration,
  }) async {
    final response = await _post(
      '/dm/threads/$threadId/messages/audio',
      token: token,
      data: FormData.fromMap({
        'duration': duration,
        'audio': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return DmMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Response<dynamic>> _get(String path, {String? token}) {
    return _guarded(
      () => _dio.get<dynamic>(path, options: Options(headers: _headers(token))),
    );
  }

  Future<Response<dynamic>> _post(String path, {Object? data, String? token}) {
    return _guarded(
      () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(headers: _headers(token)),
      ),
    );
  }

  Future<Response<dynamic>> _patch(String path, {Object? data, String? token}) {
    return _guarded(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        options: Options(headers: _headers(token)),
      ),
    );
  }

  Map<String, String> _headers(String? token) {
    if (token == null || token.isEmpty) {
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Response<dynamic>> _guarded(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final message = _responseErrorMessage(error.response?.data);
      if (message != null) {
        throw SvibeApiException(message);
      }
      if (error.type == DioExceptionType.connectionError) {
        throw SvibeApiException(
          'Cannot reach Svibe API at ${defaultApiBaseUrl()}. '
          'Start the backend and, on a real phone, run with '
          'API_BASE_URL set to your computer LAN IP.',
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw SvibeApiException(
          'Svibe API timed out at ${defaultApiBaseUrl()}. '
          'Check that the phone and computer are on the same network.',
        );
      }
      throw SvibeApiException('Svibe API request failed.');
    }
  }

  String? _responseErrorMessage(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final detail = data['detail'];
    if (detail is String) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final messages = detail
          .whereType<Map<String, dynamic>>()
          .map((item) => item['msg'])
          .whereType<String>()
          .toList();
      if (messages.isNotEmpty) {
        return messages.join(' ');
      }
    }
    return null;
  }
}

class SvibeApiException implements Exception {
  const SvibeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
