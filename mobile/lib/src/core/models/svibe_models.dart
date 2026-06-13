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
    required this.isPrivate,
    required this.messagePrivacy,
    this.displayName,
    this.bio,
    this.profilePictureUrl,
    this.dailyVibeResetAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? profilePictureUrl;
  final bool isPrivate;
  final String messagePrivacy;
  final bool isMuted;
  final int dailyVibeCount;
  final DateTime? dailyVibeResetAt;
  final bool isVip;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      messagePrivacy: json['message_privacy'] as String? ?? 'everyone',
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
    required this.isPrivate,
    required this.messagePrivacy,
    required this.followersCount,
    required this.followingCount,
    required this.vibesCount,
    this.dailyVibeResetAt,
  });

  final bool isMuted;
  final int dailyVibeCount;
  final int dailyVibeLimit;
  final DateTime? dailyVibeResetAt;
  final bool canUploadVibe;
  final bool isPrivate;
  final String messagePrivacy;
  final int followersCount;
  final int followingCount;
  final int vibesCount;

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    return UserStatus(
      isMuted: json['is_muted'] as bool? ?? true,
      dailyVibeCount: json['daily_vibe_count'] as int? ?? 0,
      dailyVibeLimit: json['daily_vibe_limit'] as int? ?? 0,
      dailyVibeResetAt: _date(json['daily_vibe_reset_at']),
      canUploadVibe: json['can_upload_vibe'] as bool? ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      messagePrivacy: json['message_privacy'] as String? ?? 'everyone',
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      vibesCount: json['vibes_count'] as int? ?? 0,
    );
  }
}

class VibeFeedItem {
  const VibeFeedItem({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
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
  final String? displayName;
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
      displayName: json['display_name'] as String?,
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

class SwipeResult {
  const SwipeResult({
    required this.vibeId,
    required this.direction,
    required this.swipeRightCount,
    required this.goldenVoiceUnlocked,
    required this.goldenVoiceUnlockPending,
    this.message,
  });

  final String vibeId;
  final String direction;
  final int swipeRightCount;
  final bool goldenVoiceUnlocked;
  final bool goldenVoiceUnlockPending;
  final String? message;

  factory SwipeResult.fromJson(Map<String, dynamic> json) {
    return SwipeResult(
      vibeId: json['vibe_id'] as String,
      direction: json['direction'] as String? ?? 'like',
      swipeRightCount: json['swipe_right_count'] as int? ?? 0,
      goldenVoiceUnlocked: json['golden_voice_unlocked'] as bool? ?? false,
      goldenVoiceUnlockPending:
          json['golden_voice_unlock_pending'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}

class ListenStartResult {
  const ListenStartResult({
    required this.vibeId,
    required this.startedAt,
    required this.canSwipeAfterSeconds,
  });

  final String vibeId;
  final DateTime startedAt;
  final int canSwipeAfterSeconds;

  factory ListenStartResult.fromJson(Map<String, dynamic> json) {
    return ListenStartResult(
      vibeId: json['vibe_id'] as String,
      startedAt: _date(json['started_at']) ?? DateTime.now(),
      canSwipeAfterSeconds: json['can_swipe_after_seconds'] as int? ?? 3,
    );
  }
}

class DmPeer {
  const DmPeer({
    required this.id,
    required this.username,
    required this.messagePrivacy,
    this.displayName,
    this.profilePictureUrl,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? profilePictureUrl;
  final String messagePrivacy;

  factory DmPeer.fromJson(Map<String, dynamic> json) {
    return DmPeer(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      messagePrivacy: json['message_privacy'] as String? ?? 'everyone',
    );
  }
}

class DmMessage {
  const DmMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.createdAt,
    this.text,
    this.audioUrl,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String? text;
  final String? audioUrl;
  final DateTime createdAt;

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      text: json['text'] as String?,
      audioUrl: json['audio_url'] as String?,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }
}

class DmThread {
  const DmThread({
    required this.id,
    required this.peer,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  final String id;
  final DmPeer peer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DmMessage? lastMessage;

  factory DmThread.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'];
    return DmThread(
      id: json['id'] as String,
      peer: DmPeer.fromJson(json['peer'] as Map<String, dynamic>),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      lastMessage: last is Map<String, dynamic>
          ? DmMessage.fromJson(last)
          : null,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
