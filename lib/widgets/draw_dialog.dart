import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../providers/game_provider.dart';
import 'package:uuid/uuid.dart';

/// 流局對話框 - 簡化版，直接確認即可
class DrawDialog extends StatelessWidget {
  final Game game;

  const DrawDialog({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🌊 流局'),
      content: const Text('確定要流局嗎？\n莊家將會連莊。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _recordDraw(context);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('確認流局'),
        ),
      ],
    );
  }

  Future<void> _recordDraw(BuildContext context) async {
    final provider = context.read<GameProvider>();

    // 流局不計分
    final scoreChanges = <String, int>{};
    for (var player in game.players) {
      scoreChanges[player.id] = 0;
    }

    const uuid = Uuid();
    final round = Round(
      id: uuid.v4(),
      timestamp: DateTime.now(),
      type: RoundType.draw,
      tai: 0,
      scoreChanges: scoreChanges,
      dealerPassCount: game.dealerPassCount,
      dealerSeat: game.dealerSeat,
      consecutiveWins: game.consecutiveWins,
      notes: '流局',
    );

    await provider.recordCustomRound(round);
  }
}
