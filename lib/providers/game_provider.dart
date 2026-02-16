import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/jiang.dart';
import '../models/player.dart';
import '../models/player_profile.dart';
import '../models/round.dart';
import '../models/settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/calculation_service.dart';
import '../services/firestore_service.dart';
import '../services/firebase_init_service.dart';
import '../services/storage_service.dart';

/// 遊戲狀態管理
class GameProvider with ChangeNotifier {
  Game? _currentGame;
  List<Game> _gameHistory = [];
  GameSettings _settings = const GameSettings();
  List<Player> _savedPlayers = [];
  List<PlayerProfile> _playerProfiles = [];
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;
  String? _error;
  String? _currentAccountId;
  String? _pendingSelfProfileName;  // 註冊時暫存，由 _initializeForAccount 統一建立

  final _uuid = const Uuid();

  Game? get currentGame => _currentGame;
  List<Game> get gameHistory => _gameHistory;
  GameSettings get settings => _settings;
  List<Player> get savedPlayers => _savedPlayers;
  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentAccountId => _currentAccountId;

  /// PlayerProfile getter（依 lastPlayedAt 降序排列）
  List<PlayerProfile> get playerProfiles {
    final sorted = List<PlayerProfile>.from(_playerProfiles);
    sorted.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return sorted;
  }

  /// 當 AuthService 狀態變化時呼叫
  void onAuthChanged(AuthService authService) {
    final newAccountId = authService.uid;
    if (newAccountId != _currentAccountId) {
      _currentAccountId = newAccountId;
      if (newAccountId != null) {
        _initializeForAccount(newAccountId);
      } else {
        _clearState();
      }
    }
  }

