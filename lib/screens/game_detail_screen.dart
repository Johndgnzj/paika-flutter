import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game.dart';
import '../models/hand_pattern.dart';
import '../models/round.dart';
import '../models/player.dart';
import '../services/calculation_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../services/export_service.dart';
import '../widgets/game_share_card.dart';
import '../widgets/player_avatar.dart';

/// 牌局詳細頁面
class GameDetailScreen extends StatefulWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  bool _sortAscending = false; // 局數排序：false = 降序（最新優先），true = 順序

  Game get game => widget.game;

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
    
    final titles = _calculateTitles();
    final myProfileIds = context.read<GameProvider>().selfProfileIds;

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
                        PlayerGameAvatar(player: player, size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: myProfileIds.contains(player.userId)
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                              if (titles[player.id] != null && titles[player.id]!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    titles[player.id]!.join(' '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
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

  /// 計算牌局稱號
  Map<String, List<String>> _calculateTitles() {
    final stats = <String, Map<String, dynamic>>{};
    
    // 初始化每個玩家的統計
    for (final player in game.players) {
      stats[player.id] = {
        'wins': 0,      // 胡牌次數（不含自摸）
        'selfDraws': 0, // 自摸次數
        'losses': 0,    // 放槍次數
        'lastWinTime': DateTime.fromMillisecondsSinceEpoch(0),
        'lastSelfDrawTime': DateTime.fromMillisecondsSinceEpoch(0),
        'lastLossTime': DateTime.fromMillisecondsSinceEpoch(0),
      };
    }

    // 統計每局並記錄最後時間
    for (final round in game.rounds) {
      if (round.type == RoundType.win && round.winnerId != null) {
        stats[round.winnerId]!['wins'] = (stats[round.winnerId]!['wins'] ?? 0) + 1;
        stats[round.winnerId]!['lastWinTime'] = round.timestamp;
        if (round.loserId != null) {
          stats[round.loserId]!['losses'] = (stats[round.loserId]!['losses'] ?? 0) + 1;
          stats[round.loserId]!['lastLossTime'] = round.timestamp;
        }
      } else if (round.type == RoundType.selfDraw && round.winnerId != null) {
        stats[round.winnerId]!['selfDraws'] = (stats[round.winnerId]!['selfDraws'] ?? 0) + 1;
        stats[round.winnerId]!['lastSelfDrawTime'] = round.timestamp;
      } else if (round.type == RoundType.multiWin) {
        for (final winnerId in round.winnerIds) {
          stats[winnerId]!['wins'] = (stats[winnerId]!['wins'] ?? 0) + 1;
          stats[winnerId]!['lastWinTime'] = round.timestamp;
        }
        if (round.loserId != null) {
          stats[round.loserId]!['losses'] = (stats[round.loserId]!['losses'] ?? 0) + 1;
          stats[round.loserId]!['lastLossTime'] = round.timestamp;
        }
      }
    }

    // 找出各項冠軍（次數相同時，取最後發生事件的人）
    final titles = <String, List<String>>{};
    
    // 胡牌王
    final maxWins = stats.values.map((s) => s['wins'] as int).reduce((a, b) => a > b ? a : b);
    if (maxWins > 0) {
      String? winKing;
      DateTime? latestWinTime;
      for (final entry in stats.entries) {
        if (entry.value['wins'] == maxWins) {
          final winTime = entry.value['lastWinTime'] as DateTime;
          if (latestWinTime == null || winTime.isAfter(latestWinTime)) {
            winKing = entry.key;
            latestWinTime = winTime;
          }
        }
      }
      if (winKing != null) {
        titles.putIfAbsent(winKing, () => []).add('🏆 胡牌王');
      }
    }

    // 自摸王
    final maxSelfDraws = stats.values.map((s) => s['selfDraws'] as int).reduce((a, b) => a > b ? a : b);
    if (maxSelfDraws > 0) {
      String? selfDrawKing;
      DateTime? latestSelfDrawTime;
      for (final entry in stats.entries) {
        if (entry.value['selfDraws'] == maxSelfDraws) {
          final selfDrawTime = entry.value['lastSelfDrawTime'] as DateTime;
          if (latestSelfDrawTime == null || selfDrawTime.isAfter(latestSelfDrawTime)) {
            selfDrawKing = entry.key;
            latestSelfDrawTime = selfDrawTime;
          }
        }
      }
      if (selfDrawKing != null) {
        titles.putIfAbsent(selfDrawKing, () => []).add('🎯 自摸王');
      }
    }

    // 放槍王
    final maxLosses = stats.values.map((s) => s['losses'] as int).reduce((a, b) => a > b ? a : b);
    if (maxLosses > 0) {
      String? lossKing;
      DateTime? latestLossTime;
      for (final entry in stats.entries) {
        if (entry.value['losses'] == maxLosses) {
          final lossTime = entry.value['lastLossTime'] as DateTime;
          if (latestLossTime == null || lossTime.isAfter(latestLossTime)) {
            lossKing = entry.key;
            latestLossTime = lossTime;
          }
        }
      }
      if (lossKing != null) {
        titles.putIfAbsent(lossKing, () => []).add('💥 放槍王');
      }
    }

    return titles;
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
                              PlayerGameAvatar(player: player, size: 30),
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

    // 依排序方向排列將號
    final jiangKeys = groupedRounds.keys.toList()
      ..sort(_sortAscending ? (a, b) => a.compareTo(b) : (a, b) => b.compareTo(a));

    final contentWidgets = <Widget>[];
    contentWidgets.add(const SizedBox(height: 8));

    // 按將 → 風圈顯示
    for (int ji = 0; ji < jiangKeys.length; ji++) {
      final jiang = jiangKeys[ji];
      final circleMap = groupedRounds[jiang]!;
      final circleKeys = circleMap.keys.toList()
        ..sort(_sortAscending ? (a, b) => a.compareTo(b) : (a, b) => b.compareTo(a));

      // 將分隔線（非第一組時顯示）
      if (ji > 0) {
        contentWidgets.add(const SizedBox(height: 16));
        contentWidgets.add(
          Row(
            children: [
              Expanded(child: Divider(thickness: 3, color: Colors.orange.shade600)),
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
              Expanded(child: Divider(thickness: 3, color: Colors.orange.shade600)),
            ],
          ),
        );
        contentWidgets.add(const SizedBox(height: 16));
      }

      // 風圈分組
      for (final circle in circleKeys) {
        final rounds = circleMap[circle]!;
        // 內層局也依排序方向
        final displayRounds = _sortAscending ? rounds : rounds.reversed.toList();

        // 風圈標題
        contentWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${windNames[circle]}風圈${jiang > 1 ? " (第$jiang將)" : ""}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );

        // 各局行
        contentWidgets.add(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: displayRounds.map((round) {
                  final dealer = game.players[round.dealerSeat.clamp(0, 3)];
                  final consecutiveWins = round.consecutiveWins;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 左欄：局名 + 類型 + 莊家（字體 2×）
                        SizedBox(
                          width: 110,
                          child: Column(
                            children: [
                              Text(
                                round.windDisplay,
                                style: const TextStyle(fontSize: 22, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRoundColor(round).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getRoundTypeText(round),
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                    color: _getRoundColor(round),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (consecutiveWins > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    '連$consecutiveWins',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 牌型標籤
                              ..._buildPatternTags(round),
                              // 骰規標記
                              if (round.diceMode != DiceRuleMode.none && round.diceFactor > 1)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    '🎲×${round.diceFactor}${round.diceMode == DiceRuleMode.total ? '整' : '台'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 四欄：玩家分數
                        ...game.players.map((player) {
                          final change = round.scoreChanges[player.id] ?? 0;
                          final isDealer = player.id == dealer.id;
                          return Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  change == 0 ? '-' : CalculationService.formatScore(change),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: change != 0 ? FontWeight.bold : FontWeight.normal,
                                    color: change > 0
                                        ? Colors.green
                                        : change < 0
                                            ? Colors.red
                                            : Colors.grey,
                                  ),
                                ),
                                if (isDealer)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                                    ),
                                    child: const Text(
                                      '莊家',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 17), // 保持高度一致
                              ],
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

    contentWidgets.add(const SizedBox(height: 32));

    return CustomScrollView(
      slivers: [
        // 標題列 + 排序切換
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.history, size: 24),
                const SizedBox(width: 8),
                Text(
                  '局數詳情 (${game.rounds.length} 局)',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _sortAscending = !_sortAscending),
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                  label: Text(_sortAscending ? '順序' : '降序'),
                ),
              ],
            ),
          ),
        ),
        // 玩家名稱固定表頭
        SliverPersistentHeader(
          pinned: true,
          delegate: _RoundsPlayerHeaderDelegate(game.players),
        ),
        // 局數內容
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(contentWidgets),
          ),
        ),
      ],
    );
  }

  /// 建立牌型標籤列表（用於局數詳情左欄）
  List<Widget> _buildPatternTags(Round round) {
    final customPatterns = game.settings.customPatterns;
    final List<String> ids;

    // win/selfDraw 用 handPatternIds；multiWin 合併所有贏家的牌型
    if (round.type == RoundType.multiWin) {
      ids = round.winnerHandPatterns.values.expand((l) => l).toSet().toList();
    } else {
      ids = round.handPatternIds;
    }

    if (ids.isEmpty) return [];

    return [
      const SizedBox(height: 4),
      Wrap(
        spacing: 3,
        runSpacing: 2,
        alignment: WrapAlignment.center,
        children: ids.map((id) {
          final name = HandPattern.nameById(id, customPatterns);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.35)),
            ),
            child: Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFB8963E) : Colors.purple,
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    ];
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
                '分享牌局',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('截圖分享'),
              subtitle: const Text('最終排名 + 數據統計'),
              onTap: () {
                Navigator.pop(context);
                _shareScreenshots();
              },
            ),
            const Divider(),
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

  Future<void> _shareScreenshots() async {
    if (!mounted) return;

    // 彈出預覽 dialog，讓用戶確認後再分享
    await showDialog(
      context: context,
      builder: (ctx) => _SharePreviewDialog(game: game),
    );
  }
}

/// 局數詳情頁的固定玩家表頭
class _RoundsPlayerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Player> players;

  _RoundsPlayerHeaderDelegate(this.players);

  static const double _height = 68.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const SizedBox(width: 110), // 對齊左欄寬度
            ...players.map(
              (player) => Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PlayerGameAvatar(player: player, size: 28),
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_RoundsPlayerHeaderDelegate oldDelegate) =>
      oldDelegate.players != players;
}

