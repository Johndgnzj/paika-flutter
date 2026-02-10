import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../models/big_round.dart';
import '../models/settings.dart';
import '../services/calculation_service.dart';
import '../services/storage_service.dart';

/// 遊戲狀態管理
class GameProvider with ChangeNotifier {
  Game? _currentGame;
  List<Game> _gameHistory = [];
  GameSettings _settings = const GameSettings();
  List<Player> _savedPlayers = [];
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;
  String? _error;

  final _uuid = const Uuid();

  Game? get currentGame => _currentGame;
  List<Game> get gameHistory => _gameHistory;
  GameSettings get settings => _settings;
  List<Player> get savedPlayers => _savedPlayers;
  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 初始化（載入資料）
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    try {
      _settings = await StorageService.loadSettings();
      _savedPlayers = await StorageService.loadPlayers();
      _gameHistory = await StorageService.loadGames();
      _currentGame = await StorageService.loadCurrentGame();
      final themeModeStr = await StorageService.loadThemeMode();
      _themeMode = _parseThemeMode(themeModeStr);
    } catch (e) {
      _error = '載入資料失敗：$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// 建立新遊戲
  Future<void> createGame({
    required List<Player> players,
    GameSettings? customSettings,
    int startDealerPos = 0,
  }) async {
    if (players.length != 4) {
      throw ArgumentError('需要4位玩家');
    }

    try {
      // 創建第一個 BigRound（第一將）
      final firstBigRound = BigRound(
        id: 'br_${DateTime.now().millisecondsSinceEpoch}',
        jiangNumber: 1,
        seatOrder: players.map((p) => p.id).toList(),
        startDealerPos: startDealerPos,
        startTime: DateTime.now(),
      );

      _currentGame = Game(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        settings: customSettings ?? _settings,
        players: players,
        bigRounds: [firstBigRound],
        currentBigRoundId: firstBigRound.id,
        status: GameStatus.playing,
        dealerIndex: startDealerPos,
      );

      await StorageService.saveCurrentGame(_currentGame!);
      notifyListeners();
    } catch (e) {
      _error = '建立遊戲失敗：$e';
      notifyListeners();
      rethrow;
    }
  }

  /// 記錄胡牌（放槍）
  Future<void> recordWin({
    required String winnerId,
    required String loserId,
    required int tai,
    required int flowers,
  }) async {
    if (_currentGame == null) return;

    try {
      final scoreChanges = CalculationService.calculateWin(
        game: _currentGame!,
        winnerId: winnerId,
        loserId: loserId,
        tai: tai,
        flowers: flowers,
      );

      final round = Round(
        id: _uuid.v4(),
        bigRoundId: _currentGame!.currentBigRoundId,
        timestamp: DateTime.now(),
        type: RoundType.win,
        winnerId: winnerId,
        loserId: loserId,
        tai: tai,
        flowers: flowers,
        scoreChanges: scoreChanges,
        wind: _currentGame!.currentWind,
        dealerPos: _currentGame!.dealerIndex,
        consecutiveWins: _currentGame!.consecutiveWins,
      );

      _currentGame = _currentGame!.addRound(round);
      await StorageService.saveCurrentGame(_currentGame!);
      notifyListeners();
    } catch (e) {
      _error = '記錄失敗：$e';
      notifyListeners();
      rethrow;
    }
  }

  /// 記錄自摸
  Future<void> recordSelfDraw({
    required String winnerId,
    required int tai,
    required int flowers,
  }) async {
    if (_currentGame == null) return;

    final scoreChanges = CalculationService.calculateSelfDraw(
      game: _currentGame!,
      winnerId: winnerId,
      tai: tai,
      flowers: flowers,
    );

    final round = Round(
      id: _uuid.v4(),
      bigRoundId: _currentGame!.currentBigRoundId,
      timestamp: DateTime.now(),
      type: RoundType.selfDraw,
      winnerId: winnerId,
      tai: tai,
      flowers: flowers,
      scoreChanges: scoreChanges,
      wind: _currentGame!.currentWind,
      dealerPos: _currentGame!.dealerIndex,
      consecutiveWins: _currentGame!.consecutiveWins,
    );

    _currentGame = _currentGame!.addRound(round);
    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 記錄詐胡
  Future<void> recordFalseWin({
    required String falserId,
  }) async {
    if (_currentGame == null) return;

    final scoreChanges = CalculationService.calculateFalseWin(
      game: _currentGame!,
      falserId: falserId,
    );

    final round = Round(
      id: _uuid.v4(),
      bigRoundId: _currentGame!.currentBigRoundId,
      timestamp: DateTime.now(),
      type: RoundType.falseWin,
      loserId: falserId,
      tai: _currentGame!.settings.falseWinTai,
      scoreChanges: scoreChanges,
      wind: _currentGame!.currentWind,
      dealerPos: _currentGame!.dealerIndex,
      consecutiveWins: _currentGame!.consecutiveWins,
    );

    _currentGame = _currentGame!.addRound(round);
    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 記錄一炮多響
  Future<void> recordMultiWin({
    required List<String> winnerIds,
    required String loserId,
    required Map<String, int> taiMap,
    required Map<String, int> flowerMap,
  }) async {
    if (_currentGame == null) return;

    final scoreChanges = CalculationService.calculateMultiWin(
      game: _currentGame!,
      winnerIds: winnerIds,
      loserId: loserId,
      taiMap: taiMap,
      flowerMap: flowerMap,
    );

    // 使用第一個贏家的台數作為代表（實際可以改進）
    final primaryTai = taiMap[winnerIds.first] ?? 0;

    final round = Round(
      id: _uuid.v4(),
      bigRoundId: _currentGame!.currentBigRoundId,
      timestamp: DateTime.now(),
      type: RoundType.multiWin,
      winnerIds: winnerIds,
      loserId: loserId,
      tai: primaryTai,
      scoreChanges: scoreChanges,
      wind: _currentGame!.currentWind,
      dealerPos: _currentGame!.dealerIndex,
      consecutiveWins: _currentGame!.consecutiveWins,
    );

    _currentGame = _currentGame!.addRound(round);
    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 還原上一局
  Future<void> undoLastRound() async {
    if (_currentGame == null || _currentGame!.rounds.isEmpty) return;

    _currentGame = _currentGame!.undoLastRound();
    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 結束遊戲
  Future<void> finishGame() async {
    if (_currentGame == null) return;

    try {
      _currentGame = _currentGame!.copyWith(status: GameStatus.finished);
      await StorageService.saveCurrentGame(_currentGame!);
      await StorageService.clearCurrentGame();

      _gameHistory.insert(0, _currentGame!);
      _currentGame = null;

      notifyListeners();
    } catch (e) {
      _error = '結束遊戲失敗：$e';
      notifyListeners();
      rethrow;
    }
  }

  /// 更換玩家位置
  Future<void> swapPlayers(int index1, int index2) async {
    if (_currentGame == null) return;
    if (index1 < 0 || index1 >= 4 || index2 < 0 || index2 >= 4) return;

    final players = List<Player>.from(_currentGame!.players);
    final temp = players[index1];
    players[index1] = players[index2];
    players[index2] = temp;

    _currentGame = _currentGame!.copyWith(players: players);
    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 指定莊家
  Future<void> setDealer({
    required int dealerIndex,
    required bool resetConsecutiveWins,
    required bool recalculateWind,
  }) async {
    if (_currentGame == null) return;
    if (dealerIndex < 0 || dealerIndex >= 4) return;

    Wind newWind = _currentGame!.currentWind;
    List<BigRound> newBigRounds = _currentGame!.bigRounds;
    String newBigRoundId = _currentGame!.currentBigRoundId;
    
    if (recalculateWind) {
      // 重新計算風圈，重置為東風
      // 這表示進入新的一將，創建新的 BigRound
      newWind = Wind.east;
      final currentBR = _currentGame!.currentBigRound;
      final newBR = BigRound(
        id: 'br_${DateTime.now().millisecondsSinceEpoch}',
        jiangNumber: (currentBR?.jiangNumber ?? 0) + 1,
        seatOrder: _currentGame!.players.map((p) => p.id).toList(),
        startDealerPos: dealerIndex,
        startTime: DateTime.now(),
      );
      
      // 結束當前 BigRound
      newBigRounds = [
        ..._currentGame!.bigRounds.map((br) => br.id == newBigRoundId 
            ? br.copyWith(endTime: DateTime.now()) 
            : br),
        newBR,
      ];
      newBigRoundId = newBR.id;
    }

    _currentGame = _currentGame!.copyWith(
      dealerIndex: dealerIndex,
      consecutiveWins: resetConsecutiveWins ? 0 : _currentGame!.consecutiveWins,
      currentWind: recalculateWind ? newWind : _currentGame!.currentWind,
      bigRounds: newBigRounds,
      currentBigRoundId: newBigRoundId,
    );

    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 更新設定
  Future<void> updateSettings(GameSettings newSettings) async {
    _settings = newSettings;
    await StorageService.saveSettings(newSettings);
    notifyListeners();
  }

  /// 更新主題模式
  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await StorageService.saveThemeMode(_themeModeToString(mode));
    notifyListeners();
  }

  /// 儲存常用玩家
  Future<void> savePlayers(List<Player> players) async {
    _savedPlayers = players;
    await StorageService.savePlayers(players);
    notifyListeners();
  }

  /// 清除當前遊戲
  Future<void> clearCurrentGame() async {
    _currentGame = null;
    await StorageService.clearCurrentGame();
    notifyListeners();
  }

  /// 記錄自訂 Round（用於流局等特殊情況）
  Future<void> recordCustomRound(Round round) async {
    if (_currentGame == null) return;

    _currentGame = _currentGame!.addRound(round);
    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 更換莊家
  Future<void> changeDealer(
    int newDealerIndex, {
    bool resetConsecutiveWins = true,
    bool recalculateWind = false,
  }) async {
    if (_currentGame == null) return;
    if (newDealerIndex < 0 || newDealerIndex >= 4) return;

    // 更新莊家
    _currentGame = _currentGame!.copyWith(
      dealerIndex: newDealerIndex,
      consecutiveWins: resetConsecutiveWins ? 0 : _currentGame!.consecutiveWins,
    );

    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }
}
