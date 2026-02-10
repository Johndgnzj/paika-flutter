/// 大局（將）- 代表一個完整的風圈循環週期
/// 一將 = 東風圈(4局) + 南風圈(4局) + 西風圈(4局) + 北風圈(4局) = 最多16局
/// 但實際可能因連莊而有更多局數
class BigRound {
  final String id;
  final int jiangNumber;          // 第幾將（1, 2, 3...）
  final List<String> seatOrder;   // 座位順序（固定）[playerId0東, playerId1南, playerId2西, playerId3北]
  final int startDealerPos;       // 起始莊家座位（0-3）
  final DateTime startTime;
  final DateTime? endTime;        // null = 進行中

  BigRound({
    required this.id,
    required this.jiangNumber,
    required this.seatOrder,
    required this.startDealerPos,
    required this.startTime,
    this.endTime,
  }) : assert(seatOrder.length == 4, '座位順序必須包含4位玩家');

  /// 是否已結束
  bool get isFinished => endTime != null;

  /// 根據座位取得玩家ID
  String getPlayerIdByPos(int pos) {
    return seatOrder[pos];
  }

  /// 根據玩家ID取得座位
  int getPosByPlayerId(String playerId) {
    return seatOrder.indexOf(playerId);
  }

  /// 從 JSON 反序列化
  factory BigRound.fromJson(Map<String, dynamic> json) {
    return BigRound(
      id: json['id'] as String,
      jiangNumber: json['jiangNumber'] as int,
      seatOrder: (json['seatOrder'] as List).cast<String>(),
      startDealerPos: json['startDealerPos'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jiangNumber': jiangNumber,
      'seatOrder': seatOrder,
      'startDealerPos': startDealerPos,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  /// 複製並更新部分欄位
  BigRound copyWith({
    String? id,
    int? jiangNumber,
    List<String>? seatOrder,
    int? startDealerPos,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return BigRound(
      id: id ?? this.id,
      jiangNumber: jiangNumber ?? this.jiangNumber,
      seatOrder: seatOrder ?? this.seatOrder,
      startDealerPos: startDealerPos ?? this.startDealerPos,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
