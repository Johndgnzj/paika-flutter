import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/game.dart';
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

  final _uuid = const Uuid();

  Game? get currentGame => _currentGame;
  List<Game> get gameHistory => _gameHistory;
  GameSettings get settings => _settings;
  List<Player> get savedPlayers => _savedPlayers;
  ThemeMode get themeMode => _themeMode;

  /// 初始化（載入資料）
  Future<void> initialize() async {
    _settings = await StorageService.loadSettings();
    _savedPlayers = await StorageService.loadPlayers();
    _gameHistory = await StorageService.loadGames();
    _currentGame = await StorageService.loadCurrentGame();
    final themeModeStr = await StorageService.loadThemeMode();
    _themeMode = _parseThemeMode(themeModeStr);
    notifyListeners();
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
  }) async {
    if (players.length != 4) {
      throw ArgumentError('需要4位玩家');
    }

    _currentGame = Game(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      settings: customSettings ?? _settings,
      players: players,
      status: GameStatus.playing,
    );

    await StorageService.saveCurrentGame(_currentGame!);
    notifyListeners();
  }

  /// 記錄胡牌（放槍）
  Future<void> recordWin({
    required String winnerId,
    required String loserId,
    required int tai,
    required int flowers,
  }) async {
    if (_currentGame == null) return;

    final scoreChanges = CalculationService.calculateWin(
      game: _currentGame!,
      winnerId: winnerId,
      loserId: loserId,
      tai: tai,
      flowers: flowers,
    );

    final round = Round(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      wind: _currentGame!.currentWind,
      sequence: _currentGame!.currentSequence,
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
      timestamp: DateTime.now(),
      wind: _currentGame!.currentWind,
      sequence: _currentGame!.currentSequence,
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

    final scoreChanges = CalculationService.calculateFalseWin(
      game: _currentGame!,
      falserId: falserId,
    );

    final round = Round(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      wind: _currentGame!.currentWind,
      sequence: _currentGame!.currentSequence,
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
      timestamp: DateTime.now(),
      wind: _currentGame!.currentWind,
      sequence: _currentGame!.currentSequence,
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

    _currentGame = _currentGame!.copyWith(status: GameStatus.finished);
    await StorageService.saveCurrentGame(_currentGame!);
    await StorageService.clearCurrentGame();
    
    _gameHistory.insert(0, _currentGame!);
    _currentGame = null;
    
    notifyListeners();
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
