import '../models/game.dart';
import '../models/hand_pattern.dart';
import '../models/round.dart';
import 'calculation_service.dart';

/// 單場牌局摘要
class GameSummary {
  final String gameId;
  final String? gameName;
  final DateTime date;
  final int rank;         // 排名 (1-4)
  final int score;        // 該場得分
  final int rounds;       // 局數
  final int jiangCount;   // 將數
  final int baseScore;    // 底分
  final int perTai;       // 台數

  GameSummary({
    required this.gameId,
    this.gameName,
    required this.date,
    required this.rank,
    required this.score,
    required this.rounds,
    required this.jiangCount,
    required this.baseScore,
    required this.perTai,
  });
}

/// 最高單局記錄
class BestRoundRecord {
  final String gameId;
  final String? gameName;
  final DateTime gameDate;
  final String roundId;
  final int roundIndex;    // 該局在牌局中的序號（從1開始）
  final int tai;           // 台數
  final int amount;        // 贏得金額

  BestRoundRecord({
    required this.gameId,
    this.gameName,
    required this.gameDate,
    required this.roundId,
    required this.roundIndex,
    required this.tai,
    required this.amount,
  });
}

/// 對手統計記錄
class OpponentRecord {
  final String name;
  final String emoji;
  final String? userId;      // 代表性 profileId（用於顯示對手頭像照片）
  final int gamesTogether;   // 同場次數（場）
  final int roundsTogether;  // 同場總局數
  final int winsAgainst;    // 我胡牌（任意）總次數（舊欄位保留相容）
  final int lossesAgainst;  // 被胡總次數（舊欄位保留相容）
  final int winsBy;         // 我直接胡對手（對手放槍）次數
  final int lossesBy;       // 被對手直接胡（我放槍）次數

  OpponentRecord({
    required this.name,
    required this.emoji,
    this.userId,
    required this.gamesTogether,
    required this.roundsTogether,
    required this.winsAgainst,
    required this.lossesAgainst,
    required this.winsBy,
    required this.lossesBy,
  });
}

/// 特殊牌型統計（本人達成的牌型次數）
class HandPatternStat {
  final String id;
  final String name;
  final int referenceTai; // 參考台數（顯示用）
  final int count;        // 達成次數

  HandPatternStat({
    required this.id,
    required this.name,
    required this.referenceTai,
    required this.count,
  });
}

/// 玩家統計資料
class PlayerStats {
  final int totalGames;
  final int totalRounds;
  final int wins;           // 胡牌次數（放槍胡）
  final int selfDraws;      // 自摸次數
  final int losses;         // 放槍次數
  final int falseWins;      // 詐胡次數
  final double winRate;     // 勝率 = (胡 + 自摸) / 參與局數
  final int totalScore;     // 累計總得分
  final double avgScorePerGame;
  final int bestGameScore;
  final int worstGameScore;
  final double avgTai;
  final int maxTai;
  final Map<int, int> taiDistribution; // 台數 → 次數
  final List<OpponentRecord> opponents;
  final List<GameSummary> recentGames; // 時間範圍內所有牌局摘要（依時間降序）
  final BestRoundRecord? bestRound;  // 最高單局記錄
  final List<HandPatternStat> handPatternStats; // 特殊牌型統計（依次數降序）

  PlayerStats({
    required this.totalGames,
    required this.totalRounds,
    required this.wins,
    required this.selfDraws,
    required this.losses,
    required this.falseWins,
    required this.winRate,
    required this.totalScore,
    required this.avgScorePerGame,
    required this.bestGameScore,
    required this.worstGameScore,
    required this.avgTai,
    required this.maxTai,
    required this.taiDistribution,
    required this.opponents,
    required this.recentGames,
    this.bestRound,
    this.handPatternStats = const [],
  });
}

/// 時間範圍類型
enum TimeRange {
  week,   // 近一週
  month,  // 近一月
  all,    // 全部
  custom, // 自訂區間
}

