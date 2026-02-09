/// 遊戲設定
class GameSettings {
  final int baseScore;      // 底分
  final int maxTai;         // 上限台數
  final bool selfDrawAddTai; // 自摸是否加1台
  final bool falseWinPayAll; // 詐胡是否賠三家（false=賠一家）
  final int falseWinTai;    // 詐胡賠付台數
  final bool supportMultiWin; // 是否支援一炮多響

  const GameSettings({
    this.baseScore = 50,
    this.maxTai = 20,
    this.selfDrawAddTai = true,
    this.falseWinPayAll = true,
    this.falseWinTai = 8,
    this.supportMultiWin = true,
  });

  /// 預設底台組合
  static const List<Map<String, int>> defaultCombinations = [
    {'base': 50, 'max': 20},
    {'base': 100, 'max': 20},
    {'base': 100, 'max': 50},
    {'base': 300, 'max': 50},
    {'base': 500, 'max': 100},
  ];

  /// 從 JSON 反序列化
  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      baseScore: json['baseScore'] as int? ?? 50,
      maxTai: json['maxTai'] as int? ?? 20,
      selfDrawAddTai: json['selfDrawAddTai'] as bool? ?? true,
      falseWinPayAll: json['falseWinPayAll'] as bool? ?? true,
      falseWinTai: json['falseWinTai'] as int? ?? 8,
      supportMultiWin: json['supportMultiWin'] as bool? ?? true,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'baseScore': baseScore,
      'maxTai': maxTai,
      'selfDrawAddTai': selfDrawAddTai,
      'falseWinPayAll': falseWinPayAll,
      'falseWinTai': falseWinTai,
      'supportMultiWin': supportMultiWin,
    };
  }

  /// 複製並修改
  GameSettings copyWith({
    int? baseScore,
    int? maxTai,
    bool? selfDrawAddTai,
    bool? falseWinPayAll,
    int? falseWinTai,
    bool? supportMultiWin,
  }) {
    return GameSettings(
      baseScore: baseScore ?? this.baseScore,
      maxTai: maxTai ?? this.maxTai,
      selfDrawAddTai: selfDrawAddTai ?? this.selfDrawAddTai,
      falseWinPayAll: falseWinPayAll ?? this.falseWinPayAll,
      falseWinTai: falseWinTai ?? this.falseWinTai,
      supportMultiWin: supportMultiWin ?? this.supportMultiWin,
    );
  }

  /// 計算分數
  /// [tai] 台數
  /// [isSelfDraw] 是否自摸
  /// 回傳單一玩家應付或應得的分數
  int calculateScore(int tai, {bool isSelfDraw = false}) {
    int effectiveTai = tai;
    
    // 自摸加台
    if (isSelfDraw && selfDrawAddTai) {
      effectiveTai += 1;
    }
    
    // 上限台數
    if (effectiveTai > maxTai) {
      effectiveTai = maxTai;
    }
    
    // 計算：底分 × 2^台數
    return baseScore * (1 << effectiveTai); // 位移運算等同 2^n
  }
}
