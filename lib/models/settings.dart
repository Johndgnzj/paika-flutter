/// 遊戲設定
class GameSettings {
  final int baseScore;      // 底分
  final int maxTai;         // 每台分數（舊名保留相容性）
  final bool selfDrawAddTai; // 自摸是否加1台
  final bool falseWinPayAll; // 詐胡是否賠三家（false=賠一家）
  final int falseWinTai;    // 詐胡賠付台數
  final bool supportMultiWin; // 是否支援一炮多響
  final bool dealerTai;     // 自動計算莊家台數（莊家+1台）
  final bool consecutiveTai; // 自動計算連莊台數（每連莊+1台）

  const GameSettings({
    this.baseScore = 50,
    this.maxTai = 20,  // 實際上是每台分數
    this.selfDrawAddTai = true,
    this.falseWinPayAll = true,
    this.falseWinTai = 8,
    this.supportMultiWin = true,
    this.dealerTai = false,
    this.consecutiveTai = false,
  });
  
  /// 每台分數（與maxTai相同，為了語意清楚）
  int get perTai => maxTai;

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
      dealerTai: json['dealerTai'] as bool? ?? false,
      consecutiveTai: json['consecutiveTai'] as bool? ?? false,
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
      'dealerTai': dealerTai,
      'consecutiveTai': consecutiveTai,
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
    bool? dealerTai,
    bool? consecutiveTai,
  }) {
    return GameSettings(
      baseScore: baseScore ?? this.baseScore,
      maxTai: maxTai ?? this.maxTai,
      selfDrawAddTai: selfDrawAddTai ?? this.selfDrawAddTai,
      falseWinPayAll: falseWinPayAll ?? this.falseWinPayAll,
      falseWinTai: falseWinTai ?? this.falseWinTai,
      supportMultiWin: supportMultiWin ?? this.supportMultiWin,
      dealerTai: dealerTai ?? this.dealerTai,
      consecutiveTai: consecutiveTai ?? this.consecutiveTai,
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
    
    // 計算：底 + (台數 × 每台分數)
    return baseScore + (effectiveTai * perTai);
  }
}
