import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../providers/game_provider.dart';
import '../services/calculation_service.dart';
import 'package:uuid/uuid.dart';

/// 流局對話框
class DrawDialog extends StatefulWidget {
  final Game game;

  const DrawDialog({super.key, required this.game});

  @override
  State<DrawDialog> createState() => _DrawDialogState();
}

class _DrawDialogState extends State<DrawDialog> {
  // 選中的聽牌玩家
  final Set<String> _tingPlayers = {};
  
  // 聽牌獎金設定
  int _tingReward = 1000;

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
                  const Icon(Icons.nature, color: Colors.grey, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    '🌊 流局',
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
              
              const Text(
                '流局（荒牌）- 牌牆摸完無人胡牌',
                style: TextStyle(color: Colors.grey),
              ),
              
              const SizedBox(height: 24),
              
              // 聽牌玩家選擇
              _buildTingPlayerSelection(),
              
              const SizedBox(height: 24),
              
              // 聽牌獎金設定
              _buildTingRewardSetting(),
              
              const SizedBox(height: 24),
              
              // 計算預覽
              if (_tingPlayers.isNotEmpty) _buildPreview(),
              
              const SizedBox(height: 24),
              
              // 說明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          '規則說明',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• 聽牌者從未聽牌者獲得獎金\n'
                      '• 莊家流局後連莊\n'
                      '• 如果沒有人聽牌，不計分直接連莊',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
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
                    onPressed: () async {
                      await _recordDraw(provider);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('✓ 確認流局'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTingPlayerSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '選擇聽牌玩家',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '（如果沒有人聽牌，不用選擇）',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.game.players.map((player) {
            final isSelected = _tingPlayers.contains(player.id);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(player.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Text(player.name),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.hearing, size: 16, color: Colors.blue),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _tingPlayers.add(player.id);
                  } else {
                    _tingPlayers.remove(player.id);
                  }
                });
              },
              selectedColor: Colors.blue.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTingRewardSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '聽牌獎金設定',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '每位聽牌者獲得（元）',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: '未聽牌者均分支付',
                ),
                controller: TextEditingController(text: _tingReward.toString()),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() {
                      _tingReward = parsed;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final tingCount = _tingPlayers.length;
    final notTingCount = 4 - tingCount;
    
    if (tingCount == 0 || tingCount == 4) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '沒有聽牌玩家或全員聽牌，不計分',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    // 計算分數變化
    final perPersonCost = (_tingReward * tingCount / notTingCount).round();
    final scoreChanges = <String, int>{};
    
    for (var player in widget.game.players) {
      if (_tingPlayers.contains(player.id)) {
        scoreChanges[player.id] = _tingReward;
      } else {
        scoreChanges[player.id] = -perPersonCost;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
            final isTing = _tingPlayers.contains(player.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(player.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${player.name}${isTing ? ' 🎯聽牌' : ''}',
                    ),
                  ),
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
            '$tingCount 人聽牌，$notTingCount 人未聽牌',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _recordDraw(GameProvider provider) async {
    final tingCount = _tingPlayers.length;
    
    // 計算分數變化
    Map<String, int> scoreChanges;
    
    if (tingCount == 0 || tingCount == 4) {
      // 沒有人聽牌或全員聽牌，不計分
      scoreChanges = {};
      for (var player in widget.game.players) {
        scoreChanges[player.id] = 0;
      }
    } else {
      // 有人聽牌
      final notTingCount = 4 - tingCount;
      final perPersonCost = (_tingReward * tingCount / notTingCount).round();
      
      scoreChanges = {};
      for (var player in widget.game.players) {
        if (_tingPlayers.contains(player.id)) {
          scoreChanges[player.id] = _tingReward;
        } else {
          scoreChanges[player.id] = -perPersonCost;
        }
      }
    }
    
    // 建立流局記錄
    const uuid = Uuid();
    final round = Round(
      id: uuid.v4(),
      timestamp: DateTime.now(),
      wind: widget.game.currentWind,
      sequence: widget.game.dealerIndex,
      type: RoundType.draw,
      tai: 0,
      scoreChanges: scoreChanges,
      notes: tingCount > 0 ? '聽牌: $tingCount 人' : '流局',
    );
    
    // 手動添加 round 並處理連莊（使用 provider 內部邏輯）
    await provider.recordCustomRound(round);
  }
}
