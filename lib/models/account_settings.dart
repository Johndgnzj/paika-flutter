/// 帳號設定（與遊戲設定分離）
class AccountSettings {
  final String? selfProfileId; // 設定為「我的 Profile」的 ID
  final bool soundEnabled;     // 音效開關
  final double soundVolume;    // 音量 0.0~1.0

  const AccountSettings({
    this.selfProfileId,
    this.soundEnabled = true,
    this.soundVolume = 0.7,
  });

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    return AccountSettings(
      selfProfileId: json['selfProfileId'] as String?,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      soundVolume: (json['soundVolume'] as num?)?.toDouble() ?? 0.7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selfProfileId': selfProfileId,
      'soundEnabled': soundEnabled,
      'soundVolume': soundVolume,
    };
  }

  AccountSettings copyWith({
    String? selfProfileId,
    bool clearSelfProfileId = false,
    bool? soundEnabled,
    double? soundVolume,
  }) {
    return AccountSettings(
      selfProfileId: clearSelfProfileId ? null : (selfProfileId ?? this.selfProfileId),
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
    );
  }
}
