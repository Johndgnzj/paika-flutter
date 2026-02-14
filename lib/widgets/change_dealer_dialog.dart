import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../providers/game_provider.dart';
import '../utils/constants.dart';

/// 更換莊家對話框
class ChangeDealerDialog extends StatefulWidget {
  final Game game;

  const ChangeDealerDialog({super.key, required this.game});

  @override
  State<ChangeDealerDialog> createState() => _ChangeDealerDialogState();
}

class _ChangeDealerDialogState extends State<ChangeDealerDialog> {
  late int _selectedDealerIndex;
  bool _resetConsecutiveWins = true;
  bool _recalculateWind = false;

  @override
  void initState() {
    super.initState();
    _selectedDealerIndex = widget.game.dealerSeat;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '指定莊家',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const Divider(),
            const SizedBox(height: 16),
            
            // 選擇莊家
            const Text(
              '選擇莊家',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            ...List.generate(4, (index) {
              final player = widget.game.players[index];
              final windName = AppConstants.windNames[index];
              final isSelected = _selectedDealerIndex == index;
              final isCurrentDealer = widget.game.dealerSeat == index;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDealerIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              windName,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          player.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            player.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isCurrentDealer) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '當前莊',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 24),
            
            // 設定選項
            const Text(
              '設定',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            CheckboxListTile(
              title: const Text('重置連莊數'),
              subtitle: const Text('將連莊數歸零'),
              value: _resetConsecutiveWins,
              onChanged: (value) {
                setState(() {
                  _resetConsecutiveWins = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            CheckboxListTile(
              title: const Text('重新計算圈風'),
              subtitle: const Text('根據新莊家調整圈風'),
              value: _recalculateWind,
              onChanged: (value) {
                setState(() {
                  _recalculateWind = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 24),
            
            // 確認按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await provider.setDealer(
                    dealerSeat: _selectedDealerIndex,
                    resetConsecutiveWins: _resetConsecutiveWins,
                    recalculateWind: _recalculateWind,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '✓ 確認',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
