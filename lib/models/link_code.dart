/// 連結碼模型
class LinkCode {
  final String code;            // 6 位數連結碼
  final String playerProfileId; // 要連結的玩家
  final String fromAccountId;   // 發起方帳號
  final DateTime createdAt;
  final DateTime expiresAt;     // 過期時間（createdAt + 10 分鐘）

  LinkCode({
    required this.code,
    required this.playerProfileId,
    required this.fromAccountId,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory LinkCode.fromJson(Map<String, dynamic> json) {
    return LinkCode(
      code: json['code'] as String,
      playerProfileId: json['playerProfileId'] as String,
      fromAccountId: json['fromAccountId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'playerProfileId': playerProfileId,
      'fromAccountId': fromAccountId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