/// 統計計算服務
class StatsService {
  /// 計算指定玩家的統計數據（支援多 profileId 聚合）
  ///
  /// 累計總分（totalScore）規則：把該玩家在「時間範圍內、有參與的每一場牌局」
  /// 的單場淨得分（該場所有局的分數變動加總）再加總起來。
  /// timeRange=all 時即為全部歷史牌局的累計；custom 時依 customStart~customEnd 篩選。
  static PlayerStats getPlayerStats(
    List<String> profileIds,
    List<Game> games, {
    TimeRange timeRange = TimeRange.all,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    // 篩選包含該玩家的牌局（任一 profileId 符合即可）
    var relevantGames = games.where((game) {
      return game.players.any((p) => profileIds.contains(p.userId));
    }).toList();

    // 計算時間範圍的起訖（all 不限制）
    final now = DateTime.now();
    DateTime? rangeStart;
    DateTime? rangeEnd;
    switch (timeRange) {
      case TimeRange.week:
        rangeStart = now.subtract(const Duration(days: 7));
        break;
      case TimeRange.month:
        rangeStart = now.subtract(const Duration(days: 30));
        break;
      case TimeRange.custom:
        rangeStart = customStart;
        // 結束日納入整天（到 23:59:59）
        rangeEnd = customEnd == null
            ? null
            : DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999);
        break;
      case TimeRange.all:
        break;
    }

    if (rangeStart != null || rangeEnd != null) {
      relevantGames = relevantGames.where((game) {
        final d = game.createdAt;
        if (rangeStart != null && d.isBefore(rangeStart)) return false;
        if (rangeEnd != null && d.isAfter(rangeEnd)) return false;
        return true;
      }).toList();
    }

    if (relevantGames.isEmpty) {
      return PlayerStats(
        totalGames: 0,
        totalRounds: 0,
        wins: 0,
        selfDraws: 0,
        losses: 0,
        falseWins: 0,
        winRate: 0,
        totalScore: 0,
        avgScorePerGame: 0,
        bestGameScore: 0,
        worstGameScore: 0,
        avgTai: 0,
        maxTai: 0,
        taiDistribution: {},
        opponents: [],
        recentGames: [],
      );
    }

    int totalRounds = 0;
    int wins = 0;
    int selfDraws = 0;
    int losses = 0;
    int falseWins = 0;
    int totalScore = 0;
    int bestGameScore = -999999;
    int worstGameScore = 999999;
    int totalTai = 0;
    int taiCount = 0;
    int maxTai = 0;
    final taiDistribution = <int, int>{};
    final opponentMap = <String, _OpponentAccumulator>{};
    final patternMap = <String, _PatternAccumulator>{};
    final gameSummaries = <GameSummary>[];
    BestRoundRecord? bestRound;
    int bestRoundAmount = 0;


    for (final game in relevantGames) {
      // 找到該玩家在這場的 playerId（用任一符合的 profileId）
      final player = game.players.firstWhere((p) => profileIds.contains(p.userId));
      final playerId = player.id;
      final scores = game.currentScores;
      final gameScore = scores[playerId] ?? 0;

      totalScore += gameScore;
      if (gameScore > bestGameScore) bestGameScore = gameScore;
      if (gameScore < worstGameScore) worstGameScore = gameScore;

      // 計算排名
      final sortedScores = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      int rank = 1;
      for (final entry in sortedScores) {
        if (entry.key == playerId) break;
        rank++;
      }

      gameSummaries.add(GameSummary(
        gameId: game.id,
        gameName: game.name,
        date: game.createdAt,
        rank: rank,
        score: gameScore,
        rounds: game.rounds.length,
        jiangCount: game.jiangs.length,
        baseScore: game.settings.baseScore,
        perTai: game.settings.perTai,
      ));

      // 遍歷每局
      for (var i = 0; i < game.rounds.length; i++) {
        final round = game.rounds[i];
        totalRounds++;

        // 有效台數（含莊家、連莊加台）
        final effTai = CalculationService.effectiveTaiFromRound(
            round, game.settings, game.players);

        // 檢查該局得分（追蹤最高單局記錄）
        final roundScore = round.scoreChanges[playerId] ?? 0;
        if (roundScore > bestRoundAmount) {
          bestRoundAmount = roundScore;
          bestRound = BestRoundRecord(
            gameId: game.id,
            gameName: game.name,
            gameDate: game.createdAt,
            roundId: round.id,
            roundIndex: i + 1,
            tai: effTai, // 使用有效台數
            amount: roundScore,
          );
        }

        // 胡牌（放槍胡，不包含自摸）
        if (round.type == RoundType.win && round.winnerId == playerId) {
          wins++;
          totalTai += effTai;
          taiCount++;
          if (effTai > maxTai) maxTai = effTai;
          taiDistribution[effTai] = (taiDistribution[effTai] ?? 0) + 1;
        }

        // 自摸
        if (round.type == RoundType.selfDraw && round.winnerId == playerId) {
          selfDraws++;
          totalTai += effTai;
          taiCount++;
          if (effTai > maxTai) maxTai = effTai;
          taiDistribution[effTai] = (taiDistribution[effTai] ?? 0) + 1;
        }

        // 一炮多響中胡牌
        if (round.type == RoundType.multiWin && round.winnerIds.contains(playerId)) {
          wins++;
          totalTai += effTai;
          taiCount++;
          if (effTai > maxTai) maxTai = effTai;
          taiDistribution[effTai] = (taiDistribution[effTai] ?? 0) + 1;
        }

        // 放槍
        if ((round.type == RoundType.win || round.type == RoundType.multiWin) &&
            round.loserId == playerId) {
          losses++;
        }

        // 詐胡
        if (round.type == RoundType.falseWin && round.loserId == playerId) {
          falseWins++;
        }

        // 特殊牌型統計（僅計入本人為贏家的局）
        List<String> myPatternIds = const [];
        if (round.winnerId == playerId &&
            (round.type == RoundType.win || round.type == RoundType.selfDraw)) {
          myPatternIds = round.handPatternIds;
        } else if (round.type == RoundType.multiWin &&
            round.winnerIds.contains(playerId)) {
          myPatternIds = round.winnerHandPatterns[playerId] ?? round.handPatternIds;
        }
        for (final pid in myPatternIds) {
          final acc = patternMap.putIfAbsent(pid, () {
            final hp = _resolveHandPattern(pid, game.settings.customPatterns);
            return _PatternAccumulator(
                id: pid, name: hp.name, referenceTai: hp.referenceTai);
          });
          acc.count++;
        }

        // 對手勝負統計
        if (round.type == RoundType.win || round.type == RoundType.selfDraw) {
          if (round.winnerId == playerId && round.loserId != null) {
            // 我胡了對手（放槍）
            final opp = game.players.firstWhere((p) => p.id == round.loserId);
            _getOpponent(opponentMap, opp.name, opp.emoji, opp.userId).winsAgainst++;
            if (round.type == RoundType.win) {
              _getOpponent(opponentMap, opp.name, opp.emoji, opp.userId).winsBy++;
            }
          } else if (round.loserId == playerId && round.winnerId != null) {
            // 對手胡了我
            final opp = game.players.firstWhere((p) => p.id == round.winnerId);
            _getOpponent(opponentMap, opp.name, opp.emoji, opp.userId).lossesAgainst++;
            if (round.type == RoundType.win) {
              _getOpponent(opponentMap, opp.name, opp.emoji, opp.userId).lossesBy++;
            }
          }
        }
      }

      // 記錄同場對手
      for (final opp in game.players) {
        if (opp.id != playerId) {
          final acc = _getOpponent(opponentMap, opp.name, opp.emoji, opp.userId);
          acc.gamesTogether++;
          acc.roundsTogether += game.rounds.length;
        }
      }
    }

    final totalGames = relevantGames.length;
    final winRate = totalRounds > 0 ? (wins + selfDraws) / totalRounds : 0.0;
    final avgScorePerGame = totalGames > 0 ? totalScore / totalGames : 0.0;
    final avgTai = taiCount > 0 ? totalTai / taiCount : 0.0;

    // 排序對手（依同場次數降序）
    final opponents = opponentMap.values.map((acc) {
      return OpponentRecord(
        name: acc.name,
        emoji: acc.emoji,
        userId: acc.userId,
        gamesTogether: acc.gamesTogether,
        roundsTogether: acc.roundsTogether,
        winsAgainst: acc.winsAgainst,
        lossesAgainst: acc.lossesAgainst,
        winsBy: acc.winsBy,
        lossesBy: acc.lossesBy,
      );
    }).toList()
      ..sort((a, b) => b.gamesTogether.compareTo(a.gamesTogether));

    // 排序牌局摘要（依時間降序）
    gameSummaries.sort((a, b) => b.date.compareTo(a.date));

    // 特殊牌型統計（依次數降序，次數相同時依參考台數降序）
    final handPatternStats = patternMap.values
        .map((a) => HandPatternStat(
            id: a.id, name: a.name, referenceTai: a.referenceTai, count: a.count))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return b.referenceTai.compareTo(a.referenceTai);
      });

    return PlayerStats(
      totalGames: totalGames,
      totalRounds: totalRounds,
      wins: wins,
      selfDraws: selfDraws,
      losses: losses,
      falseWins: falseWins,
      winRate: winRate,
      totalScore: totalScore,
      avgScorePerGame: avgScorePerGame,
      bestGameScore: totalGames > 0 ? bestGameScore : 0,
      worstGameScore: totalGames > 0 ? worstGameScore : 0,
      avgTai: avgTai,
      maxTai: maxTai,
      taiDistribution: taiDistribution,
      opponents: opponents.take(5).toList(),
      recentGames: gameSummaries, // 時間範圍內的完整清單（已依時間降序），由 UI 決定呈現
      bestRound: bestRound,
      handPatternStats: handPatternStats,
    );
  }

  static _OpponentAccumulator _getOpponent(
      Map<String, _OpponentAccumulator> map, String name, String emoji,
      [String? userId]) {
    final acc = map.putIfAbsent(name, () => _OpponentAccumulator(name: name, emoji: emoji));
    acc.userId ??= userId; // 記錄第一個非空 userId 作為頭像反查依據
    return acc;
  }

  /// 依 ID 解析牌型（系統 + 該局自訂）；找不到時以 ID 作為名稱、台數 0
  static HandPattern _resolveHandPattern(String id, List<HandPattern> customPatterns) {
    for (final p in HandPattern.allPatterns(customPatterns)) {
      if (p.id == id) return p;
    }
    return HandPattern(id: id, name: id, referenceTai: 0);
  }
}

class _OpponentAccumulator {
  final String name;
  final String emoji;
  String? userId;
  int gamesTogether = 0;
  int roundsTogether = 0;
  int winsAgainst = 0;
  int lossesAgainst = 0;
  int winsBy = 0;     // 我直接胡對手（對手放槍）
  int lossesBy = 0;   // 被對手直接胡（我放槍）

  _OpponentAccumulator({required this.name, required this.emoji});
}

class _PatternAccumulator {
  final String id;
  final String name;
  final int referenceTai;
  int count = 0;

  _PatternAccumulator({
    required this.id,
    required this.name,
    required this.referenceTai,
  });
}
