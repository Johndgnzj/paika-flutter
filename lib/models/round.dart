/// 單局類型
enum RoundType {
  win,        // 胡牌（放槍）
  selfDraw,   // 自摸
  falseWin,   // 詐胡
  multiWin,   // 一炮多響
  draw,       // 流局
}

/// 風位（保留 enum，用於向後相容）
enum Wind {
  east,   // 東
  south,  // 南
  west,   // 西
  north,  // 北
}

/// 單局結果
class Round {
  final String id;
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

  // ★ 狀態快照（用計數器追蹤遊戲進度）
  final int dealerPassCount;  // 該局時的莊家輪轉計數器
  final int dealerSeat;       // 該局的莊家座位 (0-3)
  final int consecutiveWins;  // 該局的連莊數
  final int jiangNumber;      // 該局的將號（實際值，不是計算）
  final int jiangStartDealerPassCount; // 該將的起始 dealerPassCount

  final String? notes;      // 備註

  Round({
    required this.id,
    required this.timestamp,
    required this.type,
    this.winnerId,
    this.winnerIds = const [],
    this.loserId,
    required this.tai,
    this.flowers = 0,
    required this.scoreChanges,
    required this.dealerPassCount,
    required this.dealerSeat,
    this.consecutiveWins = 0,
    required this.jiangNumber,
    required this.jiangStartDealerPassCount,
    this.notes,
  });

  /// 計算實際台數（包含花牌）
  int get totalTai => tai + flowers;

  /// ★ 衍生計算：風圈 (0=東 1=南 2=西 3=北)
  int get windCircle {
    final relativeCount = dealerPassCount - jiangStartDealerPassCount;
    return (relativeCount ~/ 4) % 4;
  }

  /// ★ 衍生計算：風圈內的第幾局 (0=東局 1=南局 2=西局 3=北局)
  int get juInCircle {
    final relativeCount = dealerPassCount - jiangStartDealerPassCount;
    return relativeCount % 4;
  }

  /// ★ 風位顯示文字（圈+局）
  String get windDisplay {
    const names = ['東', '南', '西', '北'];
    return '${names[windCircle]}風${names[juInCircle]}局';
  }

  /// 從 JSON 反序列化（支援舊格式向後相容）
  factory Round.fromJson(Map<String, dynamic> json) {
    // 向後相容：舊格式有 wind/dealerPos，新格式有 dealerPassCount/dealerSeat
    int dealerPassCount;
    int dealerSeat;
    int jiangNumber;
    int jiangStartDealerPassCount;

    if (json.containsKey('dealerPassCount')) {
      // 新格式
      dealerPassCount = json['dealerPassCount'] as int;
      dealerSeat = json['dealerSeat'] as int;
      // 向後相容：如果沒有 jiangNumber，用公式推算
      jiangNumber = json['jiangNumber'] as int? ?? ((dealerPassCount ~/ 16) + 1);
      // 向後相容：如果沒有 jiangStartDealerPassCount，用公式推算
      jiangStartDealerPassCount = json['jiangStartDealerPassCount'] as int? ?? ((jiangNumber - 1) * 16);
    } else {
      // 舊格式：從 wind + dealerPos 近似推算
      final windIndex = json['wind'] as int? ?? 0;
      final dealerPos = json['dealerPos'] as int? ?? 0;
      dealerPassCount = windIndex * 4 + dealerPos;
      dealerSeat = dealerPos;
      jiangNumber = (dealerPassCount ~/ 16) + 1;
      jiangStartDealerPassCount = (jiangNumber - 1) * 16;
    }

    return Round(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: RoundType.values[json['type'] as int],
      winnerId: json['winnerId'] as String?,
      winnerIds: (json['winnerIds'] as List<dynamic>?)?.cast<String>() ?? [],
      loserId: json['loserId'] as String?,
      tai: json['tai'] as int,
      flowers: json['flowers'] as int? ?? 0,
      scoreChanges: Map<String, int>.from(json['scoreChanges'] as Map),
      dealerPassCount: dealerPassCount,
      dealerSeat: dealerSeat,
      consecutiveWins: json['consecutiveWins'] as int? ?? 0,
      jiangNumber: jiangNumber,
      jiangStartDealerPassCount: jiangStartDealerPassCount,
      notes: json['notes'] as String?,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
      'winnerId': winnerId,
      'winnerIds': winnerIds,
      'loserId': loserId,
      'tai': tai,
      'flowers': flowers,
      'scoreChanges': scoreChanges,
      'dealerPassCount': dealerPassCount,
      'dealerSeat': dealerSeat,
      'consecutiveWins': consecutiveWins,
      'jiangNumber': jiangNumber,
      'jiangStartDealerPassCount': jiangStartDealerPassCount,
      'notes': notes,
    };
  }
}
