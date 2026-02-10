import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../models/player.dart';
import '../services/calculation_service.dart';

/// 牌局詳細頁面
class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('牌局詳情 - ${dateFormat.format(game.createdAt)}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareGame(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.emoji_events), text: '最終排名'),
              Tab(icon: Icon(Icons.bar_chart), text: '數據統計'),
              Tab(icon: Icon(Icons.history), text: '局數詳情'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRankingTab(),
            _buildStatsTab(),
            _buildRoundsTab(),
          ],
        ),
      ),
    );
  }

  // ===== 第一頁：最終排名 =====
  Widget _buildRankingTab() {
    final scores = game.currentScores;
    final sortedPlayers = List<Player>.from(game.players);
    sortedPlayers.sort((a, b) {
      final scoreA = scores[a.id] ?? 0;
      final scoreB = scores[b.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 牌局概要
        _buildSummaryCard(),
        const SizedBox(height: 16),
        
        // 排名列表
        Card(
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
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
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

  // ===== 第二頁：數據統計 =====
  Widget _buildStatsTab() {
    final stats = _calculateStats();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '數據統計',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        ...game.players.map((player) {
          final playerStats = stats[player.id]!;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(player.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildStatRow('🏆 胡牌次數', playerStats['wins']!),
                  _buildStatRow('🎯 自摸次數', playerStats['selfDraws']!),
                  _buildStatRow('💥 放炮次數', playerStats['losses']!),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, int>> _calculateStats() {
    final stats = <String, Map<String, int>>{};
    
    // 初始化
    for (var player in game.players) {
      stats[player.id] = {
        'wins': 0,
        'selfDraws': 0,
        'losses': 0,
      };
    }

    // 統計
    for (var round in game.rounds) {
      switch (round.type) {
        case RoundType.win:
          if (round.winnerId != null) {
            stats[round.winnerId]!['wins'] = stats[round.winnerId]!['wins']! + 1;
          }
          if (round.loserId != null) {
            stats[round.loserId]!['losses'] = stats[round.loserId]!['losses']! + 1;
          }
          break;

        case RoundType.selfDraw:
          if (round.winnerId != null) {
            stats[round.winnerId]!['wins'] = stats[round.winnerId]!['wins']! + 1;
            stats[round.winnerId]!['selfDraws'] = stats[round.winnerId]!['selfDraws']! + 1;
          }
          break;

        case RoundType.multiWin:
          for (var winnerId in round.winnerIds) {
            stats[winnerId]!['wins'] = stats[winnerId]!['wins']! + 1;
          }
          if (round.loserId != null) {
            stats[round.loserId]!['losses'] = stats[round.loserId]!['losses']! + 1;
          }
          break;

        default:
          break;
      }
    }

    return stats;
  }

  // ===== 第三頁：局數詳情 =====
  Widget _buildRoundsTab() {
    final reversedRounds = game.rounds.reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        
        // 表格
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // 表頭
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ...game.players.map((player) {
                        return Expanded(
                          child: Column(
                            children: [
                              Text(player.emoji, style: const TextStyle(fontSize: 18)),
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
                  final dealer = _getPlayerById(round.dealerPlayerId);
                  final consecutiveWins = round.consecutiveWins ?? 0;
                  final dealerWasLost = (dealer != null && round.loserId == dealer.id);

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // 第一欄：局 + 結果 + 莊家資訊
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
                                      color: _getRoundColor(round).withValues(alpha: 0.15),
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
                                  if (dealer != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '莊:${dealer.emoji}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        if (consecutiveWins > 0)
                                          Text(
                                            ' 連$consecutiveWins',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  if (dealerWasLost)
                                    const Text(
                                      '莊被胡',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
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
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Player? _getPlayerById(String? playerId) {
    if (playerId == null) return null;
    try {
      return game.players.firstWhere((p) => p.id == playerId);
    } catch (e) {
      return null;
    }
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
