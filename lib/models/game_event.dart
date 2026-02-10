/// 遊戲事件類型
enum GameEventType {
  setDealer,      // 指定莊家
  swapPlayers,    // 換位置
}

/// 遊戲事件（記錄 setDealer / swapPlayers 等操作，用於 undo 還原）
class GameEvent {
  final String id;
  final DateTime timestamp;
  final GameEventType type;
  final Map<String, dynamic> data;  // 彈性存放操作細節
  final int afterRoundIndex;        // 在第幾局之後發生的（-1 = 開局前）

  GameEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.data,
    required this.afterRoundIndex,
  });

  /// 從 JSON 反序列化
  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: GameEventType.values[json['type'] as int],
      data: Map<String, dynamic>.from(json['data'] as Map),
      afterRoundIndex: json['afterRoundIndex'] as int,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
      'data': data,
      'afterRoundIndex': afterRoundIndex,
    };
  }
}
