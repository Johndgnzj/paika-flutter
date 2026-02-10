import '../models/game.dart';
import '../models/settings.dart';

/// 分數計算服務
class CalculationService {
  /// 計算胡牌（放槍）的分數變化
  static Map<String, int> calculateWin({
    required Game game,
    required String winnerId,
    required String loserId,
    required int tai,
    required int flowers,
  }) {
    final settings = game.settings;
    final totalTai = tai + flowers;
    
    // 檢查是否涉及莊家（莊家胡或莊家被胡）
    final dealer = game.dealer;
    final isDealerInvolved = (winnerId == dealer.id || loserId == dealer.id);
    
    final score = settings.calculateScore(
      totalTai,
      isDealer: isDealerInvolved,
      consecutiveWins: game.consecutiveWins,
    );
    
    final changes = <String, int>{};
    for (var player in game.players) {
      if (player.id == winnerId) {
        changes[player.id] = score;
      } else if (player.id == loserId) {
        changes[player.id] = -score;
      } else {
        changes[player.id] = 0;
      }
    }
    
    return changes;
  }

  /// 計算自摸的分數變化
  static Map<String, int> calculateSelfDraw({
    required Game game,
    required String winnerId,
    required int tai,
    required int flowers,
  }) {
    final settings = game.settings;
    final totalTai = tai + flowers;
    
    // 檢查是否莊家自摸
    final dealer = game.dealer;
    final isDealer = (winnerId == dealer.id);
    
    final score = settings.calculateScore(
      totalTai,
      isSelfDraw: true,
      isDealer: isDealer,
      consecutiveWins: game.consecutiveWins,
    );
    
    final changes = <String, int>{};
    for (var player in game.players) {
      if (player.id == winnerId) {
        // 贏家拿三家的錢
        changes[player.id] = score * 3;
      } else {
        // 其他人各付
        changes[player.id] = -score;
      }
    }
    
    return changes;
  }

  /// 計算詐胡的分數變化
  static Map<String, int> calculateFalseWin({
    required Game game,
    required String falserId,
  }) {
    final settings = game.settings;
    final penalty = settings.calculateScore(settings.falseWinTai);
    
    final changes = <String, int>{};
    
    if (settings.falseWinPayAll) {
      // 賠三家
      for (var player in game.players) {
        if (player.id == falserId) {
          changes[player.id] = -penalty * 3;
        } else {
          changes[player.id] = penalty;
        }
      }
    } else {
      // 只賠莊家（或特定一家）
      final dealer = game.dealer;
      for (var player in game.players) {
        if (player.id == falserId) {
          changes[player.id] = -penalty;
        } else if (player.id == dealer.id) {
          changes[player.id] = penalty;
        } else {
          changes[player.id] = 0;
        }
      }
    }
    
    return changes;
  }

  /// 計算一炮多響的分數變化
  static Map<String, int> calculateMultiWin({
    required Game game,
    required List<String> winnerIds,
    required String loserId,
    required Map<String, int> taiMap,  // {winnerId: tai}
    required Map<String, int> flowerMap, // {winnerId: flowers}
  }) {
    final settings = game.settings;
    final changes = <String, int>{};
    final dealer = game.dealer;
    
    // 初始化所有玩家分數為 0
    for (var player in game.players) {
      changes[player.id] = 0;
    }
    
    // 計算每個贏家應得的分數
    int totalLoss = 0;
    for (var winnerId in winnerIds) {
      final tai = taiMap[winnerId] ?? 0;
      final flowers = flowerMap[winnerId] ?? 0;
      
      // 檢查是否涉及莊家（贏家是莊家或放槍者是莊家）
      final isDealerInvolved = (winnerId == dealer.id || loserId == dealer.id);
      
      final score = settings.calculateScore(
        tai + flowers,
        isDealer: isDealerInvolved,
        consecutiveWins: game.consecutiveWins,
      );
      
      changes[winnerId] = (changes[winnerId] ?? 0) + score;
      totalLoss += score;
    }
    
    // 放槍者全賠
    changes[loserId] = -totalLoss;
    
    return changes;
  }

  /// 計算流局（簡化版：不處理聽牌）
  static Map<String, int> calculateDraw({
    required Game game,
  }) {
    // 簡化版：流局不計分
    final changes = <String, int>{};
    for (var player in game.players) {
      changes[player.id] = 0;
    }
    return changes;
  }

  /// 格式化分數顯示（加上 + / - 符號）
  static String formatScore(int score) {
    if (score > 0) {
      return '+$score';
    } else if (score < 0) {
      return '$score';
    } else {
      return '0';
    }
  }

  /// 計算預覽（不儲存，用於顯示）
  static String getScorePreview({
    required GameSettings settings,
    required int tai,
    required int flowers,
    required bool isSelfDraw,
    required bool isDealer,
    required int consecutiveWins,
  }) {
    final baseTai = tai + flowers;
    int effectiveTai = baseTai;
    
    // 計算有效台數
    if (isSelfDraw && settings.selfDrawAddTai) {
      effectiveTai += 1;
    }
    if (isDealer && settings.dealerTai) {
      effectiveTai += 1;
    }
    if (settings.consecutiveTai && consecutiveWins > 0) {
      effectiveTai += consecutiveWins * 2;
    }
    
    final score = settings.calculateScore(
      baseTai,
      isSelfDraw: isSelfDraw,
      isDealer: isDealer,
      consecutiveWins: consecutiveWins,
    );
    
    // 組合說明文字
    String taiBreakdown = '$baseTai台';
    if (isSelfDraw && settings.selfDrawAddTai) {
      taiBreakdown += ' + 1台(自摸)';
    }
    if (isDealer && settings.dealerTai) {
      taiBreakdown += ' + 1台(莊家)';
    }
    if (settings.consecutiveTai && consecutiveWins > 0) {
      taiBreakdown += ' + ${consecutiveWins * 2}台(連莊×$consecutiveWins)';
    }
    
    if (baseTai != effectiveTai) {
      taiBreakdown += ' = $effectiveTai台';
    }
    
    if (isSelfDraw) {
      return '$taiBreakdown\n'
             '${settings.baseScore} + ($effectiveTai × ${settings.perTai}) = $score\n'
             '三家各付 $score，贏家共得 ${score * 3}';
    } else {
      return '$taiBreakdown\n'
             '${settings.baseScore} + ($effectiveTai × ${settings.perTai}) = $score';
    }
  }
}
