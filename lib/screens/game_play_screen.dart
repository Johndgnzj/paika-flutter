import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/game_provider.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../services/calculation_service.dart';
import '../services/firestore_service.dart';
import '../services/voice_scoring_service.dart';
import '../utils/constants.dart';
import '../widgets/animation_helpers.dart';
import '../widgets/multi_win_dialog.dart';
import '../widgets/swap_position_dialog.dart';
import '../widgets/draw_dialog.dart';
import '../widgets/quick_score_dialog.dart';
import '../widgets/voice_input_overlay.dart';
import 'game_detail_screen.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _currentRecognizedText = '';
  bool _hasShownVoicePermissionInfo = false;

  // 監測模式
  bool _isMonitorMode = false;
  Timer? _monitorTimer;
  int _monitorCountdown = 10;
  bool _isMonitorRefreshing = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  // --- 監測模式 ---

  void _enterMonitorMode(Game game) {
    _monitorTimer?.cancel();
    setState(() {
      _isMonitorMode = true;
      _monitorCountdown = 10;
      _isMonitorRefreshing = false;
    });
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _monitorCountdown--;
        if (_monitorCountdown <= 0) {
          _monitorCountdown = 10;
          _monitorRefresh(game.id);
        }
      });
    });
  }

  void _exitMonitorMode() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    setState(() => _isMonitorMode = false);
  }

  Future<void> _monitorRefresh(String gameId) async {
    if (_isMonitorRefreshing) return;
    setState(() => _isMonitorRefreshing = true);
    try {
      // 從 Firestore 拉最新資料（real-time listener 已在跑，這是額外保險）
      await FirestoreService.loadGame(gameId);
    } finally {
      if (mounted) setState(() => _isMonitorRefreshing = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Consumer<GameProvider>(
              builder: (context, provider, _) {
                final game = provider.currentGame;
                if (game == null) return const Text('遊戲');
                
                return Text(
                  '${game.currentWindDisplay}${game.consecutiveWins > 0 ? " 連 ${game.consecutiveWins}" : ""}',
                );
              },
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : null,
                ),
                onPressed: _toggleVoiceScoring,
                tooltip: '語音記分',
              ),
              Consumer<GameProvider>(
                builder: (context, provider, _) {
                  final game = provider.currentGame;
                  if (game == null) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.monitor),
                    tooltip: '監測模式',
                    onPressed: () => _enterMonitorMode(game),
                  );
                },
              ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'detail':
                  _showGameDetail();
                  break;
                case 'dealer':
                  _showSetDealerDialog();
                  break;
                case 'swap':
                  _showSwapDialog();
                  break;
                case 'undo':
                  _undoLastRound();
                  break;
                case 'finish':
                  _finishGame();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'detail',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('查看詳情'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'dealer',
                child: Row(
                  children: [
                    Icon(Icons.person_pin),
                    SizedBox(width: 8),
                    Text('指定莊家'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'swap',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz),
                    SizedBox(width: 8),
                    Text('換位置'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'undo',
                child: Row(
                  children: [
                    Icon(Icons.undo),
                    SizedBox(width: 8),
                    Text('還原上局'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'finish',
                child: Row(
                  children: [
                    Icon(Icons.stop),
                    SizedBox(width: 8),
                    Text('結束牌局'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
          body: Consumer<GameProvider>(
            builder: (context, provider, _) {
              final game = provider.currentGame;
              if (game == null) {
                return const Center(child: Text('沒有進行中的遊戲'));
              }

              return _buildMahjongTable(game);
            },
          ),
        ),
        
        // 語音輸入視覺反饋 overlay
        if (_isListening)
          VoiceInputOverlay(
            recognizedText: _currentRecognizedText,
            isListening: _isListening,
            onCancel: () async {
              setState(() {
                _isListening = false;
                _currentRecognizedText = '';
              });
              await _speech.stop();
            },
            onRetry: () async {
              // 重新開始語音辨識
              setState(() => _currentRecognizedText = '');
              await _speech.stop();
              await Future.delayed(const Duration(milliseconds: 300));
              _toggleVoiceScoring(); // 重新開始
            },
            onConfirm: () async {
              // 確認並處理語音輸入
              final text = _currentRecognizedText;
              setState(() {
                _isListening = false;
                _currentRecognizedText = '';
              });
              await _speech.stop();
              if (text.isNotEmpty) {
                _processVoiceInput(text);
              }
            },
          ),

        // 監測模式 badge（右下角小標示）
        if (_isMonitorMode)
          Positioned(
            right: 12,
            bottom: 20,
            child: _buildMonitorBadge(),
          ),
      ],
    );
  }

  Widget _buildMonitorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isMonitorRefreshing
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.greenAccent,
                  ),
                )
              : const Icon(Icons.sync, color: Colors.greenAccent, size: 12),
          const SizedBox(width: 5),
          Text(
            '自動更新 ${_monitorCountdown}s',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _exitMonitorMode,
            child: const Icon(Icons.close, color: Colors.white38, size: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMahjongTable(Game game) {
    final scores = game.currentScores;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 麻將桌背景
            Center(
              child: Container(
                width: constraints.maxWidth * 0.9,
                height: constraints.maxHeight * 0.7,
                decoration: BoxDecoration(
                  color: AppConstants.tableGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppConstants.tableGreen,
                    width: 4,
                  ),
                ),
              ),
            ),

            // 中央快速功能按鈕（垂直排列）
            Center(
              child: Builder(
                builder: (context) {
                  final centerScale = math.min(1.0, constraints.maxWidth / 400);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCenterButton(
                        icon: Icons.nature,
                        label: '流局',
                        onTap: _showDrawDialog,
                        scale: centerScale,
                      ),
                      SizedBox(height: 8 * centerScale),
                      _buildCenterButton(
                        icon: Icons.whatshot,
                        label: '一炮多響',
                        onTap: _showMultiWinDialog,
                        scale: centerScale,
                      ),
                      SizedBox(height: 8 * centerScale),
                      _buildCenterButton(
                        icon: Icons.casino,
                        label: '數位骰子',
                        onTap: _showDiceDialog,
                        scale: centerScale,
                      ),
                    ],
                  );
                },
              ),
            ),

            // 四個玩家位置
            ..._buildPlayerPositions(game, scores, constraints),
          ],
        );
      },
    );
  }

  List<Widget> _buildPlayerPositions(
    Game game,
    Map<String, int> scores,
    BoxConstraints constraints,
  ) {
    final players = game.players;
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;
    
    // 偵測橫向模式
    final isLandscape = constraints.maxWidth > constraints.maxHeight;
    
    // 響應式卡片寬度：手機窄螢幕自動縮小
    final cardWidth = math.min(constraints.maxWidth * 0.28, 150.0);
    final scaleFactor = cardWidth / 150.0;
    
    // 響應式半徑：橫向模式時增加水平半徑，避免蓋住中央按鈕
    final radiusX = isLandscape 
        ? math.max(cardWidth * 1.2, constraints.maxWidth * 0.35)
        : cardWidth * 0.6;
    final radiusY = isLandscape
        ? math.max(cardWidth * 0.8, constraints.maxHeight * 0.35)
        : constraints.maxHeight * 0.33 * 0.6;
    
    final halfCard = cardWidth * 0.5;
    final cardHeight = cardWidth * 1.2;
    
    // 最小邊距 6px（手機版最小值）
    const minMargin = 6.0;

    return List.generate(4, (index) {
      final player = players[index];
      final score = scores[player.id] ?? 0;
      final isDealer = game.dealerSeat == index;

      // 風位標籤：相對於起莊座位計算（整個將都不變）
      final startDealer = game.currentJiang?.startDealerSeat ?? 0;
      final windPos = (index - startDealer + 4) % 4;

      // 用 index（固定座位）決定螢幕位置和風位標籤
      double left, top;
      switch (index) {
        case 0: // 座位0（右）
          left = centerX + radiusX;
          top = centerY - halfCard;
          break;
        case 1: // 座位1（上）
          left = centerX - halfCard;
          top = centerY - radiusY - cardHeight;
          break;
        case 2: // 座位2（左）
          left = centerX - cardWidth - radiusX;
          top = centerY - halfCard;
          break;
        case 3: // 座位3（下）
          left = centerX - halfCard;
          top = centerY + radiusY - cardHeight * 0.1;
          break;
        default:
          left = centerX;
          top = centerY;
      }

      // 確保卡片不超出邊界（使用最小邊距）
      left = left.clamp(minMargin, constraints.maxWidth - cardWidth - minMargin);
      top = top.clamp(minMargin, constraints.maxHeight - cardHeight - minMargin);

      return Positioned(
        left: left,
        top: top,
        child: _buildPlayerCard(
          player: player,
          score: score,
          windIndex: windPos,
          isDealer: isDealer,
          consecutiveWins: isDealer ? game.consecutiveWins : 0,
          onTap: () => _showPlayerActionDialog(player),
          cardWidth: cardWidth,
          scaleFactor: scaleFactor,
        ),
      );
    });
  }

  Widget _buildPlayerCard({
    required Player player,
    required int score,
    required int windIndex,
    required bool isDealer,
    required int consecutiveWins,
    required VoidCallback onTap,
    double cardWidth = 150.0,
    double scaleFactor = 1.0,
  }) {
    final s = scaleFactor;
    // 手機上文字需要更大，加入補償係數
    final textScale = math.max(1.0, 1.2 - scaleFactor * 0.3);
    
    return TapScaleWrapper(
      onTap: onTap,
      child: Card(
        elevation: 4,
        color: isDealer ? AppConstants.dealerColor.withValues(alpha: 0.12) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * s),
          side: isDealer
              ? const BorderSide(color: AppConstants.dealerColor, width: 2)
              : BorderSide.none,
        ),
        child: Container(
          width: cardWidth,
          padding: EdgeInsets.all(12 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 風位 + 莊家標示
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppConstants.windNames[windIndex],
                    style: TextStyle(
                      fontSize: 18 * s * textScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  if (isDealer) ...[
                    SizedBox(width: 4 * s),
                    Text(
                      '莊',
                      style: TextStyle(
                        fontSize: 16 * s * textScale,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.dealerColor,
                      ),
                    ),
                    if (consecutiveWins > 0)
                      Text(
                        ' 連$consecutiveWins',
                        style: TextStyle(
                          fontSize: 16 * s * textScale,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.dealerColor,
                        ),
                      ),
                  ],
                ],
              ),

              SizedBox(height: 8 * s),

              // Emoji
              Text(
                player.emoji,
                style: TextStyle(fontSize: 38 * s * textScale),
              ),

              SizedBox(height: 4 * s),

              // 名稱
              Text(
                player.name,
                style: TextStyle(
                  fontSize: 18 * s * textScale,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 8 * s),

              // 分數（動畫）
              AnimatedScoreText(
                score: score,
                style: TextStyle(
                  fontSize: 48 * s * textScale,
                  fontWeight: FontWeight.bold,
                  color: score > 0
                      ? AppConstants.winColor
                      : score < 0
                          ? AppConstants.loseColor
                          : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double scale = 1.0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TapScaleWrapper(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20 * scale),
          border: Border.all(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18 * scale,
              color: isDark ? Colors.grey.shade200 : Colors.grey.shade700,
            ),
            SizedBox(width: 4 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameDetail() {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(game: game),
      ),
    );
  }

  /// 切換語音記分狀態
  void _toggleVoiceScoring() async {
    if (_isListening) {
      // 停止錄音
      setState(() {
        _isListening = false;
        _currentRecognizedText = '';
      });
      await _speech.stop();
    } else {
      // 首次使用：顯示說明對話框
      if (!_hasShownVoicePermissionInfo) {
        final shouldContinue = await _showVoicePermissionInfo();
        if (!shouldContinue) return;
        setState(() => _hasShownVoicePermissionInfo = true);
      }

      // 開始錄音
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
            _currentRecognizedText = '';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('語音辨識錯誤: ${error.errorMsg}')),
            );
          }
        },
      );

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('語音辨識功能不可用')),
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
        _currentRecognizedText = '';
      });

      await _speech.listen(
        onResult: (result) {
          // 即時更新辨識文字
          setState(() {
            _currentRecognizedText = result.recognizedWords;
          });

          // 不在這裡自動處理，等使用者點擊「確認」
        },
        localeId: 'zh_TW',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    }
  }

  /// 顯示語音權限說明對話框
  Future<bool> _showVoicePermissionInfo() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('語音記分功能'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📢 功能說明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '使用語音記分可以快速記錄牌局結果，說出：\n'
                '• 「小明胡阿華5台」\n'
                '• 「莊家自摸3台」\n'
                '系統會自動辨識並開啟記分視窗。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '提高辨識準確度',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '建議玩家名稱使用繁體中文，可以大幅提升語音辨識的準確率。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🔒 隱私說明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '語音辨識在您的裝置上進行，不會將錄音上傳到伺服器。首次使用需要授予麥克風權限。',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('開始使用'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// 處理語音輸入
  void _processVoiceInput(String text) {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;

    if (game == null) return;

    // 解析語音指令
    final result = VoiceScoringService.parse(text, game);

    if (result.isValid) {
      // 解析成功，開啟快速記分對話框並預填
      showDialog(
        context: context,
        builder: (context) => QuickScoreDialog(
          game: game,
          selectedPlayer: result.winner!,
          prefillLoser: result.loser,
          prefillSelfDraw: result.isSelfDraw,
          prefillTai: result.tai,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('辨識成功：${result.recognizedText}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // 解析失敗，顯示錯誤或部分結果
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('語音辨識'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('辨識文字：${result.recognizedText}'),
                const SizedBox(height: 8),
                if (result.error != null)
                  Text(
                    '錯誤：${result.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '支援格式：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• 胡牌：「小明胡阿華5台」'),
                const Text('• 自摸：「莊家自摸3台」'),
                const Text('• 支援風位：東家、南家、西家、北家'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
              if (result.winner != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => QuickScoreDialog(
                        game: game,
                        selectedPlayer: result.winner!,
                        prefillLoser: result.loser,
                        prefillSelfDraw: result.isSelfDraw,
                        prefillTai: result.tai,
                      ),
                    );
                  },
                  child: const Text('手動調整'),
                ),
            ],
          ),
        );
      }
    }
  }

  void _showPlayerActionDialog(Player player) {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null) return;
    
    showDialog(
      context: context,
      builder: (context) => QuickScoreDialog(
        game: game,
        selectedPlayer: player,
      ),
    );
  }

  void _showMultiWinDialog() {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null) return;
    
    showDialog(
      context: context,
      builder: (context) => MultiWinDialog(game: game),
    );
  }

  void _showDrawDialog() {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null) return;
    
    showDialog(
      context: context,
      builder: (context) => DrawDialog(game: game),
    );
  }

  void _showDiceDialog() {
    showDialog(
      context: context,
      builder: (context) => const _DiceDialog(),
    );
  }

  void _showSetDealerDialog() {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;

    if (game == null) return;

    showDialog(
      context: context,
      builder: (context) => _SetDealerDialog(game: game),
    );
  }

  void _showSwapDialog() {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null) return;
    
    showDialog(
      context: context,
      builder: (context) => SwapPositionDialog(game: game),
    );
  }

  Future<void> _undoLastRound() async {
    final provider = context.read<GameProvider>();
    final game = provider.currentGame;
    
    if (game == null || game.rounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可還原的紀錄')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認還原'),
        content: const Text('確定要還原上一局嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.undoLastRound();
    }
  }

  Future<void> _finishGame() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('結束牌局'),
        content: const Text('確定要結束當前牌局嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<GameProvider>().finishGame();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// 胡牌對話框
class _WinDialog extends StatefulWidget {
  final Game game;
  final Player winner;

  const _WinDialog({required this.game, required this.winner});

  @override
  State<_WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<_WinDialog> {
  Player? _loser;
  int _tai = 0;
  int _flowers = 0;

  @override
  Widget build(BuildContext context) {
    final losers = widget.game.players
        .where((p) => p.id != widget.winner.id)
        .toList();

    final provider = context.read<GameProvider>();
    final settings = widget.game.settings;
    
    return AlertDialog(
      title: Text('${widget.winner.emoji} ${widget.winner.name} 胡牌'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('誰放槍？', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: losers.map((player) {
                return ChoiceChip(
                  label: Text('${player.emoji} ${player.name}'),
                  selected: _loser == player,
                  onSelected: (selected) {
                    setState(() {
                      _loser = selected ? player : null;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            const Text('台數：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.commonTai.map((tai) {
                return ChoiceChip(
                  label: Text('$tai 台'),
                  selected: _tai == tai,
                  onSelected: (selected) {
                    setState(() {
                      _tai = tai;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '自訂台數',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _tai = parsed;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花牌',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: _flowers.toString()),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _flowers = parsed;
                  });
                }
              },
            ),
            
            if (_loser != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  CalculationService.getScorePreview(
                    settings: settings,
                    tai: _tai,
                    flowers: _flowers,
                    isSelfDraw: false,
                    isDealer: (widget.winner.id == widget.game.dealer.id || _loser!.id == widget.game.dealer.id),
                    consecutiveWins: widget.game.consecutiveWins,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _loser == null ? null : () async {
            await provider.recordWin(
              winnerId: widget.winner.id,
              loserId: _loser!.id,
              tai: _tai,
              flowers: _flowers,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}

// 自摸對話框
class _SelfDrawDialog extends StatefulWidget {
  final Game game;
  final Player winner;

  const _SelfDrawDialog({required this.game, required this.winner});

  @override
  State<_SelfDrawDialog> createState() => _SelfDrawDialogState();
}

class _SelfDrawDialogState extends State<_SelfDrawDialog> {
  int _tai = 0;
  int _flowers = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    final settings = widget.game.settings;
    
    return AlertDialog(
      title: Text('${widget.winner.emoji} ${widget.winner.name} 自摸'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('台數：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.commonTai.map((tai) {
                return ChoiceChip(
                  label: Text('$tai 台'),
                  selected: _tai == tai,
                  onSelected: (selected) {
                    setState(() {
                      _tai = tai;
                    });
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '自訂台數',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _tai = parsed;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花牌',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: _flowers.toString()),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _flowers = parsed;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                CalculationService.getScorePreview(
                  settings: settings,
                  tai: _tai,
                  flowers: _flowers,
                  isSelfDraw: true,
                  isDealer: (widget.winner.id == widget.game.dealer.id),
                  consecutiveWins: widget.game.consecutiveWins,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            await provider.recordSelfDraw(
              winnerId: widget.winner.id,
              tai: _tai,
              flowers: _flowers,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}

// 骰子滾動動畫對話框
class _DiceDialog extends StatefulWidget {
  const _DiceDialog();

  @override
  State<_DiceDialog> createState() => _DiceDialogState();
}

class _DiceDialogState extends State<_DiceDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();

  int _displayDice1 = 1;
  int _displayDice2 = 1;
  int _displayDice3 = 1;
  late int _finalDice1;
  late int _finalDice2;
  late int _finalDice3;
  bool _isRolling = true;

  @override
  void initState() {
    super.initState();
    _finalDice1 = _random.nextInt(6) + 1;
    _finalDice2 = _random.nextInt(6) + 1;
    _finalDice3 = _random.nextInt(6) + 1;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.addListener(_onAnimationUpdate);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isRolling = false;
          _displayDice1 = _finalDice1;
          _displayDice2 = _finalDice2;
          _displayDice3 = _finalDice3;
        });
      }
    });

    _controller.forward();
  }

  void _onAnimationUpdate() {
    final progress = _controller.value;
    if (progress < 0.8) {
      setState(() {
        _displayDice1 = _random.nextInt(6) + 1;
        _displayDice2 = _random.nextInt(6) + 1;
        _displayDice3 = _random.nextInt(6) + 1;
      });
    }
  }

  void _reroll() {
    setState(() {
      _isRolling = true;
      _finalDice1 = _random.nextInt(6) + 1;
      _finalDice2 = _random.nextInt(6) + 1;
      _finalDice3 = _random.nextInt(6) + 1;
    });
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎲 電子骰子'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedDice(_displayDice1),
              const SizedBox(width: 12),
              _buildAnimatedDice(_displayDice2),
              const SizedBox(width: 12),
              _buildAnimatedDice(_displayDice3),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _isRolling ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              '合計：${_finalDice1 + _finalDice2 + _finalDice3}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _reroll,
          child: const Text('再擲一次'),
        ),
        ElevatedButton(
          onPressed: _isRolling ? null : () => Navigator.pop(context),
          child: const Text('確定'),
        ),
      ],
    );
  }

  Widget _buildAnimatedDice(int value) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shakeOffset = _isRolling
            ? math.sin(_controller.value * 20 * math.pi) *
                3 *
                (1 - _controller.value)
            : 0.0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Image.asset(
            'assets/images/dice-$value.png',
            width: 52,
            height: 52,
          ),
        );
      },
    );
  }
}

// 指定莊家對話框
class _SetDealerDialog extends StatefulWidget {
  final Game game;

  const _SetDealerDialog({required this.game});

  @override
  State<_SetDealerDialog> createState() => _SetDealerDialogState();
}

class _SetDealerDialogState extends State<_SetDealerDialog> {
  late int _selectedDealer;
  bool _resetConsecutiveWins = true;
  bool _recalculateWind = false;

  @override
  void initState() {
    super.initState();
    _selectedDealer = widget.game.dealerSeat;
  }

  @override
  Widget build(BuildContext context) {
    // 計算每個玩家在選定莊家時的風位預覽
    String windLabel(int playerIndex) {
      final windPos = (playerIndex - _selectedDealer + 4) % 4;
      return AppConstants.windNames[windPos];
    }

    return AlertDialog(
      title: const Text('指定莊家'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('選擇新莊家：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(4, (index) {
                final player = widget.game.players[index];
                final isSelected = _selectedDealer == index;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(player.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(player.name),
                      Text(' (${windLabel(index)})',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDealer = index;
                    });
                  },
                );
              }),
            ),

            if (_recalculateWind) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '所選玩家將成為東家，風圈重置為東風',
                        style: TextStyle(color: Colors.amber.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('重置連莊數'),
              subtitle: const Text('連莊數歸零'),
              value: _resetConsecutiveWins,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() => _resetConsecutiveWins = value);
              },
            ),

            SwitchListTile(
              title: const Text('重新計算圈風'),
              subtitle: const Text('風圈重置為東風'),
              value: _recalculateWind,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() => _recalculateWind = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final provider = context.read<GameProvider>();
            await provider.setDealer(
              dealerSeat: _selectedDealer,
              resetConsecutiveWins: _resetConsecutiveWins,
              recalculateWind: _recalculateWind,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('確認'),
        ),
      ],
    );
  }

}
