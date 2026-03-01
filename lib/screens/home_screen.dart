import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../models/game.dart';
import '../models/player_profile.dart';
import '../services/auth_service.dart';
import '../services/calculation_service.dart';
import '../widgets/animation_helpers.dart';
import 'auth_screen.dart';
import 'game_setup_screen.dart';
import 'game_play_screen.dart';
import 'game_detail_screen.dart';
import 'player_list_screen.dart';
import 'player_stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showAllGames = false; // 是否顯示全部牌局

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜尋牌局...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Consumer2<AuthService, GameProvider>(
                builder: (context, auth, gameProvider, _) {
                  final name = auth.displayName;
                  final displayText = name != null && name.isNotEmpty ? '🀄 $name' : '🀄 牌咖';
                  return GestureDetector(
                    onTap: () => _navigateToSelfStats(context, gameProvider),
                    child: Text(displayText),
                  );
                },
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? '關閉搜尋' : '搜尋牌局',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'players':
                    Navigator.push(
                      context,
                      FadeSlidePageRoute(page: const PlayerListScreen()),
                    );
                  case 'settings':
                    Navigator.push(
                      context,
                      FadeSlidePageRoute(page: const SettingsScreen()),
                    );
                  case 'logout':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('登出'),
                        content: const Text('確定要登出嗎？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('確定'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await context.read<AuthService>().logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          FadeSlidePageRoute(page: const AuthScreen()),
                          (route) => false,
                        );
                      }
                    }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'players',
                  child: Row(
                    children: [
                      Icon(Icons.people),
                      SizedBox(width: 12),
                      Text('玩家管理'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 12),
                      Text('設定'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 12),
                      Text('登出'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('載入中...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.initialize(),
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.currentGame != null) {
            return _buildContinueGameView(context, provider);
          }

          return _buildHomeView(context, provider);
        },
      ),
    );
  }

  Widget _buildContinueGameView(BuildContext context, GameProvider provider) {
    final game = provider.currentGame!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              '有進行中的牌局',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              game.currentWindDisplay,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              '已進行 ${game.rounds.length} 局',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  FadeSlidePageRoute(page: const GamePlayScreen()),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('繼續遊戲', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('結束牌局'),
                    content: const Text('確定要結束當前牌局嗎？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('確定'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await provider.finishGame();
                }
              },
              child: const Text('結束牌局'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView(BuildContext context, GameProvider provider) {
    final allGames = _searchQuery.isEmpty
        ? provider.gameHistory
        : provider.searchGames(_searchQuery);

    // 計算最近一起玩的玩家
    final recentPlayers = _getRecentPlayers(provider);

    // 搜尋模式或展開全部時顯示完整列表
    if (_isSearching || _showAllGames) {
      return Column(
        children: [
          // 搜尋模式下不顯示新局按鈕；展開全部模式下顯示返回按鈕
          if (_showAllGames && !_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _showAllGames = false),
                  ),
                  const Text(
                    '全部牌局',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${allGames.length} 場',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '搜尋結果 (${allGames.length})',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Expanded(
            child: allGames.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSearching ? Icons.search_off : Icons.history,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearching ? '找不到符合的牌局' : '尚無牌局紀錄',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allGames.length,
                    itemBuilder: (context, index) {
                      final game = allGames[index];
                      return _buildGameHistoryCard(context, game, provider);
                    },
                  ),
          ),
        ],
      );
    }

    // 首頁正常顯示：新局按鈕 + 最近 3 筆牌局 + 最近一起玩
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 開始新局按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  FadeSlidePageRoute(page: const GameSetupScreen()),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 28),
              label: const Text('開始新局', style: TextStyle(fontSize: 22)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 最近牌局（只顯示 3 筆）
          if (allGames.isNotEmpty) ...[
            const Text(
              '最近牌局',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...allGames.take(3).map((game) => _buildGameHistoryCard(context, game, provider)),
            if (allGames.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAllGames = true),
                  icon: const Icon(Icons.expand_more),
                  label: Text('查看全部 (${allGames.length} 場)'),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // 最近一起玩
          if (recentPlayers.isNotEmpty) ...[
            const Text(
              '最近一起玩',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recentPlayers.take(3).map((profile) => _buildRecentPlayerCard(context, profile)),
          ],

          // 若沒有任何記錄
          if (allGames.isEmpty && recentPlayers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '尚無牌局紀錄',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '點擊「開始新局」開始記錄',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 取得最近一起玩的玩家（排除自己，依最後一起玩時間排序）
  List<PlayerProfile> _getRecentPlayers(GameProvider provider) {
    final selfIds = provider.selfProfileIds;
    final profiles = provider.playerProfiles
        .where((p) => !selfIds.contains(p.id))
        .toList();
    // 已經按 lastPlayedAt 排序，直接取前 3 個
    return profiles.take(3).toList();
  }

  /// 建立最近一起玩的玩家卡片
  Widget _buildRecentPlayerCard(BuildContext context, PlayerProfile profile) {
    final dateFormat = DateFormat('MM/dd');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(profile.emoji, style: const TextStyle(fontSize: 32)),
        title: Text(profile.name, style: const TextStyle(fontSize: 16)),
        subtitle: Text('最後遊玩：${dateFormat.format(profile.lastPlayedAt)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            FadeSlidePageRoute(page: PlayerStatsScreen(profile: profile)),
          );
        },
      ),
    );
  }

  /// 點擊 AppBar 名稱進入自己的統計頁
  void _navigateToSelfStats(BuildContext context, GameProvider provider) {
    final selfProfileId = provider.selfProfileId;
    if (selfProfileId == null) {
      // 嘗試用 isSelf 找
      final selfProfile = provider.playerProfiles.where((p) => p.isSelf).firstOrNull;
      if (selfProfile != null) {
        Navigator.push(
          context,
          FadeSlidePageRoute(page: PlayerStatsScreen(profile: selfProfile)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先在玩家管理中設定你的 Profile')),
        );
      }
      return;
    }

    final profile = provider.playerProfiles.where((p) => p.id == selfProfileId).firstOrNull;
    if (profile != null) {
      Navigator.push(
        context,
        FadeSlidePageRoute(page: PlayerStatsScreen(profile: profile)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到你的 Profile，請在玩家管理中重新設定')),
      );
    }
  }

  Widget _buildGameHistoryCard(BuildContext context, Game game, GameProvider provider) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final scores = game.currentScores;
    final myProfileIds = provider.selfProfileIds;

    // 找出最高分玩家
    String topPlayerId = game.players[0].id;
    int topScore = scores[topPlayerId] ?? 0;
    for (var player in game.players) {
      final score = scores[player.id] ?? 0;
      if (score > topScore) {
        topScore = score;
        topPlayerId = player.id;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            FadeSlidePageRoute(page: GameDetailScreen(game: game)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (game.name != null && game.name!.isNotEmpty)
                          Text(
                            game.name!,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          dateFormat.format(game.createdAt),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: game.status == GameStatus.finished
                              ? Colors.grey
                              : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          game.status == GameStatus.finished ? '已結束' : '進行中',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') {
                            _showRenameDialog(context, game, provider);
                          } else if (value == 'delete') {
                            _showDeleteDialog(context, game, provider);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('重新命名'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('刪除', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${game.settings.baseScore}/${game.settings.perTai} - ${game.jiangs.length}將(${game.rounds.length}局)',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              // 玩家分數列表
              ...game.players.map((player) {
                final score = scores[player.id] ?? 0;
                final isTop = player.id == topPlayerId && topScore > 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(player.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: myProfileIds.contains(player.userId) ? FontWeight.bold : FontWeight.normal,
                            color: myProfileIds.contains(player.userId)
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        CalculationService.formatScore(score),
                        style: TextStyle(
                          fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                          fontSize: 18,
                          color: score > 0
                              ? Colors.green
                              : score < 0
                                  ? Colors.red
                                  : null,
                        ),
                      ),
                      if (isTop) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Game game, GameProvider provider) {
    final controller = TextEditingController(text: game.name ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新命名牌局'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '輸入牌局名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.renameGame(game.id, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Game game, GameProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除牌局'),
        content: const Text('確定要刪除這場牌局嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteGameFromHistory(game.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
