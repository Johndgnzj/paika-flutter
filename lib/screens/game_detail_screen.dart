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
          
          // 每局詳情
          ...game.rounds.asMap().entries.map((entry) {
            final index = entry.key;
            final round = entry.value;
            return _buildRoundCard(index + 1, round);
          }),
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
            _buildInfoRow('上限', '${game.settings.maxTai} 台'),
            _buildInfoRow('總局數', '${game.rounds.length} 局'),
            _buildInfoRow('狀態', game.status == GameStatus.finished ? '已結束' : '進行中'),
            _buildInfoRow(
              '結束於',
              game.currentWindDisplay,
            ),
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
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRankingCard(Map<String, int> scores) {
    // 排序玩家
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
              '🏆 最終排名',
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
                  color: rank == 1
                      ? Colors.amber.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rank == 1
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    // 排名
                    SizedBox(
                      width: 30,
                      child: Text(
                        _getRankEmoji(rank),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // 玩家
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
                    
                    // 分數
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

  Widget _buildRoundCard(int roundNumber, Round round) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoundColor(round),
          child: Text(
            '$roundNumber',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${round.windDisplay}局 - ${_getRoundTypeText(round)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_getRoundSummary(round)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 詳細資訊
                if (round.winnerId != null) ...[
                  _buildDetailRow('勝者', _getPlayerName(round.winnerId!)),
                  if (round.loserId != null)
                    _buildDetailRow('放槍', _getPlayerName(round.loserId!)),
                  _buildDetailRow('台數', '${round.tai} 台'),
                  if (round.flowers > 0)
                    _buildDetailRow('花牌', '${round.flowers} 台'),
                  _buildDetailRow('總台數', '${round.totalTai} 台'),
                ],
                
                if (round.type == RoundType.multiWin) ...[
                  _buildDetailRow(
                    '贏家',
                    round.winnerIds.map(_getPlayerName).join(', '),
                  ),
                  if (round.loserId != null)
                    _buildDetailRow('放槍', _getPlayerName(round.loserId!)),
                ],
                
                if (round.type == RoundType.falseWin) ...[
                  _buildDetailRow('詐胡者', _getPlayerName(round.loserId!)),
                  _buildDetailRow('賠付', '${round.tai} 台'),
                ],
                
                if (round.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '備註: ${round.notes}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                
                const Divider(),
                
                // 分數變化
                const Text(
                  '分數變化',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...game.players.map((player) {
                  final change = round.scoreChanges[player.id] ?? 0;
                  if (change == 0) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(player.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(player.name)),
                        Text(
                          CalculationService.formatScore(change),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: change > 0
                                ? Colors.green
                                : change < 0
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
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
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

  String _getRoundSummary(Round round) {
    switch (round.type) {
      case RoundType.win:
        return '${_getPlayerName(round.winnerId!)} 胡 ${round.totalTai} 台';
      case RoundType.selfDraw:
        return '${_getPlayerName(round.winnerId!)} 自摸 ${round.totalTai} 台';
      case RoundType.falseWin:
        return '${_getPlayerName(round.loserId!)} 詐胡';
      case RoundType.multiWin:
        return '${round.winnerIds.length} 人胡牌';
      case RoundType.draw:
        return '流局';
    }
  }

  String _getPlayerName(String playerId) {
    try {
      return game.players.firstWhere((p) => p.id == playerId).name;
    } catch (e) {
      return '未知';
    }
  }

  void _shareGame(BuildContext context) {
    // TODO: 實作分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能開發中')),
    );
  }
}
