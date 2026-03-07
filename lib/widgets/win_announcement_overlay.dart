import 'dart:async';
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

  const WinAnnouncementOverlay({
    super.key,
    required this.game,
    required this.round,
    required this.onDismiss,
    this.soundEnabled = true,
    this.soundVolume = 0.7,
  });

  @override
  State<WinAnnouncementOverlay> createState() => _WinAnnouncementOverlayState();
}

class _WinAnnouncementOverlayState extends State<WinAnnouncementOverlay>
    with SingleTickerProviderStateMixin {
  static const _displaySeconds = 10;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  Timer? _countdownTimer;
  int _remaining = _displaySeconds;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDismiss();
    });

    // 播放音效
    SoundService.playForRound(
      round: widget.round,
      settings: widget.game.settings,
      players: widget.game.players,
      enabled: widget.soundEnabled,
      volume: widget.soundVolume,
    );

    // 倒數計時
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _countdownTimer?.cancel();
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
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
      case RoundType.selfDraw:
        return '自摸';
      case RoundType.win:
        return '胡牌';
      case RoundType.multiWin:
        return '一炮多響';
      case RoundType.falseWin:
        return '詐胡';
      case RoundType.draw:
        return '流局';
    }
  }

  /// 牌型名稱列表
  List<String> _handPatternNames() {
    final custom = widget.game.settings.customPatterns;
    return widget.round.handPatternIds
        .map((id) => HandPattern.nameById(id, custom))
        .toList();
  }

  /// 莊家連莊描述，e.g. "莊家連2 拉2台"
  String? _dealerInfo() {
    final consecutive = widget.round.consecutiveWins;
    if (!widget.game.settings.consecutiveTai || consecutive <= 0) return null;
    final extraTai = consecutive * 2;
    return '莊家連$consecutive　＋$extraTai台';
  }

  // ── 建構 UI ──────────────────────────────────────────

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

    // 依分數高→低排列玩家
    final sortedPlayers = List<Player>.from(widget.game.players)
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    return FadeTransition(
      opacity: ReverseAnimation(_fadeAnim), // 淡出
      child: GestureDetector(
        onTap: () {
          _countdownTimer?.cancel();
          _fadeController.forward();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // ── 頂部：關閉提示 ──
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      '點擊任意處關閉',
                      style: TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // ── 勝者 ──
                  if (winner != null) ...[
                    Text(
                      winner.emoji,
                      style: const TextStyle(fontSize: 72),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      winner.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 胡牌方式 + 台數
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _typeChip(_typeLabel(),
                            isSelfDraw ? Colors.greenAccent : Colors.amberAccent),
                        const SizedBox(width: 10),
                        _typeChip('$effTai 台', Colors.white70),
                        if (round.flowers > 0 || effTai != round.totalTai) ...[
                          const SizedBox(width: 6),
                          _typeChip('(底 ${round.totalTai})', Colors.white30),
                        ],
                      ],
                    ),
                  ],

                  // ── 放槍者 ──
                  if (loser != null && !isSelfDraw) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${loser.emoji} ${loser.name} 放槍',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── 牌型 ──
                  if (patterns.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: patterns.map((name) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),

                  // ── 連莊資訊 ──
                  if (dealerInfo != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dealerInfo,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
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
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(player.emoji, style: const TextStyle(fontSize: 22)),
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
                                    fontSize: 16,
                                    fontWeight: isWinner || isLoser
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (isWinner)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text('🏆', style: TextStyle(fontSize: 14)),
                                  ),
                                if (isLoser)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Text('🔫', style: TextStyle(fontSize: 14)),
                                  ),
                              ],
                            ),
                          ),
                          // 本局變動
                          Text(
                            change >= 0 ? '+$change' : '$change',
                            style: TextStyle(
                              color: changeColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 目前總分
                          SizedBox(
                            width: 70,
                            child: Text(
                              '= $total',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Spacer(flex: 2),

                  // ── 倒數進度條 ──
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

  Widget _typeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCountdownBar() {
    final progress = _remaining / _displaySeconds;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
              progress > 0.4 ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_remaining 秒後關閉',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }
}
