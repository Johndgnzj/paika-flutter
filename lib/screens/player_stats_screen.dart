import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/player_profile.dart';
import '../providers/game_provider.dart';
import '../services/stats_service.dart';
import '../services/calculation_service.dart';
import '../widgets/animation_helpers.dart';
import '../widgets/charts/score_trend_chart.dart';
import '../widgets/charts/win_rate_pie_chart.dart';
import '../widgets/charts/tai_distribution_chart.dart';
import 'game_detail_screen.dart';

class PlayerStatsScreen extends StatefulWidget {
  final PlayerProfile profile;

  const PlayerStatsScreen({super.key, required this.profile});

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  TimeRange _timeRange = TimeRange.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.profile.emoji} ${widget.profile.name}'),
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          final stats = StatsService.getPlayerStats(
            widget.profile.id,
            provider.gameHistory,
            timeRange: _timeRange,
          );

          if (stats.totalGames == 0) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('尚無牌局紀錄', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, stats),
                const SizedBox(height: 16),
                _buildTimeRangeSelector(),
                const SizedBox(height: 24),
                _buildStatsCards(context, stats),
                const SizedBox(height: 24),
                _buildTaiInfo(context, stats),
                const SizedBox(height: 24),
                if (stats.bestRound != null) ...[
                  _buildBestRound(context, stats, provider),
                  const SizedBox(height: 24),
                ],
                _buildCharts(context, stats),
                const SizedBox(height: 24),
                _buildRecentGames(context, stats, provider),
                const SizedBox(height: 24),
                _buildOpponents(context, stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return SegmentedButton<TimeRange>(
      segments: const [
        ButtonSegment(
          value: TimeRange.week,
          label: Text('近一週'),
        ),
        ButtonSegment(
          value: TimeRange.month,
          label: Text('近一月'),
        ),
        ButtonSegment(
          value: TimeRange.all,
          label: Text('全部'),
        ),
      ],
      selected: {_timeRange},
      onSelectionChanged: (Set<TimeRange> selected) {
        setState(() {
          _timeRange = selected.first;
        });
      },
    );
  }

  Widget _buildHeader(BuildContext context, PlayerStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text(widget.profile.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.profile.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildHighlight('${stats.totalGames}', '場次'),
                      const SizedBox(width: 24),
                      _buildHighlight('${(stats.winRate * 100).toStringAsFixed(1)}%', '勝率'),
                      const SizedBox(width: 24),
                      _buildHighlight(CalculationService.formatScore(stats.totalScore), '累計'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlight(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context, PlayerStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('戰績概覽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildStatCard('胡牌', '${stats.wins}', Colors.green),
            _buildStatCard('自摸', '${stats.selfDraws}', Colors.blue),
            _buildStatCard('放槍', '${stats.losses}', Colors.red),
            _buildStatCard('詐胡', '${stats.falseWins}', Colors.orange),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        CalculationService.formatScore(stats.bestGameScore),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const Text('單場最高', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        CalculationService.formatScore(stats.worstGameScore),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const Text('單場最低', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        stats.avgScorePerGame.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text('平均得分', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTaiInfo(BuildContext context, PlayerStats stats) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    stats.avgTai.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('平均台數', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${stats.maxTai}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('最高台數', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharts(BuildContext context, PlayerStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分數趨勢', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ScoreTrendChart(recentGames: stats.recentGames),
        const SizedBox(height: 24),
        const Text('勝負比例', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        WinRatePieChart(stats: stats),
        const SizedBox(height: 24),
        const Text('台數分布', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TaiDistributionChart(taiDistribution: stats.taiDistribution),
      ],
    );
  }

  Widget _buildRecentGames(BuildContext context, PlayerStats stats, GameProvider provider) {
    if (stats.recentGames.isEmpty) return const SizedBox.shrink();

    final dateFormat = DateFormat('MM/dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('最近牌局', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...stats.recentGames.map((summary) {
          final scoreColor = summary.score > 0 ? Colors.green : summary.score < 0 ? Colors.red : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: summary.rank == 1
                    ? Colors.amber.withValues(alpha: 0.25)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '#${summary.rank}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: summary.rank == 1
                        ? Colors.amber.shade700
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text(CalculationService.formatScore(summary.score),
                style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor)),
              subtitle: Text('${dateFormat.format(summary.date)}  ${summary.rounds}局'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 找到對應的完整 Game 物件
                try {
                  final game = provider.gameHistory.firstWhere((g) => g.id == summary.gameId);
                  Navigator.push(context, FadeSlidePageRoute(page: GameDetailScreen(game: game)));
                } catch (_) {}
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOpponents(BuildContext context, PlayerStats stats) {
    if (stats.opponents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('常見對手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...stats.opponents.map((opp) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(opp.emoji, style: const TextStyle(fontSize: 28)),
              title: Text(opp.name),
              subtitle: Text('同場 ${opp.gamesTogether} 次'),
              trailing: Text(
                '${opp.winsAgainst}勝 ${opp.lossesAgainst}負',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBestRound(BuildContext context, PlayerStats stats, GameProvider provider) {
    final best = stats.bestRound!;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('最高單局記錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.amber.withValues(alpha: 0.1),
          elevation: 4,
          child: InkWell(
            onTap: () {
              try {
                final game = provider.gameHistory.firstWhere((g) => g.id == best.gameId);
                Navigator.push(context, FadeSlidePageRoute(page: GameDetailScreen(game: game)));
              } catch (_) {}
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          best.gameName ?? '未命名牌局',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dateFormat.format(best.gameDate)} 第${best.roundIndex}局',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${best.tai}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                          const Text('台數', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            CalculationService.formatScore(best.amount),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const Text('得分', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