  /// 為指定帳號初始化資料
  Future<void> _initializeForAccount(String accountId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 遷移舊資料
      await StorageService.migrateOrphanGames(accountId);

      // 啟用雲端同步並從 Firestore 拉取最新資料
      if (FirebaseInitService.isInitialized) {
        StorageService.enableCloud();
        final user = FirebaseAuth.instance.currentUser;
        await FirestoreService.saveUserProfile(
          user?.displayName ?? '',
          user?.email ?? '',
        );
        await StorageService.syncFromCloud(accountId: accountId);
      }

      _settings = await StorageService.loadSettings(accountId: accountId);
      _savedPlayers = await StorageService.loadPlayers(accountId: accountId);
      _gameHistory = await StorageService.loadGames(accountId: accountId);
      _currentGame = await StorageService.loadCurrentGame(accountId: accountId);
      _playerProfiles = await StorageService.loadPlayerProfiles(accountId: accountId);

      // 1. 處理註冊時暫存的自己玩家檔案
      if (_pendingSelfProfileName != null && _pendingSelfProfileName!.isNotEmpty) {
        final name = _pendingSelfProfileName!;
        _pendingSelfProfileName = null;
        if (!_playerProfiles.any((p) => p.name == name)) {
          await addPlayerProfile(name, '🀄', isSelf: true);
        }
      }

      // 2. 舊帳號自動辨識「自己」：若沒有任何 isSelf，用 displayName 比對
      if (_playerProfiles.isNotEmpty && !_playerProfiles.any((p) => p.isSelf)) {
        final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
        if (displayName.isNotEmpty) {
          final index = _playerProfiles.indexWhere((p) => p.name == displayName);
          if (index >= 0) {
            _playerProfiles[index] = _playerProfiles[index].copyWith(isSelf: true);
            await StorageService.savePlayerProfile(_playerProfiles[index], accountId: accountId);
          }
        }
      }

      final themeModeStr = await StorageService.loadThemeMode();
      _themeMode = _parseThemeMode(themeModeStr);
    } catch (e) {
      _error = '載入資料失敗：$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearState() {
    _currentGame = null;
    _gameHistory = [];
    _settings = const GameSettings();
    _savedPlayers = [];
    _playerProfiles = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// 初始化（載入資料）— 保留向後相容（無帳號時也能載入主題）
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    try {
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

  // --- PlayerProfile 管理 ---

  /// 註冊後標記待建立的自己玩家檔案（由 _initializeForAccount 統一執行）
  void createSelfProfileAfterRegister(String displayName) {
    _pendingSelfProfileName = displayName.trim();
  }

  /// 新增玩家檔案
  Future<void> addPlayerProfile(String name, String emoji, {bool isSelf = false}) async {
    if (_currentAccountId == null) return;
    final now = DateTime.now();
    final profile = PlayerProfile(
      id: _uuid.v4(),
      accountId: _currentAccountId!,
      name: name,
      emoji: emoji,
      isSelf: isSelf,
      createdAt: now,
      lastPlayedAt: now,
    );
    _playerProfiles.add(profile);
    await StorageService.savePlayerProfile(profile, accountId: _currentAccountId!);
    notifyListeners();
  }

  /// 更新玩家檔案
  Future<void> updatePlayerProfile(String id, {String? name, String? emoji}) async {
    if (_currentAccountId == null) return;
    final index = _playerProfiles.indexWhere((p) => p.id == id);
    if (index < 0) return;

    _playerProfiles[index] = _playerProfiles[index].copyWith(
      name: name,
      emoji: emoji,
    );
    await StorageService.savePlayerProfile(_playerProfiles[index], accountId: _currentAccountId!);
    notifyListeners();
  }

  /// 刪除玩家檔案
  Future<void> deletePlayerProfile(String id) async {
    if (_currentAccountId == null) return;
    _playerProfiles.removeWhere((p) => p.id == id);
    await StorageService.deletePlayerProfile(id, accountId: _currentAccountId!);
    notifyListeners();
  }

  /// 載入玩家檔案
  Future<void> loadPlayerProfiles() async {
    if (_currentAccountId == null) return;
    _playerProfiles = await StorageService.loadPlayerProfiles(accountId: _currentAccountId!);
    notifyListeners();
  }

  /// 確保牌局中的玩家都存在於玩家清單，並更新 lastPlayedAt
  Future<void> _ensurePlayersInProfiles(List<Player> players) async {
    if (_currentAccountId == null) return;
    final now = DateTime.now();
    for (final player in players) {
      int index = -1;

      // 先用 userId 查找
      if (player.userId != null) {
        index = _playerProfiles.indexWhere((p) => p.id == player.userId);
      }
      // 再用名稱查找
      if (index < 0) {
        index = _playerProfiles.indexWhere((p) => p.name == player.name);
      }

      if (index >= 0) {
        // 已存在 → 更新 lastPlayedAt
        _playerProfiles[index] = _playerProfiles[index].copyWith(lastPlayedAt: now);
        await StorageService.savePlayerProfile(_playerProfiles[index], accountId: _currentAccountId!);
      } else {
        // 不存在 → 自動新增
        final profile = PlayerProfile(
          id: _uuid.v4(),
          accountId: _currentAccountId!,
          name: player.name,
          emoji: player.emoji,
          createdAt: now,
          lastPlayedAt: now,
        );
        _playerProfiles.add(profile);
        await StorageService.savePlayerProfile(profile, accountId: _currentAccountId!);
      }
    }
  }

  // --- 遊戲操作 ---

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
        accountId: _currentAccountId,
        createdAt: DateTime.now(),
        settings: customSettings ?? _settings,
        players: players,
        status: GameStatus.playing,
        dealerSeat: startDealerPos,
        dealerPassCount: 0,
        consecutiveWins: 0,
        initialDealerSeat: startDealerPos,
      );

      await _saveCurrentGame();
      await _ensurePlayersInProfiles(players);
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

    final updatedJiangs = List<Jiang>.from(_currentGame!.jiangs);

    if (updatedJiangs.isEmpty) {
      final firstJiang = Jiang(
        id: _uuid.v4(),
        gameId: _currentGame!.id,
        jiangNumber: 1,
        seatOrder: _currentGame!.players.map((p) => p.id).toList(),
        startDealerSeat: _currentGame!.dealerSeat,
        startDealerPassCount: _currentGame!.dealerPassCount,
        startTime: DateTime.now(),
      );
      updatedJiangs.add(firstJiang);
      _currentGame = _currentGame!.copyWith(jiangs: updatedJiangs);
      return;
    }

    final currentJiang = updatedJiangs.last;
    final passCountInJiang = _currentGame!.dealerPassCount - currentJiang.startDealerPassCount;

    if (passCountInJiang >= 16) {
      final lastIndex = updatedJiangs.length - 1;
      updatedJiangs[lastIndex] = updatedJiangs[lastIndex].copyWith(
        endTime: DateTime.now(),
      );

      final newJiang = Jiang(
        id: _uuid.v4(),
        gameId: _currentGame!.id,
        jiangNumber: currentJiang.jiangNumber + 1,
        seatOrder: _currentGame!.players.map((p) => p.id).toList(),
        startDealerSeat: _currentGame!.dealerSeat,
        startDealerPassCount: _currentGame!.dealerPassCount,
        startTime: DateTime.now(),
      );

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
      jiangStartDealerPassCount: _currentGame!.currentJiang?.startDealerPassCount ?? 0,
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
      await _saveCurrentGame();
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
    await _saveCurrentGame();
    notifyListeners();
  }

  /// 記錄詐胡
  Future<void> recordFalseWin({
    required String falserId,
  }) async {
    if (_currentGame == null) return;

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
    await _saveCurrentGame();
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

    _ensureCurrentJiang();

    final scoreChanges = CalculationService.calculateMultiWin(
      game: _currentGame!,
      winnerIds: winnerIds,
      loserId: loserId,
      taiMap: taiMap,
      flowerMap: flowerMap,
    );

    final primaryTai = taiMap[winnerIds.first] ?? 0;

    final round = _createRound(
      type: RoundType.multiWin,
      winnerIds: winnerIds,
      loserId: loserId,
      tai: primaryTai,
      scoreChanges: scoreChanges,
    );

    _currentGame = _currentGame!.addRound(round);
    await _saveCurrentGame();
    notifyListeners();
  }

  /// 還原上一局
  Future<void> undoLastRound() async {
    if (_currentGame == null || _currentGame!.rounds.isEmpty) return;

    _currentGame = _currentGame!.undoLastRound();
    await _saveCurrentGame();
    notifyListeners();
  }

  /// 結束遊戲
  Future<void> finishGame() async {
    if (_currentGame == null) return;

    try {
      _currentGame = _currentGame!.copyWith(status: GameStatus.finished);
      await _saveCurrentGame();
      if (_currentAccountId != null) {
        await StorageService.clearCurrentGame(accountId: _currentAccountId!);
      }

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
  Future<void> swapPlayers(int seat1, int seat2) async {
    if (_currentGame == null) return;
    if (seat1 < 0 || seat1 >= 4 || seat2 < 0 || seat2 >= 4) return;

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

    await _saveCurrentGame();
    notifyListeners();
  }

  /// 指定莊家
  Future<void> setDealer({
    required int dealerSeat,
    required bool resetConsecutiveWins,
    required bool recalculateWind,
  }) async {
    if (_currentGame == null) return;
    if (dealerSeat < 0 || dealerSeat >= 4) return;

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
      passCount = ((passCount ~/ 16) + 1) * 16;
    }

    _currentGame = _currentGame!.copyWith(
      dealerSeat: dealerSeat,
      dealerPassCount: passCount,
      consecutiveWins: resetConsecutiveWins ? 0 : _currentGame!.consecutiveWins,
      events: [..._currentGame!.events, event],
    );

    await _saveCurrentGame();
    notifyListeners();
  }

  /// 更新設定
  Future<void> updateSettings(GameSettings newSettings) async {
    _settings = newSettings;
    if (_currentAccountId != null) {
      await StorageService.saveSettings(newSettings, accountId: _currentAccountId!);
    }
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
    if (_currentAccountId != null) {
      await StorageService.savePlayers(players, accountId: _currentAccountId!);
    }
    notifyListeners();
  }

  /// 清除當前遊戲
  Future<void> clearCurrentGame() async {
    _currentGame = null;
    if (_currentAccountId != null) {
      await StorageService.clearCurrentGame(accountId: _currentAccountId!);
    }
    notifyListeners();
  }

  /// 記錄自訂 Round
  Future<void> recordCustomRound(Round round) async {
    if (_currentGame == null) return;

    _currentGame = _currentGame!.addRound(round);
    await _saveCurrentGame();
    notifyListeners();
  }

  // --- 多場次管理 ---

  /// 重新命名牌局
  Future<void> renameGame(String gameId, String name) async {
    final index = _gameHistory.indexWhere((g) => g.id == gameId);
    if (index < 0) return;

    _gameHistory[index] = _gameHistory[index].copyWith(name: name);
    await StorageService.saveGame(_gameHistory[index]);
    notifyListeners();
  }

  /// 刪除歷史牌局
  Future<void> deleteGameFromHistory(String gameId) async {
    _gameHistory.removeWhere((g) => g.id == gameId);
    await StorageService.deleteGame(gameId);
    notifyListeners();
  }

  /// 搜尋牌局
  List<Game> searchGames(String query) {
    if (query.isEmpty) return _gameHistory;
    final q = query.toLowerCase();
    return _gameHistory.where((g) {
      // 搜尋牌局名稱
      if (g.name != null && g.name!.toLowerCase().contains(q)) return true;
      // 搜尋玩家名稱
      for (final p in g.players) {
        if (p.name.toLowerCase().contains(q)) return true;
      }
      // 搜尋日期
      final dateStr = g.createdAt.toString();
      if (dateStr.contains(q)) return true;
      return false;
    }).toList();
  }

  // --- Private helpers ---

  Future<void> _saveCurrentGame() async {
    if (_currentGame == null) return;
    if (_currentAccountId != null) {
      await StorageService.saveCurrentGame(_currentGame!, accountId: _currentAccountId!);
    }
  }
}