/// 分享預覽 Dialog（含截圖邏輯）
class _SharePreviewDialog extends StatefulWidget {
  final Game game;
  const _SharePreviewDialog({required this.game});

  @override
  State<_SharePreviewDialog> createState() => _SharePreviewDialogState();
}

class _SharePreviewDialogState extends State<_SharePreviewDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;

  Future<void> _captureAndShare() async {
    setState(() => _isCapturing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100)); // 等待渲染完成
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('無法取得渲染物件');

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('圖片轉換失敗');

      final bytes = byteData.buffer.asUint8List();
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final timestamp = dateFormat.format(widget.game.createdAt);

      if (!mounted) return;
      Navigator.pop(context);

      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes, name: 'paika_$timestamp.png', mimeType: 'image/png'),
        ],
        subject: '${widget.game.name ?? "牌局"} - ${DateFormat("yyyy/MM/dd").format(widget.game.createdAt)}',
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('截圖失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 預覽卡片
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: RepaintBoundary(
              key: _repaintKey,
              child: GameShareCard(game: widget.game),
            ),
          ),
          const SizedBox(height: 16),
          // 按鈕列
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _isCapturing ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isCapturing ? null : _captureAndShare,
                icon: _isCapturing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share),
                label: Text(_isCapturing ? '生成中...' : '分享'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
