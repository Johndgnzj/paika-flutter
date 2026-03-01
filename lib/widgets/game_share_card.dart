import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../services/calculation_service.dart';

/// 牌局分享卡片 Widget（用於截圖分享）
class GameShareCard extends StatelessWidget {
  final Game game;

  const GameShareCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final scores = game.currentScores;
    final sortedPlayers = List.from(game.players)
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
    final stats = _calculateStats();
    final dateStr = DateFormat('yyyy/MM/dd').format(game.createdAt);

    return Container(
      width: 420,
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(dateStr),
          const SizedBox(height: 20),
          _buildRankingSection(sortedPlayers, scores),
          const SizedBox(height: 16),
          _buildStatsSection(sortedPlayers, stats),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(String dateStr) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🀄', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text(
              (game.name != null && game.name!.isNotEmpty) ? game.name! : 'Paika 麻將',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$dateStr  ·  ${game.rounds.length} 局  ·  底分 ${game.settings.baseScore} / 台 ${game.settings.perTai}',
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRankingSection(List sortedPlayers, Map<String, int> scores) {
    const rankEmojis = ['🥇', '🥈', '🥉', '4️⃣'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最終排名', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 12),
          ...sortedPlayers.asMap().entries.map((entry) {
            final rank = entry.key;
            final player = entry.value;
            final score = scores[player.id] ?? 0;
            final isWinner = rank == 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isWinner ? const Color(0xFFFFD700).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWinner ? const Color(0xFFFFD700).withValues(alpha: 0.5) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(rankEmojis[rank < 4 ? rank : 3], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(player.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(player.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  Text(
                    CalculationService.formatScore(score),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: score > 0 ? const Color(0xFF4CAF50) : score < 0 ? const Color(0xFFEF5350) : Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatsSection(List sortedPlayers, Map<String, Map<String, int>> stats) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('數據統計', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(flex: 2, child: SizedBox()),
            _headerCell('胡牌'),
            _headerCell('自摸'),
            _headerCell('放槍'),
          ]),
          const Divider(color: Colors.white24, height: 12),
          ...sortedPlayers.map((player) {
            final s = stats[player.id] ?? {'wins': 0, 'selfDraws': 0, 'losses': 0};
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Row(children: [
                    Text(player.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(player.name, style: const TextStyle(fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis)),
                  ])),
                  _statCell('${s['wins']}', const Color(0xFF4CAF50)),
                  _statCell('${s['selfDraws']}', const Color(0xFF2196F3)),
                  _statCell('${s['losses']}', const Color(0xFFEF5350)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(String label) => Expanded(
    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white54)),
  );

  Widget _statCell(String value, Color color) => Expanded(
    child: Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
  );

  Widget _buildFooter() => Text(
    'Paika · paika-13250.web.app',
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
  );

  Map<String, Map<String, int>> _calculateStats() {
    final stats = <String, Map<String, int>>{};
    for (var player in game.players) {
      stats[player.id] = {'wins': 0, 'selfDraws': 0, 'losses': 0};
    }
    for (var round in game.rounds) {
      switch (round.type) {
        case RoundType.win:
          if (round.winnerId != null) stats[round.winnerId]!['wins'] = stats[round.winnerId]!['wins']! + 1;
          if (round.loserId != null) stats[round.loserId]!['losses'] = stats[round.loserId]!['losses']! + 1;
          break;
        case RoundType.selfDraw:
          if (round.winnerId != null) {
            stats[round.winnerId]!['wins'] = stats[round.winnerId]!['wins']! + 1;
            stats[round.winnerId]!['selfDraws'] = stats[round.winnerId]!['selfDraws']! + 1;
          }
          break;
        case RoundType.multiWin:
          for (var wid in round.winnerIds) {
            stats[wid]!['wins'] = stats[wid]!['wins']! + 1;
          }
          if (round.loserId != null) stats[round.loserId]!['losses'] = stats[round.loserId]!['losses']! + 1;
          break;
        default:
          break;
      }
    }
    return stats;
  }
}
