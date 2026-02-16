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
    // 響應式佈局計算
    final screenSize = MediaQuery.of(context).size;
    final dialogPadding = 12.0 * 2; // Dialog 內部 padding
    final dialogMargin = 6.0 * 2; // Dialog 外部最小 6px 邊距
    final availableWidth = screenSize.width - dialogMargin - dialogPadding;
    final availableHeight = screenSize.height - 280; // 扣除標題、按鈕等

    // 容器大小（取較小值，確保正方形，不設最小值以免溢出）
    final containerSize = (availableWidth < availableHeight
        ? availableWidth
        : availableHeight).clamp(200.0, 500.0);

    // 桌面大小（容器的 85%）
    final tableSize = containerSize * 0.85;

    // 卡片大小（根據容器大小動態計算）
    final cardWidth = (containerSize * 0.31).clamp(55.0, 110.0);
    final cardHeight = cardWidth * 1.3;

    // 邊距
    final margin = (containerSize - tableSize) / 2;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: (containerSize + dialogPadding) * 0.97),
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
              height: containerSize,
              width: containerSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 桌面
                  Center(
                    child: Container(
                      width: tableSize,
                      height: tableSize,
                      decoration: BoxDecoration(
                        color: AppConstants.tableGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppConstants.tableGreen,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  
                  // 四個玩家位置
                  ..._buildPlayerPositions(
                    containerSize: containerSize,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    margin: margin,
                  ),
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

  List<Widget> _buildPlayerPositions({
    required double containerSize,
    required double cardWidth,
    required double cardHeight,
    required double margin,
  }) {
    return List.generate(4, (index) {
      final player = _players[index];
      final windPos = (index - widget.game.dealerSeat + 4) % 4;
      final windName = AppConstants.windNames[windPos];
      final isSelected = _selectedIndex == index;
      
      // 計算位置：上下置中，左右兩側（根據容器大小動態計算）
      double left, top;
      final centerX = (containerSize - cardWidth) / 2;
      final centerY = (containerSize - cardHeight) / 2;
      
      switch (index) {
        case 0: // 右家
          left = containerSize - cardWidth - margin;
          top = centerY;
          break;
        case 1: // 上家（置中）
          left = centerX;
          top = margin;
          break;
        case 2: // 左家
          left = margin;
          top = centerY;
          break;
        case 3: // 下家（置中）
          left = centerX;
          top = containerSize - cardHeight - margin;
          break;
        default:
          left = centerX;
          top = centerY;
      }

      // 根據卡片大小計算字體
      final scaleFactor = cardWidth / 100;
      final fontSize = (14 * scaleFactor).clamp(10.0, 16.0);
      final emojiSize = (36 * scaleFactor).clamp(20.0, 44.0);
      final padding = (12 * scaleFactor).clamp(6.0, 16.0);

      return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onTap: () => _onPlayerTap(index),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: cardWidth,
            height: cardHeight,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 風位
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * scaleFactor,
                      vertical: 2 * scaleFactor,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      windName,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: 4 * scaleFactor),

                  // Emoji
                  Text(
                    player.emoji,
                    style: TextStyle(fontSize: emojiSize),
                  ),

                  SizedBox(height: 4 * scaleFactor),

                  // 名稱
                  Text(
                    player.name,
                    style: TextStyle(fontSize: fontSize),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
            },
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
