/// 將（一個完整的風圈循環週期）
/// 理論上一將包含 16 局（東南西北風圈各 4 局），但因為連莊可能會更多
class Jiang {
  final String id;
  final String gameId;             // 屬於哪場遊戲
  final int jiangNumber;           // 第幾將 (1, 2, 3...)
  final List<String> seatOrder;    // 玩家座位順序 [seat0的playerId, seat1, seat2, seat3]
  final int startDealerSeat;       // 起莊座位 (0-3)
  final int startDealerPassCount;  // 該將開始時的 dealerPassCount
  final DateTime startTime;
  final DateTime? endTime;         // null = 進行中

  Jiang({
    required this.id,
    required this.gameId,
    required this.jiangNumber,
    required this.seatOrder,
    required this.startDealerSeat,
    required this.startDealerPassCount,
    required this.startTime,
    this.endTime,
  }) : assert(seatOrder.length == 4, '座位順序必須包含4位玩家');

  /// 是否已結束
  bool get isFinished => endTime != null;

  /// 根據座位取得玩家ID
  String getPlayerIdBySeat(int seat) {
    return seatOrder[seat];
  }

  /// 根據玩家ID取得座位
  int getSeatByPlayerId(String playerId) {
    return seatOrder.indexOf(playerId);
  }

  /// 從 JSON 反序列化
  factory Jiang.fromJson(Map<String, dynamic> json) {
    return Jiang(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      jiangNumber: json['jiangNumber'] as int,
      seatOrder: (json['seatOrder'] as List).cast<String>(),
      startDealerSeat: json['startDealerSeat'] as int,
      startDealerPassCount: json['startDealerPassCount'] as int,
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
      'gameId': gameId,
      'jiangNumber': jiangNumber,
      'seatOrder': seatOrder,
      'startDealerSeat': startDealerSeat,
      'startDealerPassCount': startDealerPassCount,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  /// 複製並更新部分欄位
  Jiang copyWith({
    String? id,
    String? gameId,
    int? jiangNumber,
    List<String>? seatOrder,
    int? startDealerSeat,
    int? startDealerPassCount,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return Jiang(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      jiangNumber: jiangNumber ?? this.jiangNumber,
      seatOrder: seatOrder ?? this.seatOrder,
      startDealerSeat: startDealerSeat ?? this.startDealerSeat,
      startDealerPassCount: startDealerPassCount ?? this.startDealerPassCount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
