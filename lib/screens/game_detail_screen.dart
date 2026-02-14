import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../models/player.dart';
import '../services/calculation_service.dart';
import '../services/export_service.dart';

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

                  return Builder(
                    builder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? Colors.amber.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rank == 1
                            ? Colors.amber
                            : colorScheme.outlineVariant,
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
                    },
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

        // 統計表格
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 表頭
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        '玩家',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '🏆 胡牌',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '🎯 自摸',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '💥 放槍',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 2),

                // 各玩家數據
                ...game.players.map((player) {
                  final playerStats = stats[player.id]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Text(player.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${playerStats['wins']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${playerStats['selfDraws']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${playerStats['losses']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
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
  /// 使用 round.jiangNumber + round.windCircle 做二層分組
  Widget _buildRoundsTab() {
    if (game.rounds.isEmpty) {
      return const Center(child: Text('尚無局數紀錄'));
    }

    const windNames = ['東', '南', '西', '北'];

    // 二層分組：將 → 風圈 → rounds
    // key = (jiangNumber, windCircle)
    final groupedRounds = <int, Map<int, List<Round>>>{};
    for (var round in game.rounds) {
      final jiang = round.jiangNumber;
      final circle = round.windCircle;
      groupedRounds.putIfAbsent(jiang, () => {});
      groupedRounds[jiang]!.putIfAbsent(circle, () => []);
      groupedRounds[jiang]![circle]!.add(round);
    }

    // 將號排序（由小到大）
    final jiangKeys = groupedRounds.keys.toList()..sort();

    final widgets = <Widget>[];

    // 標題
    widgets.add(
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
    );
    widgets.add(const SizedBox(height: 16));

    // 表頭（玩家名稱）
    widgets.add(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 2),
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
        ),
      ),
    );

    // 按將 → 風圈顯示
    for (int ji = 0; ji < jiangKeys.length; ji++) {
      final jiang = jiangKeys[ji];
      final circleMap = groupedRounds[jiang]!;
      final circleKeys = circleMap.keys.toList()..sort();

      // 將分隔線（第2將開始顯示）
      if (jiang > 1) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(
          Row(
            children: [
              Expanded(
                child: Divider(
                  thickness: 3,
                  color: Colors.orange.shade600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '第 $jiang 將',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  thickness: 3,
                  color: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        );
        widgets.add(const SizedBox(height: 16));
      }

      // 風圈分組
      for (final circle in circleKeys) {
        final rounds = circleMap[circle]!;

        // 風圈標題
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${windNames[circle]}風圈${jiang > 1 ? " (第$jiang將)" : ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // 該風圈的所有局（倒序顯示）
        widgets.add(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: rounds.reversed.map((round) {
                  // 根據 dealerSeat 找到莊家
                  final dealer = game.players[round.dealerSeat.clamp(0, 3)];
                  final consecutiveWins = round.consecutiveWins;
                  final dealerWasLost = (round.loserId == dealer.id);

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
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
                  );
                }).toList(),
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: widgets,
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
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '匯出牌局',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              subtitle: const Text('完整牌局資料'),
              onTap: () {
                Navigator.pop(context);
                final json = ExportService.exportGameToJson(game);
                ExportService.shareText(json, 'paika_game.json');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('試算表格式'),
              onTap: () {
                Navigator.pop(context);
                final csv = ExportService.exportGameToCsv(game);
                ExportService.shareText(csv, 'paika_game.csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              subtitle: const Text('排版報表'),
              onTap: () async {
                Navigator.pop(context);
                final bytes = await ExportService.exportGameToPdf(game);
                await ExportService.shareFile(bytes, 'paika_game.pdf', 'application/pdf');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
