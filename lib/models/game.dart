import 'player.dart';
import 'round.dart';
import 'settings.dart';
import 'game_event.dart';
import 'jiang.dart';

/// 遊戲狀態
enum GameStatus {
  setup,      // 設定中
  playing,    // 進行中
  finished,   // 已結束
}

/// 牌局
class Game {
  final String id;
  final String? accountId;      // 所屬帳號 ID
  final String? name;           // 牌局名稱（可選）
  final DateTime createdAt;
  final GameSettings settings;
  final List<Player> players; // 4位玩家（index = 固定座位）
  final List<Round> rounds;
  final GameStatus status;

  // ★ 遊戲進度狀態（用計數器追蹤）
  final int dealerSeat;         // 當前莊家座位 (0-3)
  final int dealerPassCount;    // 莊家輪轉計數器（核心！）
  final int consecutiveWins;    // 連莊數
  final int initialDealerSeat;  // 初始莊家座位（用於 undo 重播）

  // ★ 事件日誌（記錄 setDealer / swapPlayers 等操作）
  final List<GameEvent> events;

  // ★ 將記錄（每一將的資訊）
  final List<Jiang> jiangs;

  Game({
    required this.id,
    this.accountId,
    this.name,
    required this.createdAt,
    required this.settings,
    required this.players,
    this.rounds = const [],
    this.status = GameStatus.setup,
    this.dealerSeat = 0,
    this.dealerPassCount = 0,
    this.consecutiveWins = 0,
    this.initialDealerSeat = 0,
    this.events = const [],
    this.jiangs = const [],
  });

  // ★ 衍生計算
  /// 當前進行中的將
  Jiang? get currentJiang => jiangs.isNotEmpty ? jiangs.last : null;

  /// 第幾將（從 currentJiang 取得，沒有則推論）
  int get jiangNumber => currentJiang?.jiangNumber ?? ((dealerPassCount ~/ 16) + 1);

  /// 風圈 (0=東 1=南 2=西 3=北)
  int get windCircle {
    // 使用相對於當前將的進度
    final startCount = currentJiang?.startDealerPassCount ?? 0;
    final relativeCount = dealerPassCount - startCount;
    return (relativeCount ~/ 4) % 4;
  }

  /// 風圈內的第幾局 (0=東局 1=南局 2=西局 3=北局)
  int get juInCircle {
    // 使用相對於當前將的進度
    final startCount = currentJiang?.startDealerPassCount ?? 0;
    final relativeCount = dealerPassCount - startCount;
    return relativeCount % 4;
  }

  /// 獲取當前分數
  Map<String, int> get currentScores {
    final scores = <String, int>{};
    for (var player in players) {
      scores[player.id] = 0;
    }
    for (var round in rounds) {
      round.scoreChanges.forEach((playerId, change) {
        scores[playerId] = (scores[playerId] ?? 0) + change;
      });
    }
    return scores;
  }

  /// 獲取莊家
  Player get dealer => players[dealerSeat];

  /// 獲取當前風位顯示（圈+局）
  /// 例如：東風東局、東風南局、南風西局
  String get currentWindDisplay {
    const windNames = ['東', '南', '西', '北'];
    return '${windNames[windCircle]}風${windNames[juInCircle]}局';
  }

  /// 短版風位顯示
  String get currentWindDisplayShort {
    const windNames = ['東', '南', '西', '北'];
    return '${windNames[windCircle]}${windNames[juInCircle]}';
  }

