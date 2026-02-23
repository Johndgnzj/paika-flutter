import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/hand_pattern.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../services/calculation_service.dart';

/// 一炮多響對話框
class MultiWinDialog extends StatefulWidget {
  final Game game;

  const MultiWinDialog({super.key, required this.game});

  @override
  State<MultiWinDialog> createState() => _MultiWinDialogState();
}

class _MultiWinDialogState extends State<MultiWinDialog> {
  // 選中的放槍者
  Player? _loser;
  
  // 選中的贏家列表
  final Set<String> _selectedWinners = {};
  
  // 每個贏家的台數
  final Map<String, int> _taiMap = {};
  
  // 每個贏家的花牌
  final Map<String, int> _flowerMap = {};

  // 每個贏家的牌型（winnerId → Set<patternId>）
  final Map<String, Set<String>> _winnerPatternIds = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題
              Row(
                children: [
                  const Icon(Icons.whatshot, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    '💥 一炮多響',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
              
              // 步驟 1：選擇放槍者
              _buildStep1SelectLoser(),
              
              const SizedBox(height: 24),
              
              // 步驟 2：選擇贏家
              if (_loser != null) ...[
                _buildStep2SelectWinners(),
                const SizedBox(height: 24),
              ],
              
              // 步驟 3：輸入台數
              if (_selectedWinners.isNotEmpty) ...[
                _buildStep3InputScores(),
                const SizedBox(height: 24),
              ],
              
              // 預覽計算結果
              if (_canCalculate()) ...[
                _buildPreview(),
                const SizedBox(height: 24),
              ],
              
              // 操作按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _canCalculate()
                        ? () async {
                            await provider.recordMultiWin(
                              winnerIds: _selectedWinners.toList(),
                              loserId: _loser!.id,
                              taiMap: _taiMap,
                              flowerMap: _flowerMap,
                              winnerHandPatterns: _winnerPatternIds.map(
                                (k, v) => MapEntry(k, v.toList()),
                              ),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        : null,
                    child: const Text('✓ 確認'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1SelectLoser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1️⃣ 誰放槍？',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.game.players.map((player) {
            final isSelected = _loser == player;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(player.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Text(player.name),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _loser = selected ? player : null;
                  // 清除如果選了放槍者又選為贏家
                  if (_loser != null) {
                    _selectedWinners.remove(_loser!.id);
                  }
                });
              },
              selectedColor: Colors.red.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep2SelectWinners() {
    final availablePlayers = widget.game.players
        .where((p) => p.id != _loser!.id)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2️⃣ 誰胡牌了？（可多選）',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availablePlayers.map((player) {
            final isSelected = _selectedWinners.contains(player.id);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(player.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Text(player.name),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check, size: 16, color: Colors.green),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWinners.add(player.id);
                    // 初始化預設值
                    _taiMap[player.id] = 0;
                    _flowerMap[player.id] = 0;
                    _winnerPatternIds[player.id] = {};
                  } else {
                    _selectedWinners.remove(player.id);
                    _taiMap.remove(player.id);
                    _flowerMap.remove(player.id);
                    _winnerPatternIds.remove(player.id);
                  }
                });
              },
              selectedColor: Colors.green.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep3InputScores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3️⃣ 輸入各贏家台數',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._selectedWinners.map((playerId) {
          final player = widget.game.players.firstWhere((p) => p.id == playerId);
          return _buildWinnerScoreInput(player);
        }),
      ],
    );
  }

  Widget _buildWinnerScoreInput(Player player) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(player.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 台數快選 0-5
            Wrap(
              spacing: 8,
              children: List.generate(6, (i) => i).map((tai) {
                final isSelected = _taiMap[player.id] == tai;
                return ChoiceChip(
                  label: Text('$tai台'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _taiMap[player.id] = tai;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            
            // 台數輸入（移除花牌）
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '台數',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(
                text: _taiMap[player.id]?.toString() ?? '0',
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _taiMap[player.id] = parsed;
                  });
                }
              },
            ),

            const SizedBox(height: 8),

            // 特殊牌型（可收合，預設收起）
            _buildWinnerPatternSelection(player),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerPatternSelection(Player player) {
    final allPatterns = HandPattern.allPatterns(widget.game.settings.customPatterns);
    final selected = _winnerPatternIds[player.id] ?? {};
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        title: Row(
          children: [
            Text(
              '特殊牌型',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selected.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allPatterns.map((pattern) {
              final isSelected = selected.contains(pattern.id);
              return FilterChip(
                label: Text('${pattern.name}(${pattern.referenceTai})',
                    style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                onSelected: (sel) {
                  setState(() {
                    final s = _winnerPatternIds[player.id] ??= {};
                    if (sel) {
                      s.add(pattern.id);
                    } else {
                      s.remove(pattern.id);
                    }
                  });
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final scoreChanges = CalculationService.calculateMultiWin(
      game: widget.game,
      winnerIds: _selectedWinners.toList(),
      loserId: _loser!.id,
      taiMap: _taiMap,
      flowerMap: _flowerMap,
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, size: 20, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '計算結果',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const Divider(),
          ...widget.game.players.map((player) {
            final change = scoreChanges[player.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(player.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(player.name)),
                  Text(
                    CalculationService.formatScore(change),
                    style: TextStyle(
                      fontSize: 16,
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
          const Divider(),
          Text(
            '${_loser!.name} 放槍給 ${_selectedWinners.length} 人',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  bool _canCalculate() {
    if (_loser == null || _selectedWinners.isEmpty) return false;
    
    // 確保所有贏家都有台數設定
    for (var winnerId in _selectedWinners) {
      if (!_taiMap.containsKey(winnerId)) return false;
    }
    
    return true;
  }
}
