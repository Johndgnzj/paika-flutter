/// 玩家模型
class Player {
  final String id;
  final String name;
  final String emoji;
  final String? avatarPath;

  Player({
    required this.id,
    required this.name,
    required this.emoji,
    this.avatarPath,
  });

  /// 從 JSON 反序列化
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      avatarPath: json['avatarPath'] as String?,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'avatarPath': avatarPath,
    };
  }

  /// 複製並修改
  Player copyWith({
    String? id,
    String? name,
    String? emoji,
    String? avatarPath,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}
