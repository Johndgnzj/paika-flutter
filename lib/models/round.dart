/// 單局類型
enum RoundType {
  win,        // 胡牌（放槍）
  selfDraw,   // 自摸
  falseWin,   // 詐胡
  multiWin,   // 一炮多響
  draw,       // 流局
}

/// 風位
enum Wind {
  east,   // 東
  south,  // 南
  west,   // 西
  north,  // 北
}

/// 單局結果
class Round {
  final String id;
  final String bigRoundId;  // 關聯到 BigRound
  final DateTime timestamp;
  final RoundType type;     // 類型
  
  // 勝負資訊（純事實，用 playerId）
  final String? winnerId;   // 胡牌者 ID
  final List<String> winnerIds; // 一炮多響時多個胡牌者
  final String? loserId;    // 放槍者 ID（詐胡時也是輸家）
  
  // 計分資訊
  final int tai;            // 台數
  final int flowers;        // 花牌台數
  final Map<String, int> scoreChanges; // 各玩家分數變化 {playerId: change}
  
  // 該局的狀態快照（用於歷史查詢）
  final Wind wind;          // 該局的風圈
  final int dealerPos;      // 該局的莊家位置（0-3，對應 BigRound.seatOrder）
  final int consecutiveWins; // 該局的連莊數
  
  final String? notes;      // 備註

  Round({
    required this.id,
    required this.bigRoundId,
    required this.timestamp,
    required this.type,
    this.winnerId,
    this.winnerIds = const [],
    this.loserId,
    required this.tai,
    this.flowers = 0,
    required this.scoreChanges,
    required this.wind,
    required this.dealerPos,
    this.consecutiveWins = 0,
    this.notes,
  });

  /// 計算實際台數（包含花牌）
  int get totalTai => tai + flowers;

  /// 從 JSON 反序列化
  factory Round.fromJson(Map<String, dynamic> json) {
    return Round(
      id: json['id'] as String,
      bigRoundId: json['bigRoundId'] as String? ?? '', // 向後相容
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: RoundType.values[json['type'] as int],
      winnerId: json['winnerId'] as String?,
      winnerIds: (json['winnerIds'] as List<dynamic>?)?.cast<String>() ?? [],
      loserId: json['loserId'] as String?,
      tai: json['tai'] as int,
      flowers: json['flowers'] as int? ?? 0,
      scoreChanges: Map<String, int>.from(json['scoreChanges'] as Map),
      wind: Wind.values[json['wind'] as int? ?? 0],
      dealerPos: json['dealerPos'] as int? ?? 0,
      consecutiveWins: json['consecutiveWins'] as int? ?? 0,
      notes: json['notes'] as String?,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bigRoundId': bigRoundId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
      'winnerId': winnerId,
      'winnerIds': winnerIds,
      'loserId': loserId,
      'tai': tai,
      'flowers': flowers,
      'scoreChanges': scoreChanges,
      'wind': wind.index,
      'dealerPos': dealerPos,
      'consecutiveWins': consecutiveWins,
      'notes': notes,
    };
  }

  /// 獲取風位顯示文字（圈+風制）
  String get windDisplay {
    const windNames = ['東', '南', '西', '北'];
    final roundWind = windNames[wind.index]; // 圈
    final dealerWind = windNames[dealerPos.clamp(0, 3)]; // 局
    return '$roundWind風$dealerWind局';
  }
}
