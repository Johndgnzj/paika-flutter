import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../services/calculation_service.dart';
import '../utils/constants.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<GameProvider>(
          builder: (context, provider, _) {
            final game = provider.currentGame;
            if (game == null) return const Text('遊戲');
            
            return Text(
              '${game.currentWindDisplay}局 ${game.consecutiveWins > 0 ? "連${game.consecutiveWins}" : ""}',
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino),
            onPressed: _showDiceDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'swap':
                  _showSwapDialog();
                  break;
                case 'undo':
                  _undoLastRound();
                  break;
                case 'finish':
                  _finishGame();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'swap',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz),
                    SizedBox(width: 8),
                    Text('換位置'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'undo',
                child: Row(
                  children: [
                    Icon(Icons.undo),
                    SizedBox(width: 8),
                    Text('還原上局'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'finish',
                child: Row(
                  children: [
                    Icon(Icons.stop),
                    SizedBox(width: 8),
                    Text('結束牌局'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          final game = provider.currentGame;
          if (game == null) {
            return const Center(child: Text('沒有進行中的遊戲'));
          }

          return _buildMahjongTable(game);
        },
      ),
    );
  }

  Widget _buildMahjongTable(Game game) {
    final scores = game.currentScores;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 麻將桌背景
            Center(
              child: Container(
                width: constraints.maxWidth * 0.9,
                height: constraints.maxHeight * 0.7,
                decoration: BoxDecoration(
                  color: AppConstants.mahjongGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppConstants.mahjongGreen,
                    width: 4,
                  ),
                ),
              ),
            ),
            
            // 四個玩家位置
            ..._buildPlayerPositions(game, scores, constraints),
          ],
        );
      },
    );
  }

  List<Widget> _buildPlayerPositions(
    Game game,
    Map<String, int> scores,
    BoxConstraints constraints,
  ) {
    final players = game.players;
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;
    final radius = math.min(constraints.maxWidth, constraints.maxHeight) * 0.35;

    return List.generate(4, (index) {
      final player = players[index];
      final score = scores[player.id] ?? 0;
      final isDealer = game.dealerIndex == index;

      // 計算位置（上下左右）
      double left, top;
      switch (index) {
        case 0: // 東（右）
          left = centerX + radius - 60;
          top = centerY - 60;
          break;
        case 1: // 南（下）
          left = centerX - 60;
          top = centerY + radius - 60;
          break;
        case 2: // 西（左）
          left = centerX - radius - 60;
          top = centerY - 60;
          break;
        case 3: // 北（上）
          left = centerX - 60;
          top = centerY - radius - 60;
          break;
        default:
          left = centerX;
          top = centerY;
      }

      return Positioned(
        left: left,
        top: top,
        child: _buildPlayerCard(
          player: player,
          score: score,
          windIndex: index,
          isDealer: isDealer,
          consecutiveWins: isDealer ? game.consecutiveWins : 0,
          onTap: () => _showPlayerActionDialog(player),
        ),
      );
    });
  }

  Widget _buildPlayerCard({
    required Player player,
    required int score,
    required int windIndex,
    required bool isDealer,
    required int consecutiveWins,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.playerCardBorderRadius),
      child: Card(
        elevation: 4,
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 風位
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppConstants.windNames[windIndex],
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (isDealer) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.circle, color: AppConstants.dealerColor, size: 12),
                    if (consecutiveWins > 0)
                      Text(
                        '連$consecutiveWins',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppConstants.dealerColor,
                        ),
                      ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Emoji
              Text(
                player.emoji,
                style: const TextStyle(fontSize: 36),
              ),
              
              const SizedBox(height: 4),
              
              // 名稱
              Text(
                player.name,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // 分數
              Text(
                CalculationService.formatScore(score),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: score > 0
                      ? AppConstants.winColor
                      : score < 0
                          ? AppConstants.loseColor
                          : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlayerActionDialog(Player player) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('${player.emoji} ${player.name}'),
                subtitle: const Text('選擇操作'),
                dense: true,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: const Text('胡牌（放槍）'),
                onTap: () {
                  Navigator.pop(context);
                  _showWinDialog(player);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.green),
                title: const Text('自摸'),
                onTap: () {
                  Navigator.pop(context);
                  _showSelfDrawDialog(player);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text('詐胡'),
                onTap: () {
                  Navigator.pop(context);
                  _showFalseWinDialog(player);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showWinDialog(Player winner) {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame!;
    
    showDialog(
      context: context,
      builder: (context) => _WinDialog(game: game, winner: winner),
    );
  }

  void _showSelfDrawDialog(Player winner) {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame!;
    
    showDialog(
      context: context,
      builder: (context) => _SelfDrawDialog(game: game, winner: winner),
    );
  }

  void _showFalseWinDialog(Player falser) {
    final provider = context.read<GameProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${falser.emoji} ${falser.name} 詐胡'),
        content: Text(
          '詐胡將賠付 ${provider.currentGame!.settings.falseWinTai} 台',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.recordFalseWin(falserId: falser.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  void _showDiceDialog() {
    final random = math.Random();
    final dice1 = random.nextInt(6) + 1;
    final dice2 = random.nextInt(6) + 1;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎲 電子骰子'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDice(dice1),
                const SizedBox(width: 24),
                _buildDice(dice2),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '合計：${dice1 + dice2}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDiceDialog(); // 再擲一次
            },
            child: const Text('再擲一次'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Widget _buildDice(int value) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  void _showSwapDialog() {
    // TODO: 實作換位置功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('換位置功能開發中')),
    );
  }

  Future<void> _undoLastRound() async {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null || game.rounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可還原的紀錄')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認還原'),
        content: const Text('確定要還原上一局嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.undoLastRound();
    }
  }

  Future<void> _finishGame() async {
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<GameProvider>().finishGame();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// 胡牌對話框
class _WinDialog extends StatefulWidget {
  final Game game;
  final Player winner;

  const _WinDialog({required this.game, required this.winner});

  @override
  State<_WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<_WinDialog> {
  Player? _loser;
  int _tai = 4;
  int _flowers = 0;

  @override
  Widget build(BuildContext context) {
    final losers = widget.game.players
        .where((p) => p.id != widget.winner.id)
        .toList();

    final provider = context.read<GameProvider>();
    final settings = widget.game.settings;
    
    return AlertDialog(
      title: Text('${widget.winner.emoji} ${widget.winner.name} 胡牌'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('誰放槍？', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: losers.map((player) {
                return ChoiceChip(
                  label: Text('${player.emoji} ${player.name}'),
                  selected: _loser == player,
                  onSelected: (selected) {
                    setState(() {
                      _loser = selected ? player : null;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            const Text('台數：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.commonTai.map((tai) {
                return ChoiceChip(
                  label: Text('$tai台'),
                  selected: _tai == tai,
                  onSelected: (selected) {
                    setState(() {
                      _tai = tai;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '自訂台數',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _tai = parsed;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花牌',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: _flowers.toString()),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _flowers = parsed;
                  });
                }
              },
            ),
            
            if (_loser != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  CalculationService.getScorePreview(
                    settings: settings,
                    tai: _tai,
                    flowers: _flowers,
                    isSelfDraw: false,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _loser == null ? null : () async {
            await provider.recordWin(
              winnerId: widget.winner.id,
              loserId: _loser!.id,
              tai: _tai,
              flowers: _flowers,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}

// 自摸對話框
class _SelfDrawDialog extends StatefulWidget {
  final Game game;
  final Player winner;

  const _SelfDrawDialog({required this.game, required this.winner});

  @override
  State<_SelfDrawDialog> createState() => _SelfDrawDialogState();
}

class _SelfDrawDialogState extends State<_SelfDrawDialog> {
  int _tai = 4;
  int _flowers = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    final settings = widget.game.settings;
    
    return AlertDialog(
      title: Text('${widget.winner.emoji} ${widget.winner.name} 自摸'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('台數：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.commonTai.map((tai) {
                return ChoiceChip(
                  label: Text('$tai台'),
                  selected: _tai == tai,
                  onSelected: (selected) {
                    setState(() {
                      _tai = tai;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '自訂台數',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _tai = parsed;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花牌',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: _flowers.toString()),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _flowers = parsed;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                CalculationService.getScorePreview(
                  settings: settings,
                  tai: _tai,
                  flowers: _flowers,
                  isSelfDraw: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            await provider.recordSelfDraw(
              winnerId: widget.winner.id,
              tai: _tai,
              flowers: _flowers,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}
