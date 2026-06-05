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
    String? profilePictureUrl,
  }) async {
    final response = await _post(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        'profile_picture_url': profilePictureUrl,
      },
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

  Future<Response<dynamic>> _get(String path, {String? token}) {
    return _guarded(
      () => _dio.get<dynamic>(
        path,
        options: Options(headers: _headers(token)),
      ),
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
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] is String) {
        throw SvibeApiException(data['detail'] as String);
      }
      if (error.type == DioExceptionType.connectionError) {
        throw SvibeApiException(
          'Cannot reach Svibe API at ${defaultApiBaseUrl()}.',
        );
      }
      throw SvibeApiException('Svibe API request failed.');
    }
  }
}

class SvibeApiException implements Exception {
  const SvibeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
