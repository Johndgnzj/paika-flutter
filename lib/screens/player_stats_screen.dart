import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import '../models/player.dart';
import '../models/player_profile.dart';
import '../providers/game_provider.dart';
import '../services/stats_service.dart';
import '../services/calculation_service.dart';
import '../services/avatar_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../widgets/animation_helpers.dart';
import '../widgets/player_avatar.dart';
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
  DateTimeRange? _customRange; // 自訂時間區間（_timeRange == custom 時生效）
  late PlayerProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
  }

  void _refreshProfile() {
    final provider = context.read<GameProvider>();
    final updated = provider.playerProfiles.firstWhere(
      (p) => p.id == widget.profile.id,
      orElse: () => widget.profile,
    );
    setState(() {
      _currentProfile = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(profile: _currentProfile, size: 28),
            const SizedBox(width: 8),
            Flexible(child: Text(_currentProfile.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編輯玩家',
            onPressed: () => _showEditSheet(context),
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          // For the self profile, include linked profile IDs from other accounts so
          // that games recorded under the linked account also appear in stats.
          final profileIds = [_currentProfile.id, ..._currentProfile.mergedProfileIds];
          if (provider.selfProfileIds.contains(_currentProfile.id)) {
            profileIds.addAll(provider.linkedProfileIds);
          }
          final stats = StatsService.getPlayerStats(
            profileIds,
            provider.gameHistory,
            timeRange: _timeRange,
            customStart: _customRange?.start,
            customEnd: _customRange?.end,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, stats),
                const SizedBox(height: 16),
                _buildTimeRangeSelector(),
                const SizedBox(height: 24),
                // 空狀態改為行內顯示，確保時間範圍選擇器一直可操作
                if (stats.totalGames == 0)
                  _buildEmptyInRange()
                else ...[
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
                  _buildHandPatterns(context, stats),
                  const SizedBox(height: 24),
                  _buildRecentGames(context, stats, provider),
                  const SizedBox(height: 24),
                  _buildOpponents(context, stats),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TimeRange>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TimeRange.week, label: Text('近一週')),
              ButtonSegment(value: TimeRange.month, label: Text('近一月')),
              ButtonSegment(value: TimeRange.all, label: Text('全部')),
              ButtonSegment(value: TimeRange.custom, label: Text('自訂')),
            ],
            selected: {_timeRange},
            onSelectionChanged: (Set<TimeRange> selected) async {
              final choice = selected.first;
              if (choice == TimeRange.custom) {
                await _pickCustomRange();
              } else {
                setState(() => _timeRange = choice);
              }
            },
          ),
        ),
        if (_timeRange == TimeRange.custom && _customRange != null) ...[
          const SizedBox(height: 8),
          _buildCustomRangeLabel(),
        ],
      ],
    );
  }

  /// 自訂區間文字（可點擊重新選擇）
  Widget _buildCustomRangeLabel() {
    final f = DateFormat('yyyy/MM/dd');
    final r = _customRange!;
    return InkWell(
      onTap: _pickCustomRange,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              '${f.format(r.start)} ~ ${f.format(r.end)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// 開啟自訂區間選擇器
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialRange = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initialRange,
      helpText: '選擇統計區間',
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _timeRange = TimeRange.custom;
      });
    }
  }

  /// 此時間範圍內無牌局
  Widget _buildEmptyInRange() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _timeRange == TimeRange.all ? '尚無牌局紀錄' : '此時間範圍內尚無牌局紀錄',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PlayerStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            PlayerAvatar(profile: _currentProfile, size: 64),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentProfile.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
    final totalRounds = stats.totalRounds;
    final winRate    = totalRounds > 0 ? stats.wins      / totalRounds * 100 : 0.0;
    final selfRate   = totalRounds > 0 ? stats.selfDraws / totalRounds * 100 : 0.0;
    final lossRate   = totalRounds > 0 ? stats.losses    / totalRounds * 100 : 0.0;

    // 綜合戰力 0~100
    // 公式：自摸率*40 + 胡牌率*30 + (1-放槍率)*20 + 場次權重*10
    // 場次權重：log(場次+1)/log(51) capped at 1

    final gameWeight = stats.totalGames > 0
        ? (math.log(stats.totalGames + 1) / math.log(51)).clamp(0.0, 1.0)
        : 0.0;
    final power = ((selfRate / 100) * 40 +
                   (winRate / 100) * 30 +
                   (1 - (lossRate / 100)) * 20 +
                   gameWeight * 10).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('戰績概覽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showPowerFormula(context),
              child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第一行：胡牌、自摸、放槍 大字 + 機率，以及綜合戰力
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildStatCard('胡牌', '${stats.wins}', Colors.green,
                sub: '${winRate.toStringAsFixed(1)}%'),
            _buildStatCard('自摸', '${stats.selfDraws}', Colors.blue,
                sub: '${selfRate.toStringAsFixed(1)}%'),
            _buildStatCard('放槍', '${stats.losses}', Colors.red,
                sub: '${lossRate.toStringAsFixed(1)}%'),
            _buildPowerCard(power.round()),
          ],
        ),
        const SizedBox(height: 8),
        // 第二行：詐胡 + 單場最高最低 + 平均
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text('${stats.falseWins}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const Text('詐胡', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(CalculationService.formatScore(stats.bestGameScore),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const Text('單場最高', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(CalculationService.formatScore(stats.worstGameScore),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    const Text('單場最低', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(stats.avgScorePerGame.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('平均得分', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, {String? sub}) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          if (sub != null)
            Text(sub, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPowerCard(int power) {
    final color = power >= 70
        ? Colors.amber
        : power >= 40
            ? Colors.blue
            : Colors.grey;
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$power', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          const Text('戰力', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showPowerFormula(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('綜合戰力計算公式'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('滿分 100 分，由以下四項加總：', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('🀄 自摸率 × 40 分'),
              Text('   自摸次數 ÷ 參與局數'),
              SizedBox(height: 8),
              Text('🀄 胡牌率 × 30 分'),
              Text('   胡牌次數 ÷ 參與局數'),
              SizedBox(height: 8),
              Text('🛡 不放槍率 × 20 分'),
              Text('   (1 − 放槍率)，放槍越少越高'),
              SizedBox(height: 8),
              Text('📊 場次權重 × 10 分'),
              Text('   log(場次+1) / log(51)，最多 50 場滿分'),
              SizedBox(height: 12),
              Text('說明：', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('場次少時戰力偏低，反映樣本不足的不確定性。'
                   '高胡牌率 + 高自摸率 + 低放槍率可達到高分。'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('了解了')),
        ],
      ),
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
          final r = opp.roundsTogether;
          final winPct  = r > 0 ? (opp.winsBy  / r * 100).toStringAsFixed(1) : '-';
          final lossPct = r > 0 ? (opp.lossesBy / r * 100).toStringAsFixed(1) : '-';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: PlayerGameAvatar(
                player: Player(
                  id: opp.userId ?? opp.name,
                  userId: opp.userId,
                  name: opp.name,
                  emoji: opp.emoji,
                ),
                size: 36,
              ),
              title: Text(opp.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('同場 ${opp.gamesTogether} 場 / ${opp.roundsTogether} 局'),
                  Text(
                    '胡對手 ${opp.winsBy}次($winPct%)  被胡 ${opp.lossesBy}次($lossPct%)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Text(
                '${opp.winsAgainst}胡\n${opp.lossesAgainst}放',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
        }),
      ],
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

  Widget _buildHandPatterns(BuildContext context, PlayerStats stats) {
    final scheme = Theme.of(context).colorScheme;
    final patterns = stats.handPatternStats;
    final totalTimes = patterns.fold<int>(0, (sum, p) => sum + p.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('特殊牌型', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (patterns.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('共 ${patterns.length} 種 / $totalTimes 次',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (patterns.isEmpty)
          Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '尚無特殊牌型紀錄\n（記分時於「特殊牌型」選擇牌型即會計入）',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: patterns.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    if (p.referenceTai > 0) ...[
                      const SizedBox(width: 4),
                      Text('${p.referenceTai}台',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSecondaryContainer.withValues(alpha: 0.7),
                          )),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '×${p.count}',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCharts(BuildContext context, PlayerStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分數趨勢（近 20 場）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ScoreTrendChart(recentGames: stats.recentGames.take(20).toList()),
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

    final dateFormat = DateFormat('yyyy/MM/dd');
    final sortedGames = List.of(stats.recentGames)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('牌局紀錄（${stats.recentGames.length} 場）',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...sortedGames.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final summary = entry.value;
          final scoreColor = summary.score > 0 ? Colors.green : summary.score < 0 ? Colors.red : null;
          final hasName = summary.gameName != null && summary.gameName!.isNotEmpty;
          final subtitleText =
              '${summary.baseScore}/${summary.perTai} - ${summary.jiangCount}將(${summary.rounds}局) - ${dateFormat.format(summary.date)}';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: summary.rank == 1
                    ? Colors.amber.withValues(alpha: 0.25)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '#$idx',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: summary.rank == 1
                        ? Colors.amber.shade700
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Row(
                children: [
                  if (hasName) ...[
                    Text(summary.gameName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(CalculationService.formatScore(summary.score),
                        style: TextStyle(fontSize: 13, color: scoreColor)),
                  ] else
                    Text(CalculationService.formatScore(summary.score),
                        style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor)),
                ],
              ),
              subtitle: Text(subtitleText),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
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

  // --- 編輯玩家 ---

  void _showEditSheet(BuildContext context) {
    final nameController = TextEditingController(text: _currentProfile.name);
    String selectedEmoji = _currentProfile.emoji;
    final provider = context.read<GameProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '編輯玩家',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // 頭像區塊
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showAvatarOptionsSheet(context, provider);
                      },
                      child: Stack(
                        children: [
                          PlayerAvatar(profile: _currentProfile, size: 80),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showAvatarOptionsSheet(context, provider);
                      },
                      icon: const Icon(Icons.photo_camera, size: 18),
                      label: const Text('更換頭像'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Emoji 選擇
                  Row(
                    children: [
                      const Text('Emoji：', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          _showEmojiPicker(context, selectedEmoji, (emoji) {
                            setSheetState(() => selectedEmoji = emoji);
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(selectedEmoji, style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('(點擊更換)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 名稱輸入
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '玩家名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 按鈕列
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          await provider.updatePlayerProfile(
                            _currentProfile.id,
                            name: name,
                            emoji: selectedEmoji,
                          );
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _refreshProfile();
                        },
                        child: const Text('儲存'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEmojiPicker(BuildContext context, String current, void Function(String) onSelected) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('選擇圖示'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              children: AppConstants.availableEmojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    onSelected(emoji);
                    Navigator.pop(dialogContext);
                  },
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showAvatarOptionsSheet(BuildContext context, GameProvider provider) {
    final isLinked = _currentProfile.linkedAccountId != null;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 已連結帳號：優先顯示「對方頭像」選項
              if (isLinked)
                ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('顯示對方的頭像'),
                  subtitle: const Text('即時同步對方帳號設定的大頭照（連結後預設）'),
                  trailing: _currentProfile.avatarType == AvatarType.accountAvatar
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    if (sheetContext.mounted) Navigator.pop(sheetContext);

                    final existingData = await FirestoreService.loadAccountAvatarByUid(
                      _currentProfile.linkedAccountId!,
                    );

                    if (existingData != null) {
                      await provider.updatePlayerProfile(
                        _currentProfile.id,
                        avatarType: AvatarType.accountAvatar,
                      );
                      _refreshProfile();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已切換為對方帳號頭像')),
                        );
                      }
                      return;
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('對方尚未設定帳號頭像')),
                      );
                    }
                  },
                ),
              // 未連結帳號：顯示「使用帳號頭像」
              if (!isLinked)
                ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('使用帳號頭像'),
                  subtitle: const Text('套用您的帳號大頭照'),
                  trailing: _currentProfile.avatarType == AvatarType.accountAvatar
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    if (sheetContext.mounted) Navigator.pop(sheetContext);

                    final existingData = await FirestoreService.loadAccountAvatar();

                    if (existingData != null) {
                      await provider.updatePlayerProfile(
                        _currentProfile.id,
                        avatarType: AvatarType.accountAvatar,
                      );
                      _refreshProfile();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已套用帳號頭像')),
                        );
                      }
                      return;
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('尚未設定帳號頭像，請先至個人資料上傳大頭照')),
                      );
                    }
                  },
                ),
              if (isLinked) const Divider(height: 1),
              // 以下選項：自訂顯示（連結後覆蓋對方頭像，但保留連結）
              ListTile(
                leading: const Icon(Icons.emoji_emotions),
                title: const Text('顯示 Emoji'),
                subtitle: isLinked ? const Text('保留連結，顯示我設定的圖示') : null,
                trailing: _currentProfile.avatarType == AvatarType.emoji
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await provider.updatePlayerProfile(
                    _currentProfile.id,
                    avatarType: AvatarType.emoji,
                  );
                  _refreshProfile();
                },
              ),
              // Web 平台只顯示「從裝置選擇照片」，手機平台顯示「相機」和「相簿」
              if (!kIsWeb) ...[
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('拍照（相機）'),
                  subtitle: isLinked ? const Text('保留連結，顯示我設定的照片') : null,
                  onTap: () async {
                    // 重要：先 pick 圖片（必須是 onTap 中第一個 await）
                    final base64Data = await AvatarService.pickImageAsBase64(source: ImageSource.camera);

                    if (sheetContext.mounted) Navigator.pop(sheetContext);

                    if (base64Data == null) return;
                    await _handlePhotoSelectedBase64(context, provider, base64Data);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('從相簿選擇'),
                  subtitle: isLinked ? const Text('保留連結，顯示我設定的照片') : null,
                  onTap: () async {
                    // 重要：先 pick 圖片（必須是 onTap 中第一個 await）
                    final base64Data = await AvatarService.pickImageAsBase64();

                    if (sheetContext.mounted) Navigator.pop(sheetContext);

                    if (base64Data == null) return;
                    await _handlePhotoSelectedBase64(context, provider, base64Data);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('從裝置選擇照片'),
                  subtitle: isLinked ? const Text('保留連結，顯示我設定的照片') : null,
                  onTap: () async {
                    // 重要：先 pick 圖片（必須是 onTap 中第一個 await，保留 gesture context）
                    final base64Data = await AvatarService.pickImageAsBase64();

                    if (sheetContext.mounted) Navigator.pop(sheetContext);

                    if (base64Data == null) return;
                    await _handlePhotoSelectedBase64(context, provider, base64Data);
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePhotoSelectedBase64(
    BuildContext context,
    GameProvider provider,
    String base64Data,
  ) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('上傳中...')),
      );
    }

    final url = await AvatarService.uploadProfilePhotoFromBase64(_currentProfile.id, base64Data);
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上傳失敗，請重試')),
        );
      }
      return;
    }

    await provider.updatePlayerProfile(
      _currentProfile.id,
      avatarType: AvatarType.customPhoto,
      customPhotoData: url,
    );

    _refreshProfile();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('頭像已更新')),
      );
    }
  }

  Future<void> _handleAccountAvatarSelectedBase64(
    BuildContext context,
    GameProvider provider,
    String base64Data,
  ) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('上傳帳號頭像中...')),
      );
    }

    final url = await AvatarService.uploadAccountAvatarFromBase64(base64Data);
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上傳失敗，請重試')),
        );
      }
      return;
    }

    await provider.updatePlayerProfile(
      _currentProfile.id,
      avatarType: AvatarType.accountAvatar,
    );

    _refreshProfile();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('帳號頭像已上傳並套用')),
      );
    }
  }
}
