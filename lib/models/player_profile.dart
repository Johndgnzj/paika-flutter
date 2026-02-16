/// 玩家檔案模型（帳號下的持久玩家資料）
class PlayerProfile {
  final String id;              // 持久 UUID
  final String accountId;       // 所屬帳號
  final String name;            // 玩家名稱
  final String emoji;           // 頭像 emoji
  final String? linkedAccountId; // 連結到的另一個帳號
  final bool isSelf;            // 是否為帳號擁有者本人
  final DateTime createdAt;
  final DateTime lastPlayedAt;

  PlayerProfile({
    required this.id,
    required this.accountId,
    required this.name,
    required this.emoji,
    this.linkedAccountId,
    this.isSelf = false,
    required this.createdAt,
    required this.lastPlayedAt,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      linkedAccountId: json['linkedAccountId'] as String?,
      isSelf: json['isSelf'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'name': name,
      'emoji': emoji,
      'linkedAccountId': linkedAccountId,
      'isSelf': isSelf,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
    };
  }

  PlayerProfile copyWith({
    String? id,
    String? accountId,
    String? name,
    String? emoji,
    String? linkedAccountId,
    bool? isSelf,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isSelf: isSelf ?? this.isSelf,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }
}
