/// 帳號設定（與遊戲設定分離）
class AccountSettings {
  final String? selfProfileId; // 設定為「我的 Profile」的 ID

  const AccountSettings({
    this.selfProfileId,
  });

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    return AccountSettings(
      selfProfileId: json['selfProfileId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selfProfileId': selfProfileId,
    };
  }

  AccountSettings copyWith({
    String? selfProfileId,
    bool clearSelfProfileId = false,
  }) {
    return AccountSettings(
      selfProfileId: clearSelfProfileId ? null : (selfProfileId ?? this.selfProfileId),
    );
  }
}
