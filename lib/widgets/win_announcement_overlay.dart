import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/round.dart';
import '../models/player.dart';
import '../models/hand_pattern.dart';
import '../services/calculation_service.dart';
import '../services/sound_service.dart';

/// 自動更新模式下的胡牌全屏公告
class WinAnnouncementOverlay extends StatefulWidget {
  final Game game;
  final Round round;
  final VoidCallback onDismiss;
  final bool soundEnabled;
  final double soundVolume;
  final bool playSound; // false = 手動呼出時不播音效

  const WinAnnouncementOverlay({
    super.key,
    required this.game,
    required this.round,
    required this.onDismiss,
    this.soundEnabled = true,
    this.soundVolume = 0.7,
    this.playSound = true,
  });

  @override
  State<WinAnnouncementOverlay> createState() => _WinAnnouncementOverlayState();
}

class _WinAnnouncementOverlayState extends State<WinAnnouncementOverlay>
    with SingleTickerProviderStateMixin {
  static const _displaySeconds = 10;

  // 用 AnimationController 控制整個生命週期（倒數 + 淡出）
  late AnimationController _controller; // 0.0 → 1.0 over 10s
  late Animation<double> _fadeOut;      // 最後 1s 淡出

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _displaySeconds),
    );

    // 最後 10% 時間（約 1 秒）做淡出
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.9, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onDismiss();
      }
    });

    _controller.forward();

    // 播放音效
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

  // ── 資料提取 ─────────────────────────────────────────

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

  List<String> _handPatternNames() {
    final custom = widget.game.settings.customPatterns;
    return widget.round.handPatternIds
        .map((id) => HandPattern.nameById(id, custom))
        .toList();
  }

  String? _dealerInfo() {
    final consecutive = widget.round.consecutiveWins;
    if (!widget.game.settings.consecutiveTai || consecutive <= 0) return null;
    final extraTai = consecutive * 2;
    return '莊家連$consecutive　＋$extraTai台';
  }

  // ── UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final isSelfDraw = round.type == RoundType.selfDraw;
    final winner = _playerById(round.winnerId);
    final loser = _playerById(round.loserId);
    final patterns = _handPatternNames();
    final dealerInfo = _dealerInfo();
    final scores = widget.game.currentScores;
    final effTai = CalculationService.effectiveTaiFromRound(
        round, widget.game.settings, widget.game.players);

    final sortedPlayers = List<Player>.from(widget.game.players)
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeOut.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      '點擊任意處關閉',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // ── 勝者 ──
                  if (winner != null) ...[
                    Text(winner.emoji, style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 8),
                    Text(
                      winner.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 33,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chip(_typeLabel(),
                            isSelfDraw ? Colors.greenAccent : Colors.amberAccent),
                        const SizedBox(width: 10),
                        _chip('$effTai 台', Colors.white70),
                        if (effTai != round.totalTai) ...[
                          const SizedBox(width: 6),
                          _chip('底 ${round.totalTai}', Colors.white24),
                        ],
                      ],
                    ),
                  ],

                  // ── 放槍者 ──
                  if (loser != null && !isSelfDraw) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${loser.emoji} ${loser.name} 放槍',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 17),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ── 特殊牌型（字體 2x）──
                  if (patterns.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: patterns.map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.deepPurpleAccent
                                  .withValues(alpha: 0.7)),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28, // 原本 14 → 2x
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )).toList(),
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
                    if (change > 0) changeColor = Colors.greenAccent;
                    if (change < 0) changeColor = Colors.redAccent;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Text(player.emoji,
                              style: const TextStyle(fontSize: 23)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  player.name,
                                  style: TextStyle(
                                    color: isWinner
                                        ? Colors.greenAccent
                                        : isLoser
                                            ? Colors.redAccent
                                            : Colors.white70,
                                    fontSize: 17,
                                    fontWeight: isWinner || isLoser
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (isWinner)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text('🏆',
                                        style: TextStyle(fontSize: 15)),
                                  ),
                                if (isLoser)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text('🔫',
                                        style: TextStyle(fontSize: 15)),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            change >= 0 ? '+$change' : '$change',
                            style: TextStyle(
                              color: changeColor,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Spacer(flex: 2),

                  // ── 平滑倒數條 ──
                  _buildCountdownBar(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        final progress = 1.0 - _controller.value; // 1.0 → 0.0
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
              style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
