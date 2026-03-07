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

  bool get _isMultiWin => widget.round.type == RoundType.multiWin;
  bool get _isSelfDraw => widget.round.type == RoundType.selfDraw;

  /// 一炮多響的所有贏家
  List<Player> get _multiWinners {
    final ids = widget.round.winnerIds.isNotEmpty
        ? widget.round.winnerIds
        : (widget.round.winnerId != null ? [widget.round.winnerId!] : []);
    return ids.map((id) => _playerById(id)).whereType<Player>().toList();
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

  /// 一般局：共同牌型；multiWin：各贏家自己的牌型
  List<HandPattern> _handPatternsForWinner(String? winnerId) {
    final custom = widget.game.settings.customPatterns;
    final all = HandPattern.allPatterns(custom);
    List<String> ids;
    if (_isMultiWin && winnerId != null) {
      ids = widget.round.winnerHandPatterns[winnerId] ?? widget.round.handPatternIds;
    } else {
      ids = widget.round.handPatternIds;
    }
    return ids.map((id) {
      try { return all.firstWhere((p) => p.id == id); }
      catch (_) { return HandPattern(id: id, name: id, referenceTai: 0); }
    }).toList();
  }

  /// 某位贏家的有效台數（從 scoreChanges 取絕對值）
  int _effTaiForWinner(String winnerId) {
    final change = widget.round.scoreChanges[winnerId] ?? 0;
    if (change > 0) return change; // 贏家是正值
    // fallback
    return CalculationService.effectiveTaiFromRound(
        widget.round, widget.game.settings, widget.game.players);
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
    final loser = _playerById(round.loserId);
    final dealerInfo = _dealerInfo();
    final scores = widget.game.currentScores;
    final settings = widget.game.settings;
    final players = widget.game.players;

    // 有效台數（單一贏家時用）
    final effTai = CalculationService.effectiveTaiFromRound(round, settings, players);

    // 非莊家自摸：分別顯示兩種台數
    final winnerIsDealer = round.dealerSeat < players.length &&
        players[round.dealerSeat].id == round.winnerId;
    int? dealerPayTai;
    int normalTai = effTai;
    if (_isSelfDraw && !winnerIsDealer) {
      int base = round.tai + round.flowers;
      if (settings.selfDrawAddTai) base += 1;
      normalTai = base;
      dealerPayTai = effTai;
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
                // 頂部提示列
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
                    if (!widget.autoClose)
                      GestureDetector(
                        onTap: _dismiss,
                        child: const Icon(Icons.close, color: Colors.white54, size: 22),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),

                const Spacer(flex: 1),

                // ── 一炮多響：橫排顯示所有贏家 ──
                if (_isMultiWin) ...[
                  _chip('一炮多響 🎯', Colors.redAccent),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: _multiWinners.map((w) {
                      final tai = _effTaiForWinner(w.id);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(w.emoji,
                              style: const TextStyle(
                                  fontSize: 44, decoration: TextDecoration.none)),
                          const SizedBox(height: 4),
                          Text(w.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              )),
                          const SizedBox(height: 4),
                          _chip('$tai 台', Colors.amberAccent),
                        ],
                      );
                    }).toList(),
                  ),
                  // 放槍者：兩列（名字 + 各人台數）
                  if (loser != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${loser.emoji} ${loser.name}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: _multiWinners.map((w) {
                        final tai = _effTaiForWinner(w.id);
                        return Text(
                          '→ ${w.name} $tai台',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],

                // ── 一般胡牌 / 自摸 ──
                if (!_isMultiWin) ...[
                  if (_playerById(round.winnerId) case final winner?) ...[
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
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _chip(_typeLabel(),
                            _isSelfDraw ? Colors.greenAccent : Colors.amberAccent),
                        _chip('$normalTai 台', Colors.white70),
                        if (dealerPayTai != null && dealerPayTai != normalTai)
                          _chip('莊家 $dealerPayTai 台', Colors.amber),
                        if (dealerPayTai == null && effTai != round.totalTai)
                          _chip('底 ${round.totalTai}', Colors.white24),
                      ],
                    ),
                  ],
                  // 放槍者（非自摸）
                  if (loser != null && !_isSelfDraw) ...[
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
                ],

                const SizedBox(height: 18),

                // ── 特殊牌型（一般局 or multiWin 各人）──
                ..._buildPatternSection(),

                // ── 連莊 ──
                if (dealerInfo != null) ...[
                  const SizedBox(height: 4),
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

  /// 特殊牌型區塊：一炮多響時每位贏家分開顯示
  List<Widget> _buildPatternSection() {
    if (_isMultiWin) {
      final widgets = <Widget>[];
      for (final w in _multiWinners) {
        final patterns = _handPatternsForWinner(w.id);
        if (patterns.isEmpty) continue;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text('${w.emoji} ', style: const TextStyle(
                  fontSize: 16, decoration: TextDecoration.none)),
              ...patterns.map((p) => _patternChip(p)),
            ],
          ),
        ));
      }
      return widgets;
    } else {
      final patterns = _handPatternsForWinner(widget.round.winnerId);
      if (patterns.isEmpty) return [];
      return [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: patterns.map(_patternChip).toList(),
        ),
      ];
    }
  }

  Widget _patternChip(HandPattern p) {
    final isHighTai = p.referenceTai >= 4;
    final borderColor = isHighTai
        ? AppConstants.dealerColor.withValues(alpha: 0.8)
        : Colors.blueAccent.withValues(alpha: 0.7);
    final bgColor = isHighTai
        ? Colors.orange.withValues(alpha: 0.2)
        : Colors.deepPurple.withValues(alpha: 0.35);
    final textColor = isHighTai ? AppConstants.dealerColor : Colors.lightBlueAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Text(p.name,
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          )),
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
