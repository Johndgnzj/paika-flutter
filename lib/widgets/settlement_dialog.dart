import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../services/calculation_service.dart';
import '../services/settlement_service.dart';
import 'player_avatar.dart';

/// 結算對話框：依各家淨輸贏算出「誰付誰多少錢」
///
/// 計算規則見 [SettlementService.compute]：以貪婪法把最大的贏家與最大的輸家
/// 配對，讓一位贏家的錢盡量由同一位輸家支付。
class SettlementDialog extends StatelessWidget {
  final Game game;

  const SettlementDialog({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final scores = game.currentScores;
    final transfers = SettlementService.compute(scores);

    Player? playerById(String id) {
      try {
        return game.players.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    }

    // 依輸家（付款人）分組，保留貪婪產生的順序
    final byPayer = <String, List<SettlementTransfer>>{};
    for (final t in transfers) {
      byPayer.putIfAbsent(t.fromId, () => []).add(t);
    }

    return AlertDialog(
      title: const Text('💰 結算'),
      content: SizedBox(
        width: double.maxFinite,
        child: transfers.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('目前沒有輸贏差額，無需結算'),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNetSummary(context, scores, playerById),
                    const Divider(height: 24),
                    ...byPayer.entries.map(
                      (entry) => _buildPayerBlock(
                        context,
                        playerById(entry.key),
                        entry.value,
                        playerById,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }

  /// 各家淨輸贏摘要
  Widget _buildNetSummary(
    BuildContext context,
    Map<String, int> scores,
    Player? Function(String) playerById,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: game.players.map((p) {
        final net = scores[p.id] ?? 0;
        final color = net > 0
            ? Colors.green
            : net < 0
                ? Colors.red
                : Colors.grey;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerGameAvatar(player: p, size: 24),
            const SizedBox(width: 4),
            Text(p.name, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              CalculationService.formatScore(net),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 單一輸家的付款明細
  Widget _buildPayerBlock(
    BuildContext context,
    Player? payer,
    List<SettlementTransfer> transfers,
    Player? Function(String) playerById,
  ) {
    final total = transfers.fold<int>(0, (sum, t) => sum + t.amount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (payer != null) PlayerGameAvatar(player: payer, size: 28),
              const SizedBox(width: 8),
              Text(
                '${payer?.name ?? '?'} 應付 $total',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...transfers.map((t) {
            final to = playerById(t.toId);
            return Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  if (to != null) PlayerGameAvatar(player: to, size: 24),
                  const SizedBox(width: 6),
                  Expanded(child: Text(to?.name ?? '?')),
                  Text(
                    '${t.amount}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
