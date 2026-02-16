import '../models/game.dart';
import '../models/round.dart';

/// 單場牌局摘要
class GameSummary {
  final String gameId;
  final DateTime date;
  final int rank;         // 排名 (1-4)
  final int score;        // 該場得分
  final int rounds;       // 局數

  GameSummary({
    required this.gameId,
    required this.date,
    required this.rank,
    required this.score,
    required this.rounds,
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
  final int gamesTogether;  // 同場次數
  final int winsAgainst;    // 對該對手胡牌次數
  final int lossesAgainst;  // 被該對手胡牌次數

  OpponentRecord({
    required this.name,
    required this.emoji,
    required this.gamesTogether,
    required this.winsAgainst,
    required this.lossesAgainst,
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
  final List<GameSummary> recentGames;
  final BestRoundRecord? bestRound;  // 最高單局記錄

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
  });
}

/// 時間範圍類型
enum TimeRange {
  week,   // 近一週
  month,  // 近一月
  all,    // 全部
}

/// 統計計算服務
class StatsService {
  /// 計算指定玩家的統計數據
  static PlayerStats getPlayerStats(
    String profileId,
    List<Game> games, {
    TimeRange timeRange = TimeRange.all,
  }) {
    // 篩選包含該玩家的牌局
    var relevantGames = games.where((game) {
      return game.players.any((p) => p.userId == profileId);
    }).toList();

    // 根據時間範圍篩選
    if (timeRange != TimeRange.all) {
      final now = DateTime.now();
      final cutoffDate = timeRange == TimeRange.week
          ? now.subtract(const Duration(days: 7))
          : now.subtract(const Duration(days: 30));
      
      relevantGames = relevantGames.where((game) {
        return game.createdAt.isAfter(cutoffDate);
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
    final gameSummaries = <GameSummary>[];
    BestRoundRecord? bestRound;
    int bestRoundAmount = 0;

    for (final game in relevantGames) {
      // 找到該玩家在這場的 playerId
      final player = game.players.firstWhere((p) => p.userId == profileId);
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
        date: game.createdAt,
        rank: rank,
        score: gameScore,
        rounds: game.rounds.length,
      ));

      // 遍歷每局
      for (var i = 0; i < game.rounds.length; i++) {
        final round = game.rounds[i];
        totalRounds++;

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
            tai: round.totalTai,
            amount: roundScore,
          );
        }

        // 胡牌（放槍胡，不包含自摸）
        if (round.type == RoundType.win && round.winnerId == playerId) {
          wins++;
          totalTai += round.tai;
          taiCount++;
          if (round.tai > maxTai) maxTai = round.tai;
          taiDistribution[round.tai] = (taiDistribution[round.tai] ?? 0) + 1;
        }

        // 自摸
        if (round.type == RoundType.selfDraw && round.winnerId == playerId) {
          selfDraws++;
          totalTai += round.tai;
          taiCount++;
          if (round.tai > maxTai) maxTai = round.tai;
          taiDistribution[round.tai] = (taiDistribution[round.tai] ?? 0) + 1;
        }

        // 一炮多響中胡牌
        if (round.type == RoundType.multiWin && round.winnerIds.contains(playerId)) {
          wins++;
          totalTai += round.tai;
          taiCount++;
          if (round.tai > maxTai) maxTai = round.tai;
          taiDistribution[round.tai] = (taiDistribution[round.tai] ?? 0) + 1;
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

        // 對手勝負統計
        if (round.type == RoundType.win || round.type == RoundType.selfDraw) {
          if (round.winnerId == playerId && round.loserId != null) {
            // 我胡了對手
            final opp = game.players.firstWhere((p) => p.id == round.loserId);
            _getOpponent(opponentMap, opp.name, opp.emoji).winsAgainst++;
          } else if (round.loserId == playerId && round.winnerId != null) {
            // 對手胡了我
            final opp = game.players.firstWhere((p) => p.id == round.winnerId);
            _getOpponent(opponentMap, opp.name, opp.emoji).lossesAgainst++;
          }
        }
      }

      // 記錄同場對手
      for (final opp in game.players) {
        if (opp.id != playerId) {
          _getOpponent(opponentMap, opp.name, opp.emoji).gamesTogether++;
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
        gamesTogether: acc.gamesTogether,
        winsAgainst: acc.winsAgainst,
        lossesAgainst: acc.lossesAgainst,
      );
    }).toList()
      ..sort((a, b) => b.gamesTogether.compareTo(a.gamesTogether));

    // 排序牌局摘要（依時間降序）
    gameSummaries.sort((a, b) => b.date.compareTo(a.date));

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
      recentGames: gameSummaries.take(10).toList(),
      bestRound: bestRound,
    );
  }

  static _OpponentAccumulator _getOpponent(
    Map<String, _OpponentAccumulator> map, String name, String emoji,
  ) {
    return map.putIfAbsent(name, () => _OpponentAccumulator(name: name, emoji: emoji));
  }
}

class _OpponentAccumulator {
  final String name;
  final String emoji;
  int gamesTogether = 0;
  int winsAgainst = 0;
  int lossesAgainst = 0;

  _OpponentAccumulator({required this.name, required this.emoji});
}
