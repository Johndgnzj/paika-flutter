import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/hand_pattern.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../services/calculation_service.dart';
import '../services/sound_service.dart';
import '../utils/constants.dart';

/// 自動更新模式下的胡牌全屏公告
class WinAnnouncementOverlay extends StatefulWidget {
  final Game game;
  final Round round;
  final VoidCallback onDismiss;
  final bool soundEnabled;
  final double soundVolume;
  final bool playSound;   // false = 手動叫出，不播音效
  final bool autoClose;   // false = 手動查看，不自動關閉

  const WinAnnouncementOverlay({
    super.key,
    required this.game,
    required this.round,
    required this.onDismiss,
    this.soundEnabled = true,
    this.soundVolume = 0.7,
    this.playSound = true,
    this.autoClose = true,
  });

  @override
  State<WinAnnouncementOverlay> createState() => _WinAnnouncementOverlayState();
}

class _WinAnnouncementOverlayState extends State<WinAnnouncementOverlay>
    with SingleTickerProviderStateMixin {
  static const _displaySeconds = 10;

  late AnimationController _controller;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _displaySeconds),
    );

    // 最後 10% 淡出
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.9, 1.0, curve: Curves.easeIn),
      ),
    );

    if (widget.autoClose) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onDismiss();
        }
      });
      _controller.forward();
    }

    if (widget.playSound) {
      SoundService.playForRound(
        round: widget.round,
        settings: widget.game.settings,
        players: widget.game.players,
        enabled: widget.soundEnabled,
        volume: widget.soundVolume,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.stop();
    widget.onDismiss();
  }

  // ── 資料 ─────────────────────────────────────────────

  Player? _playerById(String? id) {
    if (id == null) return null;
    try {
      return widget.game.players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String _typeLabel() {
    switch (widget.round.type) {
      case RoundType.selfDraw:  return '自摸';
      case RoundType.win:       return '胡牌';
      case RoundType.multiWin:  return '一炮多響';
      case RoundType.falseWin:  return '詐胡';
      case RoundType.draw:      return '流局';
    }
  }

  /// 查找牌型物件（含 referenceTai）
  List<HandPattern> _handPatterns() {
    final custom = widget.game.settings.customPatterns;
    final all = HandPattern.allPatterns(custom);
    return widget.round.handPatternIds
        .map((id) {
          try {
            return all.firstWhere((p) => p.id == id);
          } catch (_) {
            return HandPattern(id: id, name: id, referenceTai: 0);
          }
        })
        .toList();
  }

  String? _dealerInfo() {
    final consecutive = widget.round.consecutiveWins;
    if (!widget.game.settings.consecutiveTai || consecutive <= 0) return null;
    final extraTai = consecutive * 2;
    return '莊家連$consecutive　＋$extraTai台';
  }

  // ── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final isSelfDraw = round.type == RoundType.selfDraw;
    final winner = _playerById(round.winnerId);
    final loser = _playerById(round.loserId);
    final patterns = _handPatterns();
    final dealerInfo = _dealerInfo();
    final scores = widget.game.currentScores;
    final settings = widget.game.settings;
    final players = widget.game.players;

    // 有效台數（含莊家、連莊）
    final effTai = CalculationService.effectiveTaiFromRound(round, settings, players);

    // 非莊家自摸時，分別計算一般玩家 vs 莊家付的台數
    bool winnerIsDealer = round.dealerSeat < players.length &&
        players[round.dealerSeat].id == round.winnerId;
    int? dealerPayTai; // 只在非莊家自摸時有值
    int normalTai = effTai;

    if (isSelfDraw && !winnerIsDealer) {
      // 一般玩家台數（不含莊家bonus + 連莊）
      int base = round.tai + round.flowers;
      if (settings.selfDrawAddTai) base += 1;
      normalTai = base;
      dealerPayTai = effTai; // effectiveTai 已包含莊家+連莊
    }

    final sortedPlayers = List<Player>.from(players)
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    final overlayContent = GestureDetector(
      onTap: _dismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // 頂部提示
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Text(
                      '點擊任意處關閉',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    // 手動模式：明顯關閉按鈕
                    if (!widget.autoClose)
                      GestureDetector(
                        onTap: _dismiss,
                        child: const Icon(Icons.close,
                            color: Colors.white54, size: 22),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),

                const Spacer(flex: 1),

                // ── 勝者 ──
                if (winner != null) ...[
                  Text(winner.emoji,
                      style: const TextStyle(
                          fontSize: 72, decoration: TextDecoration.none)),
                  const SizedBox(height: 8),
                  Text(
                    winner.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 33,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 胡牌方式 + 台數 chip 列
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _chip(_typeLabel(),
                          isSelfDraw ? Colors.greenAccent : Colors.amberAccent),
                      _chip('$normalTai 台', Colors.white70),
                      // 非莊家自摸：額外顯示莊家付的台數
                      if (dealerPayTai != null && dealerPayTai != normalTai)
                        _chip('莊家 $dealerPayTai 台', Colors.amber),
                      // 台數有加成時顯示底台
                      if (dealerPayTai == null && effTai != round.totalTai)
                        _chip('底 ${round.totalTai}', Colors.white24),
                    ],
                  ),
                ],

                // ── 放槍者 ──
                if (loser != null && !isSelfDraw) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${loser.emoji} ${loser.name} 放槍',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 17,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── 特殊牌型（依 referenceTai 上色，2x 字體）──
                if (patterns.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: patterns.map((p) {
                      // ≥ 4台：金/橙暖色；< 4台：藍/紫冷色
                      final isHighTai = p.referenceTai >= 4;
                      final borderColor = isHighTai
                          ? AppConstants.dealerColor.withValues(alpha: 0.8)
                          : Colors.blueAccent.withValues(alpha: 0.7);
                      final bgColor = isHighTai
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.deepPurple.withValues(alpha: 0.35);
                      final textColor =
                          isHighTai ? AppConstants.dealerColor : Colors.lightBlueAccent;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          p.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                // ── 連莊 ──
                if (dealerInfo != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dealerInfo,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),

                // ── 各家分數 ──
                ...sortedPlayers.map((player) {
                  final change = round.scoreChanges[player.id] ?? 0;
                  final total = scores[player.id] ?? 0;
                  final isWinner = player.id == round.winnerId ||
                      round.winnerIds.contains(player.id);
                  final isLoser = player.id == round.loserId;

                  Color changeColor = Colors.white54;
                  if (change > 0) changeColor = AppConstants.winColor;
                  if (change < 0) changeColor = AppConstants.loseColor;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text(player.emoji,
                            style: const TextStyle(
                                fontSize: 23, decoration: TextDecoration.none)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(children: [
                            Text(
                              player.name,
                              style: TextStyle(
                                color: isWinner
                                    ? AppConstants.winColor
                                    : isLoser
                                        ? AppConstants.loseColor
                                        : Colors.white70,
                                fontSize: 17,
                                fontWeight: isWinner || isLoser
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (isWinner)
                              const Text('  🏆',
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none)),
                            if (isLoser)
                              const Text('  🔫',
                                  style: TextStyle(
                                      fontSize: 15,
                                      decoration: TextDecoration.none)),
                          ]),
                        ),
                        Text(
                          change >= 0 ? '+$change' : '$change',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 72,
                          child: Text(
                            '= $total',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const Spacer(flex: 2),

                // ── 倒數 / 關閉 ──
                widget.autoClose
                    ? _buildCountdownBar()
                    : TextButton.icon(
                        onPressed: _dismiss,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('關閉'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white54),
                      ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.autoClose) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Opacity(opacity: _fadeOut.value, child: child),
        child: overlayContent,
      );
    }
    return overlayContent;
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildCountdownBar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final remaining =
            (_displaySeconds * (1.0 - _controller.value)).ceil();
        final progress = 1.0 - _controller.value;
        final barColor =
            progress > 0.4 ? Colors.greenAccent : Colors.redAccent;
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$remaining 秒後關閉',
              style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 12,
                  decoration: TextDecoration.none),
            ),
          ],
        );
      },
    );
  }
}
