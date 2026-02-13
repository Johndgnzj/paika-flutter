import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../models/game.dart';
import '../services/auth_service.dart';
import '../services/calculation_service.dart';
import '../widgets/animation_helpers.dart';
import 'auth_screen.dart';
import 'game_setup_screen.dart';
import 'game_play_screen.dart';
import 'game_detail_screen.dart';
import 'player_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

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
            : Consumer<AuthService>(
                builder: (context, auth, _) {
                  final name = auth.currentAccount?.name;
                  return Text(name != null ? '🀄 $name' : '🀄 牌咖');
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
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: '玩家管理',
              onPressed: () {
                Navigator.push(
                  context,
                  FadeSlidePageRoute(page: const PlayerListScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  FadeSlidePageRoute(page: const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '登出',
              onPressed: () async {
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
              },
            ),
          ],
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
    final games = _searchQuery.isEmpty
        ? provider.gameHistory
        : provider.searchGames(_searchQuery);

    return Column(
      children: [
        // 開始新局按鈕
        if (!_isSearching)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
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
          ),

        // 歷史紀錄
        if (games.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isSearching ? '搜尋結果 (${games.length})' : '最近牌局',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return _buildGameHistoryCard(context, game, provider);
              },
            ),
          ),
        ] else ...[
          Expanded(
            child: Center(
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
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGameHistoryCard(BuildContext context, Game game, GameProvider provider) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final scores = game.currentScores;

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
                '底${game.settings.baseScore} / ${game.rounds.length}局',
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
                      Expanded(child: Text(player.name, style: const TextStyle(fontSize: 16))),
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
