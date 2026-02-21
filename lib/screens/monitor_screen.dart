import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';

/// 監測模式：大字記分板，每 10 秒從 Firestore 拉取最新資料
class MonitorScreen extends StatefulWidget {
  final String gameId;
  final Game initialGame;

  const MonitorScreen({
    super.key,
    required this.gameId,
    required this.initialGame,
  });

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late Game _game;
  Timer? _timer;
  int _countdown = 10;
  DateTime? _lastUpdated;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _lastUpdated = DateTime.now();
    // 全螢幕沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdown = 10;
          _refresh();
        }
      });
    });
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final game = await FirestoreService.loadGame(widget.gameId);
      if (game != null && mounted) {
        setState(() {
          _game = game;
          _lastUpdated = DateTime.now();
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scores = _game.currentScores;
    final players = _game.players;

    // 依分數排序（高→低）
    final ranked = List<Player>.from(players)
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              _buildHeader(players),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  physics: const NeverScrollableScrollPhysics(),
                  children: ranked.asMap().entries.map((e) {
                    final rank = e.key;
                    final player = e.value;
                    final score = scores[player.id] ?? 0;
                    final seatIndex = players.indexOf(player);
                    final isDealer = _game.dealerSeat == seatIndex;
                    return _buildPlayerCard(
                      player: player,
                      score: score,
                      isDealer: isDealer,
                      rank: rank,
                      total: ranked.length,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<Player> players) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 局資訊
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _game.currentWindDisplay,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              '共 ${_game.rounds.length} 局',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        // 倒數 + 重新整理 + 關閉
        Row(
          children: [
            _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  )
                : Text(
                    '$_countdown s',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
              tooltip: '立即更新',
              onPressed: () {
                setState(() => _countdown = 10);
                _refresh();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              tooltip: '退出監測',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerCard({
    required Player player,
    required int score,
    required bool isDealer,
    required int rank,
    required int total,
  }) {
    // 顏色：第1名綠、最後名紅、其餘藍灰
    final Color bgColor;
    final Color scoreColor;
    if (rank == 0) {
      bgColor = const Color(0xFF0D2B0D);
      scoreColor = Colors.greenAccent;
    } else if (rank == total - 1) {
      bgColor = const Color(0xFF2B0D0D);
      scoreColor = Colors.redAccent;
    } else {
      bgColor = const Color(0xFF0D0D2B);
      scoreColor = Colors.white;
    }

    final scoreStr = score > 0 ? '+$score' : '$score';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isDealer
            ? Border.all(color: Colors.amber, width: 2)
            : Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          // 排名
          Positioned(
            top: 10,
            left: 12,
            child: Text(
              '#${rank + 1}',
              style: TextStyle(
                color: rank == 0 ? Colors.greenAccent : Colors.white30,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 莊家標籤
          if (isDealer)
            Positioned(
              top: 8,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '莊',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // 中央內容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(player.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 4),
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  scoreStr,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.access_time, color: Colors.grey, size: 12),
        const SizedBox(width: 4),
        Text(
          _lastUpdated != null
              ? '最後更新：${_formatTime(_lastUpdated!)}'
              : '更新中...',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
