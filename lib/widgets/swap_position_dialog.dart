import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../utils/constants.dart';

/// 換位置對話框
class SwapPositionDialog extends StatefulWidget {
  final Game game;

  const SwapPositionDialog({super.key, required this.game});

  @override
  State<SwapPositionDialog> createState() => _SwapPositionDialogState();
}

class _SwapPositionDialogState extends State<SwapPositionDialog> {
  late List<Player> _players;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _players = List.from(widget.game.players);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題
            Row(
              children: [
                const Icon(Icons.swap_horiz, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '🔄 調整位置',
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
              '點選兩位玩家來交換位置',
              style: TextStyle(color: Colors.grey),
            ),
            
            const SizedBox(height: 24),
            
            // 麻將桌視圖
            SizedBox(
              height: 400,
              width: 400,
              child: Stack(
                children: [
                  // 桌面
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: AppConstants.mahjongGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppConstants.mahjongGreen,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  
                  // 四個玩家位置
                  ..._buildPlayerPositions(),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
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
                  onPressed: _hasChanged()
                      ? () async {
                          final provider = context.read<GameProvider>();
                          
                          // 找出差異並交換
                          for (int i = 0; i < 4; i++) {
                            if (_players[i].id != widget.game.players[i].id) {
                              // 找到交換的目標位置
                              for (int j = i + 1; j < 4; j++) {
                                if (_players[i].id == widget.game.players[j].id) {
                                  await provider.swapPlayers(i, j);
                                  break;
                                }
                              }
                            }
                          }
                          
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
    );
  }

  List<Widget> _buildPlayerPositions() {
    return List.generate(4, (index) {
      final player = _players[index];
      final windPos = (index - widget.game.dealerSeat + 4) % 4;
      final windName = AppConstants.windNames[windPos];
      final isSelected = _selectedIndex == index;
      
      // 計算位置（逆時針排列：東→北→西→南）
      double left, top;
      switch (index) {
        case 0: // 東（右）
          left = 270;
          top = 170;
          break;
        case 1: // 南（原為下，現改為上 = 北的位置）
          left = 170;
          top = 30;
          break;
        case 2: // 西（左）
          left = 30;
          top = 170;
          break;
        case 3: // 北（原為上，現改為下 = 南的位置）
          left = 170;
          top = 270;
          break;
        default:
          left = 200;
          top = 200;
      }

      return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onTap: () => _onPlayerTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.shade100
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.blue
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 風位
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    windName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Emoji
                Text(
                  player.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                
                const SizedBox(height: 4),
                
                // 名稱
                Text(
                  player.name,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _onPlayerTap(int index) {
    setState(() {
      if (_selectedIndex == null) {
        // 第一次點選
        _selectedIndex = index;
      } else if (_selectedIndex == index) {
        // 點選同一個，取消選擇
        _selectedIndex = null;
      } else {
        // 交換位置
        final temp = _players[_selectedIndex!];
        _players[_selectedIndex!] = _players[index];
        _players[index] = temp;
        _selectedIndex = null;
      }
    });
  }

  bool _hasChanged() {
    for (int i = 0; i < 4; i++) {
      if (_players[i].id != widget.game.players[i].id) {
        return true;
      }
    }
    return false;
  }
}
