import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/jiang.dart';
import '../models/player.dart';
import '../models/round.dart';
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
      _currentGame = Game(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        settings: customSettings ?? _settings,
        players: players,
        status: GameStatus.playing,
        dealerSeat: startDealerPos,
        dealerPassCount: 0,
        consecutiveWins: 0,
        initialDealerSeat: startDealerPos,
      );

      await StorageService.saveCurrentGame(_currentGame!);
      notifyListeners();
    } catch (e) {
      _error = '建立遊戲失敗：$e';
      notifyListeners();
      rethrow;
    }
  }

  /// 確保當前將存在（自動建立邏輯）
  void _ensureCurrentJiang() {
    if (_currentGame == null) return;

    // 推論應該是第幾將
    final expectedJiangNumber = (_currentGame!.dealerPassCount ~/ 16) + 1;

    // 檢查是否需要建立新的 Jiang
    if (_currentGame!.currentJiang == null ||
        _currentGame!.currentJiang!.jiangNumber != expectedJiangNumber) {
      // 自動建立新的 Jiang
      final newJiang = Jiang(
        id: _uuid.v4(),
        gameId: _currentGame!.id,
        jiangNumber: expectedJiangNumber,
        seatOrder: _currentGame!.players.map((p) => p.id).toList(),
        startDealerSeat: _currentGame!.dealerSeat,
        startDealerPassCount: _currentGame!.dealerPassCount,
        startTime: DateTime.now(),
      );

      // 如果有前一將，標記為已結束
      final updatedJiangs = List<Jiang>.from(_currentGame!.jiangs);
      if (updatedJiangs.isNotEmpty) {
        final lastIndex = updatedJiangs.length - 1;
        updatedJiangs[lastIndex] = updatedJiangs[lastIndex].copyWith(
          endTime: DateTime.now(),
        );
      }

      // 加入新將
      updatedJiangs.add(newJiang);

      _currentGame = _currentGame!.copyWith(jiangs: updatedJiangs);
    }
  }

  /// 建立 Round 快照（共用邏輯）
  Round _createRound({
    required RoundType type,
    String? winnerId,
    List<String> winnerIds = const [],
    String? loserId,
    required int tai,
    int flowers = 0,
    required Map<String, int> scoreChanges,
    String? notes,
  }) {
    return Round(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: type,
      winnerId: winnerId,
      winnerIds: winnerIds,
      loserId: loserId,
      tai: tai,
      flowers: flowers,
      scoreChanges: scoreChanges,
      dealerPassCount: _currentGame!.dealerPassCount,
      dealerSeat: _currentGame!.dealerSeat,
      consecutiveWins: _currentGame!.consecutiveWins,
      jiangNumber: _currentGame!.jiangNumber,
      notes: notes,
    );
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
      // 確保當前將存在
      _ensureCurrentJiang();

      final scoreChanges = CalculationService.calculateWin(
        game: _currentGame!,
        winnerId: winnerId,
        loserId: loserId,
        tai: tai,
        flowers: flowers,
      );

      final round = _createRound(
        type: RoundType.win,
        winnerId: winnerId,
        loserId: loserId,
        tai: tai,
        flowers: flowers,
        scoreChanges: scoreChanges,
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

    // 確保當前將存在
    _ensureCurrentJiang();

    final scoreChanges = CalculationService.calculateSelfDraw(
      game: _currentGame!,
      winnerId: winnerId,
      tai: tai,
      flowers: flowers,
    );

    final round = _createRound(
      type: RoundType.selfDraw,
      winnerId: winnerId,
      tai: tai,
      flowers: flowers,
      scoreChanges: scoreChanges,
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

    // 確保當前將存在
    _ensureCurrentJiang();

    final scoreChanges = CalculationService.calculateFalseWin(
      game: _currentGame!,
      falserId: falserId,
    );

    final round = _createRound(
      type: RoundType.falseWin,
      loserId: falserId,
      tai: _currentGame!.settings.falseWinTai,
      scoreChanges: scoreChanges,
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

    // 確保當前將存在
    _ensureCurrentJiang();

    final scoreChanges = CalculationService.calculateMultiWin(
      game: _currentGame!,
      winnerIds: winnerIds,
      loserId: loserId,
      taiMap: taiMap,
      flowerMap: flowerMap,
    );

    // 使用第一個贏家的台數作為代表
    final primaryTai = taiMap[winnerIds.first] ?? 0;

    final round = _createRound(
      type: RoundType.multiWin,
      winnerIds: winnerIds,
      loserId: loserId,
      tai: primaryTai,
      scoreChanges: scoreChanges,
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

  /// 更換玩家位置（記錄事件，供 undo 使用）
  Future<void> swapPlayers(int seat1, int seat2) async {
    if (_currentGame == null) return;
    if (seat1 < 0 || seat1 >= 4 || seat2 < 0 || seat2 >= 4) return;

    // 記錄事件
    final event = GameEvent(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: GameEventType.swapPlayers,
      data: {'seat1': seat1, 'seat2': seat2},
      afterRoundIndex: _currentGame!.rounds.length - 1,
    );

    final players = List<Player>.from(_currentGame!.players);
    final temp = players[seat1];
    players[seat1] = players[seat2];
    players[seat2] = temp;

    // 如果莊家在被交換的座位上，dealerSeat 跟著動
    int newDealerSeat = _currentGame!.dealerSeat;
    if (newDealerSeat == seat1) {
      newDealerSeat = seat2;
    } else if (newDealerSeat == seat2) {
      newDealerSeat = seat1;
    }

    _currentGame = _currentGame!.copyWith(
      players: players,
      dealerSeat: newDealerSeat,
      events: [..._currentGame!.events, event],
    );

    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 指定莊家（記錄事件，供 undo 使用）
  Future<void> setDealer({
    required int dealerSeat,
    required bool resetConsecutiveWins,
    required bool recalculateWind,
  }) async {
    if (_currentGame == null) return;
    if (dealerSeat < 0 || dealerSeat >= 4) return;

    // 記錄事件
    final event = GameEvent(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: GameEventType.setDealer,
      data: {
        'oldDealerSeat': _currentGame!.dealerSeat,
        'oldDealerPassCount': _currentGame!.dealerPassCount,
        'oldConsecutiveWins': _currentGame!.consecutiveWins,
        'newDealerSeat': dealerSeat,
        'recalculateWind': recalculateWind,
      },
      afterRoundIndex: _currentGame!.rounds.length - 1,
    );

    int passCount = _currentGame!.dealerPassCount;
    if (recalculateWind) {
      // 進入下一將的東風東局（不是回到第一將）
      passCount = ((passCount ~/ 16) + 1) * 16;
    }

    _currentGame = _currentGame!.copyWith(
      dealerSeat: dealerSeat,
      dealerPassCount: passCount,
      consecutiveWins: resetConsecutiveWins ? 0 : _currentGame!.consecutiveWins,
      events: [..._currentGame!.events, event],
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
}