  /// 從 JSON 反序列化（支援舊格式向後相容）
  factory Game.fromJson(Map<String, dynamic> json) {
    // 向後相容：偵測舊格式
    int dealerSeat;
    int dealerPassCount;
    int initialDealerSeat;
    List<GameEvent> events;

    if (json.containsKey('dealerPassCount')) {
      // 新格式
      dealerSeat = json['dealerSeat'] as int;
      dealerPassCount = json['dealerPassCount'] as int;
      initialDealerSeat = json['initialDealerSeat'] as int? ?? 0;
      events = (json['events'] as List?)
          ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
          .toList() ?? [];
    } else {
      // 舊格式轉換
      final oldDealerIndex = json['dealerIndex'] as int? ?? 0;
      final oldWindIndex = json['currentWind'] as int? ?? 0;
      dealerSeat = oldDealerIndex;
      dealerPassCount = oldWindIndex * 4 + oldDealerIndex;
      initialDealerSeat = 0;
      events = [];
    }

    return Game(
      id: json['id'] as String,
      accountId: json['accountId'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settings: GameSettings.fromJson(json['settings'] as Map<String, dynamic>),
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      rounds: (json['rounds'] as List)
          .map((r) => Round.fromJson(r as Map<String, dynamic>))
          .toList(),
      status: GameStatus.values[json['status'] as int],
      dealerSeat: dealerSeat,
      dealerPassCount: dealerPassCount,
      consecutiveWins: json['consecutiveWins'] as int? ?? 0,
      initialDealerSeat: initialDealerSeat,
      events: events,
      jiangs: (json['jiangs'] as List?)
          ?.map((j) => Jiang.fromJson(j as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'rounds': rounds.map((r) => r.toJson()).toList(),
      'status': status.index,
      'dealerSeat': dealerSeat,
      'dealerPassCount': dealerPassCount,
      'consecutiveWins': consecutiveWins,
      'initialDealerSeat': initialDealerSeat,
      'events': events.map((e) => e.toJson()).toList(),
      'jiangs': jiangs.map((j) => j.toJson()).toList(),
    };
  }

  /// 複製並修改
  Game copyWith({
    String? id,
    String? accountId,
    String? name,
    DateTime? createdAt,
    GameSettings? settings,
    List<Player>? players,
    List<Round>? rounds,
    GameStatus? status,
    int? dealerSeat,
    int? dealerPassCount,
    int? consecutiveWins,
    int? initialDealerSeat,
    List<GameEvent>? events,
    List<Jiang>? jiangs,
  }) {
    return Game(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? this.settings,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      status: status ?? this.status,
      dealerSeat: dealerSeat ?? this.dealerSeat,
      dealerPassCount: dealerPassCount ?? this.dealerPassCount,
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
      initialDealerSeat: initialDealerSeat ?? this.initialDealerSeat,
      events: events ?? this.events,
      jiangs: jiangs ?? this.jiangs,
    );
  }

  /// 添加新局並更新狀態
  Game addRound(Round round) {
    final newRounds = [...rounds, round];

    // 判斷是否連莊
    bool shouldContinueDealer = false;
    if (round.winnerId == dealer.id) {
      shouldContinueDealer = true;
    } else if (round.type == RoundType.draw) {
      shouldContinueDealer = true;
    }

    if (shouldContinueDealer) {
      // 連莊：dealerSeat 和 dealerPassCount 不變
      return copyWith(
        rounds: newRounds,
        consecutiveWins: consecutiveWins + 1,
      );
    } else {
      // 換莊：座位 +1，計數器 +1
      final newSeat = (dealerSeat + 1) % 4;
      final newPassCount = dealerPassCount + 1;

      return copyWith(
        rounds: newRounds,
        dealerSeat: newSeat,
        dealerPassCount: newPassCount,
        consecutiveWins: 0,
      );
    }
  }

  /// 還原上一局
  Game undoLastRound() {
    if (rounds.isEmpty) return this;

    final newRounds = rounds.sublist(0, rounds.length - 1);

    // 從頭重播，套用事件日誌
    Game game = copyWith(
      rounds: [],
      dealerSeat: initialDealerSeat,
      dealerPassCount: 0,
      consecutiveWins: 0,
      // 保留 players 為初始狀態？不行，事件會重播 swap
      // 所以需要保留初始 players... 暫時用現有 players
    );

    // 重建初始 players（從事件反推 swap 前的狀態）
    // 簡化方案：先套用事件，再重播 rounds
    int eventIndex = 0;
    for (int i = 0; i < newRounds.length; i++) {
      // 先套用在這個 round 之前發生的事件
      while (eventIndex < events.length &&
             events[eventIndex].afterRoundIndex < i) {
        game = _applyEvent(game, events[eventIndex]);
        eventIndex++;
      }
      game = game.addRound(newRounds[i]);
    }

    return game.copyWith(events: events); // 保留所有事件，由外部決定是否裁剪
  }

  /// 套用事件到遊戲狀態
  static Game _applyEvent(Game game, GameEvent event) {
    switch (event.type) {
      case GameEventType.setDealer:
        final newSeat = event.data['newDealerSeat'] as int;
        final recalculate = event.data['recalculateWind'] as bool? ?? false;
        int passCount = game.dealerPassCount;
        if (recalculate) {
          // 進入下一將的東風東局（不是回到第一將）
          passCount = ((passCount ~/ 16) + 1) * 16;
        }
        return game.copyWith(
          dealerSeat: newSeat,
          dealerPassCount: passCount,
          consecutiveWins: 0,
        );

      case GameEventType.swapPlayers:
        final seat1 = event.data['seat1'] as int;
        final seat2 = event.data['seat2'] as int;
        final players = List<Player>.from(game.players);
        final temp = players[seat1];
        players[seat1] = players[seat2];
        players[seat2] = temp;

        int newDealerSeat = game.dealerSeat;
        if (newDealerSeat == seat1) {
          newDealerSeat = seat2;
        } else if (newDealerSeat == seat2) {
          newDealerSeat = seat1;
        }

        return game.copyWith(
          players: players,
          dealerSeat: newDealerSeat,
        );
    }
  }
}
