/// 玩家模型
class Player {
  final String id;
  final String? userId;     // 關聯到使用者帳號（未來線上版）
  final String name;
  final String emoji;
  final String? avatarUrl;  // 頭像 URL

  Player({
    required this.id,
    this.userId,
    required this.name,
    required this.emoji,
    this.avatarUrl,
  });

  /// 從 JSON 反序列化
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatarPath'] as String?,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'emoji': emoji,
      'avatarUrl': avatarUrl,
    };
  }

  /// 複製並修改
  Player copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    String? avatarUrl,
  }) {
    return Player(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
