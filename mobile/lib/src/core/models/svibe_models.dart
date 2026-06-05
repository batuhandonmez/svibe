class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.isMuted,
    required this.dailyVibeCount,
    required this.isVip,
    required this.createdAt,
    this.profilePictureUrl,
    this.dailyVibeResetAt,
  });

  final String id;
  final String username;
  final String? profilePictureUrl;
  final bool isMuted;
  final int dailyVibeCount;
  final DateTime? dailyVibeResetAt;
  final bool isVip;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      isMuted: json['is_muted'] as bool? ?? true,
      dailyVibeCount: json['daily_vibe_count'] as int? ?? 0,
      dailyVibeResetAt: _date(json['daily_vibe_reset_at']),
      isVip: json['is_vip'] as bool? ?? false,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }
}

class UserStatus {
  const UserStatus({
    required this.isMuted,
    required this.dailyVibeCount,
    required this.dailyVibeLimit,
    required this.canUploadVibe,
    this.dailyVibeResetAt,
  });

  final bool isMuted;
  final int dailyVibeCount;
  final int dailyVibeLimit;
  final DateTime? dailyVibeResetAt;
  final bool canUploadVibe;

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    return UserStatus(
      isMuted: json['is_muted'] as bool? ?? true,
      dailyVibeCount: json['daily_vibe_count'] as int? ?? 0,
      dailyVibeLimit: json['daily_vibe_limit'] as int? ?? 0,
      dailyVibeResetAt: _date(json['daily_vibe_reset_at']),
      canUploadVibe: json['can_upload_vibe'] as bool? ?? false,
    );
  }
}

class VibeFeedItem {
  const VibeFeedItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.audioUrl,
    required this.duration,
    required this.swipeRightCount,
    required this.isGoldenVoice,
    required this.createdAt,
    required this.expiresAt,
    required this.canSwipeNow,
    this.profilePictureUrl,
    this.listenStartedAt,
    this.canSwipeAt,
  });

  final String id;
  final String userId;
  final String username;
  final String? profilePictureUrl;
  final String audioUrl;
  final int duration;
  final int swipeRightCount;
  final bool isGoldenVoice;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? listenStartedAt;
  final DateTime? canSwipeAt;
  final bool canSwipeNow;

  factory VibeFeedItem.fromJson(Map<String, dynamic> json) {
    return VibeFeedItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'unknown',
      profilePictureUrl: json['profile_picture_url'] as String?,
      audioUrl: json['audio_url'] as String,
      duration: json['duration'] as int? ?? 0,
      swipeRightCount: json['swipe_right_count'] as int? ?? 0,
      isGoldenVoice: json['is_golden_voice'] as bool? ?? false,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      expiresAt: _date(json['expires_at']) ?? DateTime.now(),
      listenStartedAt: _date(json['listen_started_at']),
      canSwipeAt: _date(json['can_swipe_at']),
      canSwipeNow: json['can_swipe_now'] as bool? ?? false,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
