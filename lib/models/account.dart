/// 帳號模型
class Account {
  final String id;              // UUID，永久不變
  final String name;            // 帳號顯示名稱
  final String? email;          // 可選
  final String passwordHash;    // SHA-256 雜湊
  final String salt;            // 隨機鹽值
  final DateTime createdAt;
  final DateTime lastLoginAt;

  Account({
    required this.id,
    required this.name,
    this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'salt': salt,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    String? email,
    String? passwordHash,
    String? salt,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
