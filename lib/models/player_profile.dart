/// 玩家頭像類型
enum AvatarType {
  emoji,         // 使用 emoji 字符
  accountAvatar, // 使用帳號頭像
  customPhoto,   // 使用自訂照片
}

/// 玩家檔案模型（帳號下的持久玩家資料）
class PlayerProfile {
  final String id;              // 持久 UUID
  final String accountId;       // 所屬帳號
  final String name;            // 玩家名稱
  final String emoji;           // 頭像 emoji
  final AvatarType avatarType;  // 頭像類型
  final String? customPhotoUrl; // 自訂照片 URL（Firebase Storage）
  final String? linkedAccountId; // 連結到的另一個帳號
  final bool isSelf;            // 是否為帳號擁有者本人
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final List<String> mergedProfileIds; // 已合併的玩家 profile ID 列表

  PlayerProfile({
    required this.id,
    required this.accountId,
    required this.name,
    required this.emoji,
    this.avatarType = AvatarType.emoji,
    this.customPhotoUrl,
    this.linkedAccountId,
    this.isSelf = false,
    required this.createdAt,
    required this.lastPlayedAt,
    this.mergedProfileIds = const [],
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      avatarType: _parseAvatarType(json['avatarType'] as String?),
      customPhotoUrl: json['customPhotoUrl'] as String?,
      linkedAccountId: json['linkedAccountId'] as String?,
      isSelf: json['isSelf'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      mergedProfileIds: (json['mergedProfileIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  static AvatarType _parseAvatarType(String? value) {
    switch (value) {
      case 'accountAvatar':
        return AvatarType.accountAvatar;
      case 'customPhoto':
        return AvatarType.customPhoto;
      default:
        return AvatarType.emoji;
    }
  }

  static String _avatarTypeToString(AvatarType type) {
    switch (type) {
      case AvatarType.emoji:
        return 'emoji';
      case AvatarType.accountAvatar:
        return 'accountAvatar';
      case AvatarType.customPhoto:
        return 'customPhoto';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'name': name,
      'emoji': emoji,
      'avatarType': _avatarTypeToString(avatarType),
      'customPhotoUrl': customPhotoUrl,
      'linkedAccountId': linkedAccountId,
      'isSelf': isSelf,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'mergedProfileIds': mergedProfileIds,
    };
  }

  PlayerProfile copyWith({
    String? id,
    String? accountId,
    String? name,
    String? emoji,
    AvatarType? avatarType,
    String? customPhotoUrl,
    bool clearCustomPhotoUrl = false,
    String? linkedAccountId,
    bool? isSelf,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    List<String>? mergedProfileIds,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      avatarType: avatarType ?? this.avatarType,
      customPhotoUrl: clearCustomPhotoUrl ? null : (customPhotoUrl ?? this.customPhotoUrl),
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isSelf: isSelf ?? this.isSelf,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      mergedProfileIds: mergedProfileIds ?? this.mergedProfileIds,
    );
  }
}
