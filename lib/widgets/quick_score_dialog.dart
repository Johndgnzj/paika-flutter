import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/hand_pattern.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../providers/game_provider.dart';
import '../services/calculation_service.dart';
import 'player_avatar.dart';

/// 快速記分對話框
class QuickScoreDialog extends StatefulWidget {
  final Game game;
  final Player selectedPlayer;
  final Player? prefillLoser;      // 預填放槍者
  final bool prefillSelfDraw;      // 預填是否自摸
  final int? prefillTai;           // 預填台數

  const QuickScoreDialog({
    super.key,
    required this.game,
    required this.selectedPlayer,
    this.prefillLoser,
    this.prefillSelfDraw = false,
    this.prefillTai,
  });

  @override
  State<QuickScoreDialog> createState() => _QuickScoreDialogState();
}

class _QuickScoreDialogState extends State<QuickScoreDialog> {
  // 記分類型
  late String _scoreType;
  
  // 台數
  late int _tai;
  
  // 放槍者（胡牌時需要）
  Player? _loser;

  // 特殊牌型（已選的 ID）
  final Set<String> _selectedPatternIds = {};

  // 骰規（倍數規則）
  DiceRuleMode _diceMode = DiceRuleMode.none;
  int _diceFactor = 2;

  @override
  void initState() {
    super.initState();
    
    // 初始化預填值
    _scoreType = widget.prefillSelfDraw ? 'selfDraw' : 'win';
    _tai = widget.prefillTai ?? 0;
    _loser = widget.prefillLoser;
  }

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
              // 標題（使用 Consumer 動態更新）
              Consumer<GameProvider>(
                builder: (context, gameProvider, _) {
                  // 從當前遊戲取得最新的 player 資料
                  Player currentPlayer = widget.selectedPlayer;
                  if (gameProvider.currentGame != null) {
                    try {
                      currentPlayer = gameProvider.currentGame!.players
                          .firstWhere((p) => p.id == widget.selectedPlayer.id);
                    } catch (e) {
                      // 找不到就用原本的
                      currentPlayer = widget.selectedPlayer;
                    }
                  }
                  
                  return Row(
                    children: [
                      PlayerGameAvatar(player: currentPlayer, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPlayer.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditPlayerNameDialog(context),
                        tooltip: '修改名稱',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  );
                },
              ),
              
              const Divider(),
              const SizedBox(height: 16),
              
              // 記分類型 + 放槍者選擇（合併）
              _buildCombinedTypeSelection(),
              
              const SizedBox(height: 24),

              // 台數選擇（詐胡時隱藏）
              if (_scoreType != 'falseWin') ...[
                _buildTaiSelection(),
                const SizedBox(height: 16),
                // 特殊牌型（可收合，預設收起）
                _buildPatternSelection(),
                const SizedBox(height: 16),
                // 骰規（倍數規則）
                _buildDiceRuleSelection(),
              ],

              const SizedBox(height: 16),
              
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

  /// 合併記分類型＋放槍者：自摸 | 玩家A | 玩家B | 玩家C | 詐胡
  Widget _buildCombinedTypeSelection() {
    final availablePlayers = widget.game.players
        .where((p) => p.id != widget.selectedPlayer.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '記分類型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // 自摸
            ChoiceChip(
              label: const Text('自摸'),
              selected: _scoreType == 'selfDraw',
              labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              onSelected: (_) {
                setState(() {
                  _scoreType = 'selfDraw';
                  _loser = null;
                });
              },
            ),
            // 各玩家（選中表示對方放槍）
            ...availablePlayers.map((player) {
              final isSelected = _scoreType == 'win' && _loser?.id == player.id;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerGameAvatar(player: player, size: 26),
                    const SizedBox(width: 5),
                    Text(player.name, style: const TextStyle(fontSize: 16.1)),
                  ],
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _scoreType = 'win';
                    _loser = selected ? player : null;
                  });
                },
                selectedColor: Colors.red.withValues(alpha: 0.2),
              );
            }),
            // 詐胡
            ChoiceChip(
              label: const Text('詐胡'),
              selected: _scoreType == 'falseWin',
              labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              onSelected: (_) {
                setState(() {
                  _scoreType = 'falseWin';
                  _loser = null;
                });
              },
              selectedColor: Colors.red.withValues(alpha: 0.2),
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
        // 台數選單 (0-99)，高度限制 1/3 螢幕，最小顯示 5 項
        Builder(
          builder: (ctx) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            const itemHeight = 48.0;
            final maxHeight = math.max(screenHeight / 3, itemHeight * 5);
            return DropdownButtonFormField<int>(
              initialValue: _tai,
              menuMaxHeight: maxHeight,
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
            );
          },
        ),
      ],
    );
  }

  /// 特殊牌型區（可收合，預設收起）
  Widget _buildPatternSelection() {
    final allPatterns = HandPattern.allPatterns(widget.game.settings.customPatterns);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        title: Row(
          children: [
            const Text(
              '特殊牌型',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_selectedPatternIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedPatternIds.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allPatterns.map((pattern) {
              final isSelected = _selectedPatternIds.contains(pattern.id);
              return FilterChip(
                label: Text('${pattern.name}(${pattern.referenceTai})'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPatternIds.add(pattern.id);
                    } else {
                      _selectedPatternIds.remove(pattern.id);
                    }
                  });
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // _buildLoserSelection 已整合進 _buildCombinedTypeSelection

  /// 骰規（倍數規則）選擇
  Widget _buildDiceRuleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('骰規', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _showDiceRuleInfo,
              child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('無'),
              selected: _diceMode == DiceRuleMode.none,
              onSelected: (_) => setState(() => _diceMode = DiceRuleMode.none),
            ),
            ChoiceChip(
              label: const Text('整體加倍'),
              selected: _diceMode == DiceRuleMode.total,
              onSelected: (_) => setState(() => _diceMode = DiceRuleMode.total),
            ),
            ChoiceChip(
              label: const Text('台數加倍'),
              selected: _diceMode == DiceRuleMode.tai,
              onSelected: (_) => setState(() => _diceMode = DiceRuleMode.tai),
            ),
          ],
        ),
        if (_diceMode != DiceRuleMode.none) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('倍數：'),
              const SizedBox(width: 8),
              ...[2, 3, 4, 5].map((n) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('×$n'),
                      selected: _diceFactor == n,
                      onSelected: (_) => setState(() => _diceFactor = n),
                    ),
                  )),
            ],
          ),
        ],
      ],
    );
  }

  void _showDiceRuleInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('骰規說明'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('骰規會把計算結果乘上倍數，但「台數」本身不變（統計仍以原台數計算）。',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('🎲 整體加倍：（底 + 台×每台）× N'),
              SizedBox(height: 6),
              Text('🎲 台數加倍：底 + (台×每台 × N)'),
              SizedBox(height: 12),
              Text('例：底 50、2 台、每台 20、倍數 ×3',
                  style: TextStyle(color: Colors.grey)),
              Text('整體：(50 + 2×20) × 3 = 270', style: TextStyle(color: Colors.grey)),
              Text('台數：50 + (2×20 × 3) = 170', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('了解了')),
        ],
      ),
    );
  }

  Widget _buildPreview(GameProvider provider) {
    final settings = widget.game.settings;
    final game = widget.game;
    final dealer = game.dealer;
    final consecutiveWins = game.consecutiveWins;
    final diceActive = _diceMode != DiceRuleMode.none && _diceFactor > 1;
    final effFactor = diceActive ? _diceFactor : 1;
    final diceNote = diceActive
        ? '\n🎲 骰規 ×$_diceFactor（${_diceMode == DiceRuleMode.total ? '整體加倍' : '台數加倍'}）'
        : '';
    String previewText = '';

    if (_scoreType == 'selfDraw') {
      final changes = CalculationService.calculateSelfDraw(
        game: game,
        winnerId: widget.selectedPlayer.id,
        tai: _tai,
        flowers: 0,
        diceMode: _diceMode,
        diceFactor: effFactor,
      );
      final winnerGets = changes[widget.selectedPlayer.id] ?? 0;
      final isWinnerDealer = (widget.selectedPlayer.id == dealer.id);
      if (isWinnerDealer) {
        // 莊家自摸：三家各付相同
        final each = -(changes.entries
            .firstWhere((e) => e.key != widget.selectedPlayer.id)
            .value);
        previewText = '莊家自摸\n三家各付 $each，共得 $winnerGets$diceNote';
      } else {
        // 非莊家自摸：莊家付更多
        final lines = game.players
            .where((p) => p.id != widget.selectedPlayer.id)
            .map((p) => '${p.name} 付 ${-(changes[p.id] ?? 0)}')
            .join('，');
        previewText =
            '非莊家自摸\n$lines\n${widget.selectedPlayer.name} 共得 $winnerGets$diceNote';
      }
    } else if (_scoreType == 'win' && _loser != null) {
      final isDealerInvolved =
          (widget.selectedPlayer.id == dealer.id || _loser!.id == dealer.id);
      final changes = CalculationService.calculateWin(
        game: game,
        winnerId: widget.selectedPlayer.id,
        loserId: _loser!.id,
        tai: _tai,
        flowers: 0,
        diceMode: _diceMode,
        diceFactor: effFactor,
      );
      final amt = changes[widget.selectedPlayer.id] ?? 0;
      // 底台拆解（未套骰規），再標示骰規與最終金額
      final base = CalculationService.getScorePreview(
        settings: settings,
        tai: _tai,
        flowers: 0,
        isSelfDraw: false,
        isDealer: isDealerInvolved,
        consecutiveWins: isDealerInvolved ? consecutiveWins : 0,
      );
      previewText =
          '$base$diceNote\n${widget.selectedPlayer.name} +$amt\n${_loser!.name} -$amt';
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
    final patternIds = _selectedPatternIds.toList();
    final effFactor = _diceMode == DiceRuleMode.none ? 1 : _diceFactor;
    switch (_scoreType) {
      case 'win':
        if (_loser != null) {
          await provider.recordWin(
            winnerId: widget.selectedPlayer.id,
            loserId: _loser!.id,
            tai: _tai,
            flowers: 0,
            handPatternIds: patternIds,
            diceMode: _diceMode,
            diceFactor: effFactor,
          );
        }
        break;

      case 'selfDraw':
        await provider.recordSelfDraw(
          winnerId: widget.selectedPlayer.id,
          tai: _tai,
          flowers: 0,
          handPatternIds: patternIds,
          diceMode: _diceMode,
          diceFactor: effFactor,
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

  /// 顯示修改玩家名稱對話框
  void _showEditPlayerNameDialog(BuildContext context) {
    final provider = context.read<GameProvider>();
    final controller = TextEditingController(text: widget.selectedPlayer.name);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改玩家名稱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '新名稱',
                border: OutlineInputBorder(),
                helperText: '建議使用繁體中文以提高語音辨識準確度',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '修改名稱只會影響此次牌局，不會改變玩家檔案。',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              
              // 更新牌局中的玩家名稱
              provider.updatePlayerNameInGame(
                widget.game.id,
                widget.selectedPlayer.id,
                newName,
              );
              
              Navigator.pop(dialogContext);
              // Consumer 會自動更新，不需要 setState
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }
}
