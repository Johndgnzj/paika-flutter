import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../models/game.dart';
import '../services/calculation_service.dart';
import 'game_setup_screen.dart';
import 'game_play_screen.dart';
import 'game_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🀄 麻將記分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 打開設定頁面
            },
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          // 如果有進行中的遊戲，顯示繼續按鈕
          if (provider.currentGame != null) {
            return _buildContinueGameView(context, provider);
          }

          // 否則顯示新局和歷史紀錄
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
              '${game.currentWindDisplay} 局',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '已進行 ${game.rounds.length} 局',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GamePlayScreen(),
                  ),
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
    return Column(
      children: [
        // 開始新局按鈕
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameSetupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 28),
              label: const Text('開始新局', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
        ),

        // 歷史紀錄
        if (provider.gameHistory.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '最近牌局',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: provider.gameHistory.length,
              itemBuilder: (context, index) {
                final game = provider.gameHistory[index];
                return _buildGameHistoryCard(context, game);
              },
            ),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '尚無牌局紀錄',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGameHistoryCard(BuildContext context, Game game) {
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
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(game: game),
            ),
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
                  Text(
                    dateFormat.format(game.createdAt),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '底${game.settings.baseScore} / ${game.rounds.length}局',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                      Text(player.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(player.name)),
                      Text(
                        CalculationService.formatScore(score),
                        style: TextStyle(
                          fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
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
}
