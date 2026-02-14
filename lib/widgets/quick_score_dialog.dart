import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../services/calculation_service.dart';

/// 快速記分對話框
class QuickScoreDialog extends StatefulWidget {
  final Game game;
  final Player selectedPlayer;

  const QuickScoreDialog({
    super.key,
    required this.game,
    required this.selectedPlayer,
  });

  @override
  State<QuickScoreDialog> createState() => _QuickScoreDialogState();
}

class _QuickScoreDialogState extends State<QuickScoreDialog> {
  // 記分類型
  String _scoreType = 'win'; // win, selfDraw, falseWin
  
  // 台數
  int _tai = 0;
  
  // 放槍者（胡牌時需要）
  Player? _loser;

  // 快速台數選項
  final List<Map<String, dynamic>> _quickTaiOptions = [
    {'label': '屁糊', 'tai': 0},
    {'label': '自摸台', 'tai': 1},
    {'label': '門清一摸三', 'tai': 3},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題
              Row(
                children: [
                  Text(
                    widget.selectedPlayer.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.selectedPlayer.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const Divider(),
              const SizedBox(height: 16),
              
              // 記分類型選擇
              _buildScoreTypeSelection(),
              
              const SizedBox(height: 24),
              
              // 台數選擇
              _buildTaiSelection(),
              
              const SizedBox(height: 24),
              
              // 放槍者選擇（胡牌時顯示）
              if (_scoreType == 'win') ...[
                _buildLoserSelection(),
                const SizedBox(height: 24),
              ],
              
              // 計算預覽
              if (_canCalculate()) ...[
                _buildPreview(provider),
                const SizedBox(height: 24),
              ],
              
              // 確認按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canCalculate()
                      ? () => _submit(provider)
                      : null,
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
      ),
    );
  }

  Widget _buildScoreTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '記分類型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('胡牌'),
                selected: _scoreType == 'win',
                onSelected: (selected) {
                  setState(() {
                    _scoreType = 'win';
                    _loser = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('自摸'),
                selected: _scoreType == 'selfDraw',
                onSelected: (selected) {
                  setState(() {
                    _scoreType = 'selfDraw';
                    _loser = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('詐胡'),
                selected: _scoreType == 'falseWin',
                onSelected: (selected) {
                  setState(() {
                    _scoreType = 'falseWin';
                    _loser = null;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaiSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '台數',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // 快速台數按鈕
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickTaiOptions.map((option) {
            final label = option['label'] as String;
            final tai = option['tai'] as int;
            final isSelected = _tai == tai;
            
            return ChoiceChip(
              label: Text('$label ($tai台)'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _tai = tai;
                });
              },
            );
          }).toList(),
        ),
        
        const SizedBox(height: 12),
        
        // 台數選單 (0-99)
        DropdownButtonFormField<int>(
          initialValue: _tai,
          decoration: const InputDecoration(
            labelText: '選擇台數',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: List.generate(100, (index) {
            return DropdownMenuItem(
              value: index,
              child: Text('$index 台'),
            );
          }),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _tai = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildLoserSelection() {
    final availablePlayers = widget.game.players
        .where((p) => p.id != widget.selectedPlayer.id)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '誰放槍？',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availablePlayers.map((player) {
            final isSelected = _loser == player;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(player.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Text(player.name),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _loser = selected ? player : null;
                });
              },
              selectedColor: Colors.red.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreview(GameProvider provider) {
    final settings = widget.game.settings;
    final dealer = widget.game.dealer;
    final consecutiveWins = widget.game.consecutiveWins;
    String previewText = '';
    
    if (_scoreType == 'selfDraw') {
      final isDealer = (widget.selectedPlayer.id == dealer.id);
      previewText = CalculationService.getScorePreview(
        settings: settings,
        tai: _tai,
        flowers: 0,
        isSelfDraw: true,
        isDealer: isDealer,
        consecutiveWins: consecutiveWins,
      );
    } else if (_scoreType == 'win' && _loser != null) {
      final isDealerInvolved = (widget.selectedPlayer.id == dealer.id || _loser!.id == dealer.id);
      final score = settings.calculateScore(
        _tai,
        isDealer: isDealerInvolved,
        consecutiveWins: consecutiveWins,
      );
      previewText = CalculationService.getScorePreview(
        settings: settings,
        tai: _tai,
        flowers: 0,
        isSelfDraw: false,
        isDealer: isDealerInvolved,
        consecutiveWins: consecutiveWins,
      );
      previewText = '$previewText\n${widget.selectedPlayer.name} +$score\n'
                    '${_loser!.name} -$score';
    } else if (_scoreType == 'falseWin') {
      final penalty = settings.calculateScore(settings.falseWinTai);
      if (settings.falseWinPayAll) {
        previewText = '詐胡賠三家\n'
                     '${widget.selectedPlayer.name} -${penalty * 3}\n'
                     '其他各 +$penalty';
      } else {
        previewText = '詐胡賠莊家\n'
                     '${widget.selectedPlayer.name} -$penalty';
      }
    }
    
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                '計算預覽',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            previewText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  bool _canCalculate() {
    if (_scoreType == 'win' && _loser == null) return false;
    if (_scoreType == 'falseWin') return true;
    return true;
  }

  Future<void> _submit(GameProvider provider) async {
    switch (_scoreType) {
      case 'win':
        if (_loser != null) {
          await provider.recordWin(
            winnerId: widget.selectedPlayer.id,
            loserId: _loser!.id,
            tai: _tai,
            flowers: 0,
          );
        }
        break;
        
      case 'selfDraw':
        await provider.recordSelfDraw(
          winnerId: widget.selectedPlayer.id,
          tai: _tai,
          flowers: 0,
        );
        break;
        
      case 'falseWin':
        await provider.recordFalseWin(
          falserId: widget.selectedPlayer.id,
        );
        break;
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
