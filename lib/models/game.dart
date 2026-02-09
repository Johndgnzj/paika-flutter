import 'player.dart';
import 'round.dart';
import 'settings.dart';

/// 遊戲狀態
enum GameStatus {
  setup,      // 設定中
  playing,    // 進行中
  finished,   // 已結束
}

/// 牌局
class Game {
  final String id;
  final DateTime createdAt;
  final GameSettings settings;
  final List<Player> players; // 4位玩家，依序為東南西北
  final List<Round> rounds;
  final GameStatus status;
  
  // 當前狀態
  final Wind currentWind;     // 當前風圈
  final int currentSequence;  // 當前局數
  final int dealerIndex;      // 莊家位置（0-3）
  final int consecutiveWins;  // 連莊數
  
  Game({
    required this.id,
    required this.createdAt,
    required this.settings,
    required this.players,
    this.rounds = const [],
    this.status = GameStatus.setup,
    this.currentWind = Wind.east,
    this.currentSequence = 1,
    this.dealerIndex = 0,
    this.consecutiveWins = 0,
  });

  /// 獲取當前分數
  Map<String, int> get currentScores {
    final scores = <String, int>{};
    
    // 初始化所有玩家分數為 0
    for (var player in players) {
      scores[player.id] = 0;
    }
    
    // 累加所有局數的分數變化
    for (var round in rounds) {
      round.scoreChanges.forEach((playerId, change) {
        scores[playerId] = (scores[playerId] ?? 0) + change;
      });
    }
    
    return scores;
  }

  /// 獲取莊家
  Player get dealer => players[dealerIndex];

  /// 獲取當前風位顯示（圈+風制）
  /// 例如：東風東局、東風南局、南風西局
  String get currentWindDisplay {
    const windNames = ['東', '南', '西', '北'];
    final roundWind = windNames[currentWind.index]; // 圈（東風、南風...）
    final dealerWind = windNames[dealerIndex];       // 局（東局、南局...）
    return '$roundWind風$dealerWind局';
  }

  /// 短版風位顯示（用於空間有限的地方）
  String get currentWindDisplayShort {
    const windNames = ['東', '南', '西', '北'];
    return '${windNames[currentWind.index]}${windNames[dealerIndex]}';
  }

  /// 從 JSON 反序列化
  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settings: GameSettings.fromJson(json['settings'] as Map<String, dynamic>),
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      rounds: (json['rounds'] as List)
          .map((r) => Round.fromJson(r as Map<String, dynamic>))
          .toList(),
      status: GameStatus.values[json['status'] as int],
      currentWind: Wind.values[json['currentWind'] as int],
      currentSequence: json['currentSequence'] as int,
      dealerIndex: json['dealerIndex'] as int,
      consecutiveWins: json['consecutiveWins'] as int,
    );
  }

  /// 序列化為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'rounds': rounds.map((r) => r.toJson()).toList(),
      'status': status.index,
      'currentWind': currentWind.index,
      'currentSequence': currentSequence,
      'dealerIndex': dealerIndex,
      'consecutiveWins': consecutiveWins,
    };
  }

  /// 複製並修改
  Game copyWith({
    String? id,
    DateTime? createdAt,
    GameSettings? settings,
    List<Player>? players,
    List<Round>? rounds,
    GameStatus? status,
    Wind? currentWind,
    int? currentSequence,
    int? dealerIndex,
    int? consecutiveWins,
  }) {
    return Game(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? this.settings,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      status: status ?? this.status,
      currentWind: currentWind ?? this.currentWind,
      currentSequence: currentSequence ?? this.currentSequence,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
    );
  }

  /// 添加新局並更新狀態
  Game addRound(Round round) {
    final newRounds = [...rounds, round];
    
    // 判斷是否連莊
    bool shouldContinueDealer = false;
    if (round.winnerId == dealer.id) {
      // 莊家胡牌，連莊
      shouldContinueDealer = true;
    } else if (round.type == RoundType.draw) {
      // 流局，莊家連莊（簡化版規則）
      shouldContinueDealer = true;
    }
    
    int newConsecutiveWins = shouldContinueDealer ? consecutiveWins + 1 : 0;
    int newSequence = currentSequence;
    Wind newWind = currentWind;
    int newDealerIndex = dealerIndex;
    
    if (shouldContinueDealer) {
      // 連莊，局數+1
      newSequence++;
    } else {
      // 不連莊，換莊家
      newDealerIndex = (dealerIndex + 1) % 4;
      newSequence = 1;
      
      // 如果回到東家，進入下一圈
      if (newDealerIndex == 0) {
        if (currentWind.index < Wind.values.length - 1) {
          newWind = Wind.values[currentWind.index + 1];
        } else {
          // 完成四圈，遊戲結束
          return copyWith(
            rounds: newRounds,
            status: GameStatus.finished,
          );
        }
      }
    }
    
    return copyWith(
      rounds: newRounds,
      currentWind: newWind,
      currentSequence: newSequence,
      dealerIndex: newDealerIndex,
      consecutiveWins: newConsecutiveWins,
    );
  }

  /// 還原上一局
  Game undoLastRound() {
    if (rounds.isEmpty) return this;
    
    final newRounds = rounds.sublist(0, rounds.length - 1);
    
    // 重新計算狀態（簡化版：重新遍歷所有局）
    // 實際應用中可以儲存每局後的狀態快照
    Game game = copyWith(
      rounds: [],
      currentWind: Wind.east,
      currentSequence: 1,
      dealerIndex: 0,
      consecutiveWins: 0,
    );
    
    for (var round in newRounds) {
      game = game.addRound(round);
    }
    
    return game;
  }
}
