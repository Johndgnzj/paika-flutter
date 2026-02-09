import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../services/calculation_service.dart';

/// 牌局詳細頁面
class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final scores = game.currentScores;

    return Scaffold(
      appBar: AppBar(
        title: Text('牌局詳情 - ${dateFormat.format(game.createdAt)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareGame(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 牌局概要卡片
          _buildSummaryCard(scores),

          const SizedBox(height: 16),

          // 最終排名
          _buildRankingCard(scores),

          const SizedBox(height: 24),

          // 分隔線
          const Divider(thickness: 2),

          const SizedBox(height: 16),

          // 標題
          Row(
            children: [
              const Icon(Icons.history, size: 24),
              const SizedBox(width: 8),
              Text(
                '局數詳情 (${game.rounds.length} 局)',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 五欄表格：局+結果 | 玩家1 | 玩家2 | 玩家3 | 玩家4
          _buildRoundsTable(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, int> scores) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '牌局資訊',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('底分', '${game.settings.baseScore} 元'),
            _buildInfoRow('每台', '${game.settings.perTai} 元'),
            _buildInfoRow('總局數', '${game.rounds.length} 局'),
            _buildInfoRow(
                '狀態', game.status == GameStatus.finished ? '已結束' : '進行中'),
            _buildInfoRow('結束於', game.currentWindDisplay),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRankingCard(Map<String, int> scores) {
    final sortedPlayers = List.from(game.players);
    sortedPlayers.sort((a, b) {
      final scoreA = scores[a.id] ?? 0;
      final scoreB = scores[b.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最終排名',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...sortedPlayers.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final player = entry.value;
              final score = scores[player.id] ?? 0;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rank == 1 ? Colors.amber.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rank == 1 ? Colors.amber : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        _getRankEmoji(rank),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(player.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      CalculationService.formatScore(score),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: score > 0
                            ? Colors.green
                            : score < 0
                                ? Colors.red
                                : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      case 4:
        return '4️⃣';
      default:
        return '$rank';
    }
  }

  /// 五欄表格顯示每局分數增減，時間降序排列
  Widget _buildRoundsTable(BuildContext context) {
    // 時間降序排列
    final reversedRounds = game.rounds.reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // 表頭：玩家名稱
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      '局',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ...game.players.map((player) {
                    return Expanded(
                      child: Column(
                        children: [
                          Text(player.emoji,
                              style: const TextStyle(fontSize: 18)),
                          Text(
                            player.name,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 每局資料
            ...reversedRounds.map((round) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    // 第一欄：局 + 結果
                    SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          Text(
                            round.windDisplay,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoundColor(round)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getRoundTypeText(round),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getRoundColor(round),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 四欄：各玩家分數增減
                    ...game.players.map((player) {
                      final change = round.scoreChanges[player.id] ?? 0;
                      return Expanded(
                        child: Text(
                          change == 0 ? '-' : CalculationService.formatScore(change),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: change != 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: change > 0
                                ? Colors.green
                                : change < 0
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getRoundColor(Round round) {
    switch (round.type) {
      case RoundType.win:
        return Colors.blue;
      case RoundType.selfDraw:
        return Colors.green;
      case RoundType.falseWin:
        return Colors.red;
      case RoundType.multiWin:
        return Colors.orange;
      case RoundType.draw:
        return Colors.grey;
    }
  }

  String _getRoundTypeText(Round round) {
    switch (round.type) {
      case RoundType.win:
        return '胡牌';
      case RoundType.selfDraw:
        return '自摸';
      case RoundType.falseWin:
        return '詐胡';
      case RoundType.multiWin:
        return '一炮多響';
      case RoundType.draw:
        return '流局';
    }
  }

  void _shareGame(BuildContext context) {
    // TODO: 實作分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能開發中')),
    );
  }
}
