import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/account_settings.dart';
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
  List<Game> _linkedGames = []; // 來自其他玩家綁定的場次
  Set<String> _linkedProfileIds = {}; // 在別人牌局中代表「我」的 profileId
  GameSettings _settings = const GameSettings();
  AccountSettings _accountSettings = const AccountSettings();
  List<Player> _savedPlayers = [];
  List<PlayerProfile> _playerProfiles = [];
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;
  String? _error;
  String? _currentAccountId;
  String? _pendingSelfProfileName;  // 註冊時暫存，由 _initializeForAccount 統一建立

  // Real-time Firestore 監聽器
  StreamSubscription<List<Game>>? _gamesSubscription;
  StreamSubscription<List<PlayerProfile>>? _profilesSubscription;
  StreamSubscription<List<Player>>? _savedPlayersSubscription;
  StreamSubscription<GameSettings?>? _settingsSubscription;
  StreamSubscription<AccountSettings?>? _accountSettingsSubscription;
  StreamSubscription<String?>? _currentGameIdSubscription;
  StreamSubscription<Game?>? _currentGameSubscription;

  final _uuid = const Uuid();

  Game? get currentGame => _currentGame;
  /// 代表「自己」的 profileId 集合（用於 UI 高亮自己）
  /// 包含 _linkedProfileIds（跨帳號連結）和 selfProfileId（自己設定）
  Set<String> get selfProfileIds {
    final result = Set<String>.from(_linkedProfileIds);
    final selfId = _accountSettings.selfProfileId;
    if (selfId != null) {
      result.add(selfId);
    }
    // 同時包含標記為 isSelf 的 profile
    for (final profile in _playerProfiles) {
      if (profile.isSelf) {
        result.add(profile.id);
      }
    }
    return result;
  }

  /// 取得 selfProfileId（若有設定）
  String? get selfProfileId => _accountSettings.selfProfileId;

  /// 取得帳號設定
  AccountSettings get accountSettings => _accountSettings;

  List<Game> get gameHistory {
    final merged = <String, Game>{};
    for (final g in _linkedGames) {
      merged[g.id] = g;
    }
    for (final g in _gameHistory) {
      merged[g.id] = g;
    }
    final result = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
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
      _accountSettings = await StorageService.loadAccountSettings(accountId: accountId);
      _savedPlayers = await StorageService.loadPlayers(accountId: accountId);
      _gameHistory = await StorageService.loadGames(accountId: accountId);
      _currentGame = await StorageService.loadCurrentGame(accountId: accountId);
      _playerProfiles = await StorageService.loadPlayerProfiles(accountId: accountId);

      // 載入跨帳號連結場次（被連結用戶可查詢場主的場次）
      if (FirebaseInitService.isInitialized) {
        await _loadLinkedGames(accountId);
      }

      // 方案 B：若本地 playerProfiles 為空，額外嘗試直接從 Firestore 拉取
      // 解決同一帳號在不同設備登入時，可能因 syncFromCloud 尚未完成而漏掉已有 profile 的問題
      if (_playerProfiles.isEmpty && FirebaseInitService.isInitialized) {
        try {
          final remoteProfiles = await FirestoreService.loadPlayerProfiles();
          if (remoteProfiles.isNotEmpty) {
            _playerProfiles = remoteProfiles;
            // 同步寫入本地
            for (final profile in remoteProfiles) {
              await StorageService.savePlayerProfile(profile, accountId: accountId);
            }
          }
        } catch (e) {
          if (kDebugMode) print('[GameProvider] loadPlayerProfiles from Firestore failed: $e');
        }
      }

      // 若本地沒有 currentGame，嘗試從 Firestore 拿（另一台設備開了牌局）
      if (_currentGame == null && FirebaseInitService.isInitialized) {
        final gameId = await FirestoreService.loadCurrentGameId();
        if (gameId != null) {
          _currentGame = await FirestoreService.loadGame(gameId);
        }
      }

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

      // 啟動 real-time 監聽器，讓跨裝置資料即時同步
      if (FirebaseInitService.isInitialized) {
        _startListeners(accountId);
      }
    } catch (e) {
      _error = '載入資料失敗：$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 載入跨帳號連結場次（被連結用戶可查詢場主的場次）
  Future<void> _loadLinkedGames(String accountId) async {
    try {
      final linkedSources = await FirestoreService.loadLinkedSources();
      if (linkedSources.isEmpty) return;

      final linkedGames = <Game>[];
      for (final source in linkedSources) {
        final games = await FirestoreService.loadLinkedGames(
          source.ownerUid,
          source.profileId,
        );
        linkedGames.addAll(games);
      }

      if (linkedGames.isEmpty) return;

      // 存入 _linkedGames（不混入 _gameHistory，避免被 listener 過濾掉）
      _linkedGames = linkedGames;
      _linkedProfileIds = linkedSources.map((s) => s.profileId).toSet();
    } catch (e) {
      if (kDebugMode) print('[GameProvider] loadLinkedGames failed: $e');
    }
  }

  void _clearState() {
    _cancelListeners();
    _currentGame = null;
    _gameHistory = [];
    _linkedGames = [];
    _linkedProfileIds = {};
    _settings = const GameSettings();
    _accountSettings = const AccountSettings();
    _savedPlayers = [];
    _playerProfiles = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// 啟動 Firestore real-time 監聽器（跨裝置即時同步）
  void _startListeners(String accountId) {
    _cancelListeners();

    _gamesSubscription = FirestoreService.gamesStream().listen((remoteGames) {
      // 合併：遠端有的覆蓋本地，本地獨有的保留
      final localMap = <String, Game>{for (final g in _gameHistory) g.id: g};
      for (final g in remoteGames) {
        localMap[g.id] = g;
      }
      _gameHistory = localMap.values
          .where((g) => g.accountId == accountId || g.accountId == null)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Listener] games error: $e');
    });

    _profilesSubscription =
        FirestoreService.playerProfilesStream().listen((profiles) {
      if (profiles.isEmpty) return;
      print('[DEBUG][Stream] 🔄 playerProfilesStream 收到更新，共 ${profiles.length} 筆');
      for (final p in profiles) {
        print('[DEBUG][Stream]   - ${p.name}: avatarType=${p.avatarType.name}, customPhotoData=${p.customPhotoData != null ? '有(${p.customPhotoData!.length}chars)' : 'null'}');
      }
      _playerProfiles = profiles;
      notifyListeners();
    }, onError: (e) {
      print('[DEBUG][Stream] ❌ playerProfilesStream error: $e');
    });

    _savedPlayersSubscription =
        FirestoreService.savedPlayersStream().listen((players) {
      if (players.isEmpty) return;
      _savedPlayers = players;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Listener] savedPlayers error: $e');
    });

    _settingsSubscription =
        FirestoreService.settingsStream().listen((settings) {
      if (settings == null) return;
      _settings = settings;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Listener] settings error: $e');
    });

    _accountSettingsSubscription =
        FirestoreService.accountSettingsStream().listen((accountSettings) {
      if (accountSettings == null) return;
      _accountSettings = accountSettings;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Listener] accountSettings error: $e');
    });

    // 監聽 currentGameId：讓另一台設備知道有進行中的牌局
    _currentGameIdSubscription =
        FirestoreService.currentGameIdStream().listen((gameId) {
      if (gameId == null) {
        // 另一台設備結束了牌局
        if (_currentGame != null) {
          _currentGame = null;
          notifyListeners();
        }
        _currentGameSubscription?.cancel();
        _currentGameSubscription = null;
      } else if (_currentGame?.id != gameId) {
        // 有新的進行中牌局，開始監聽其內容
        _subscribeToCurrentGame(gameId);
      }
    }, onError: (e) {
      if (kDebugMode) print('[Listener] currentGameId error: $e');
    });
  }

  /// 監聽特定進行中牌局的即時更新（只更新記憶體，不回寫 Firestore 避免循環）
  void _subscribeToCurrentGame(String gameId) {
    _currentGameSubscription?.cancel();
    _currentGameSubscription =
        FirestoreService.gameStream(gameId).listen((game) {
      if (game == null) return;
      // 只更新記憶體狀態，重啟時由 syncFromCloud 處理持久化
      _currentGame = game;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Listener] currentGame error: $e');
    });
  }

  /// 取消所有 Firestore 監聽器
  void _cancelListeners() {
    _gamesSubscription?.cancel();
    _profilesSubscription?.cancel();
    _savedPlayersSubscription?.cancel();
    _settingsSubscription?.cancel();
    _accountSettingsSubscription?.cancel();
    _currentGameIdSubscription?.cancel();
    _currentGameSubscription?.cancel();
    _gamesSubscription = null;
    _profilesSubscription = null;
    _savedPlayersSubscription = null;
    _settingsSubscription = null;
    _accountSettingsSubscription = null;
    _currentGameIdSubscription = null;
    _currentGameSubscription = null;
  }

  @override
  void dispose() {
    _cancelListeners();
    super.dispose();
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
  Future<void> updatePlayerProfile(
    String id, {
    String? name,
    String? emoji,
    AvatarType? avatarType,
    String? customPhotoData,
    bool clearCustomPhotoData = false,
  }) async {
    if (_currentAccountId == null) return;
    final index = _playerProfiles.indexWhere((p) => p.id == id);
    if (index < 0) return;

    print('[DEBUG][Provider] updatePlayerProfile: id=$id');
    print('[DEBUG][Provider]   avatarType=$avatarType, customPhotoData length=${customPhotoData?.length ?? 'null'}');

    _playerProfiles[index] = _playerProfiles[index].copyWith(
      name: name,
      emoji: emoji,
      avatarType: avatarType,
      customPhotoData: customPhotoData,
      clearCustomPhotoData: clearCustomPhotoData,
    );

    print('[DEBUG][Provider]   after copyWith: avatarType=${_playerProfiles[index].avatarType.name}');

    await StorageService.savePlayerProfile(_playerProfiles[index], accountId: _currentAccountId!);
    notifyListeners();

    print('[DEBUG][Provider]   ✅ updatePlayerProfile 完成');
  }

  /// 更新牌局中的玩家名稱（僅影響當前牌局，不改變玩家檔案）
  Future<void> updatePlayerNameInGame(String gameId, String playerId, String newName) async {
    // 如果是當前牌局
    if (_currentGame?.id == gameId) {
      final playerIndex = _currentGame!.players.indexWhere((p) => p.id == playerId);
      if (playerIndex >= 0) {
        final updatedPlayers = List<Player>.from(_currentGame!.players);
        updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(name: newName);
        
        _currentGame = _currentGame!.copyWith(players: updatedPlayers);
        await _saveCurrentGame();
        notifyListeners();
      }
    } else {
      // 如果是歷史牌局
      final historyIndex = _gameHistory.indexWhere((g) => g.id == gameId);
      if (historyIndex >= 0) {
        final game = _gameHistory[historyIndex];
        final playerIndex = game.players.indexWhere((p) => p.id == playerId);
        if (playerIndex >= 0) {
          final updatedPlayers = List<Player>.from(game.players);
          updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(name: newName);
          
          _gameHistory[historyIndex] = game.copyWith(players: updatedPlayers);
          await StorageService.saveGame(_gameHistory[historyIndex]);
          notifyListeners();
        }
      }
    }
  }

  /// 刪除玩家檔案
  Future<void> deletePlayerProfile(String id) async {
    if (_currentAccountId == null) return;
    _playerProfiles.removeWhere((p) => p.id == id);
    await StorageService.deletePlayerProfile(id, accountId: _currentAccountId!);
    notifyListeners();
  }

  /// 合併玩家檔案（將 mergeId 的記錄合併進 keepId）
  Future<void> mergePlayerProfiles(String keepId, String mergeId) async {
    if (_currentAccountId == null) return;

    final keepIndex = _playerProfiles.indexWhere((p) => p.id == keepId);
    final mergeIndex = _playerProfiles.indexWhere((p) => p.id == mergeId);
    if (keepIndex < 0 || mergeIndex < 0) return;

    final keepProfile = _playerProfiles[keepIndex];
    final mergeProfile = _playerProfiles[mergeIndex];

    try {
      // 1. 遍歷 _gameHistory，把每局中 player.userId == mergeId 改成 keepId
      for (var i = 0; i < _gameHistory.length; i++) {
        final game = _gameHistory[i];
        bool changed = false;
        final updatedPlayers = game.players.map((p) {
          if (p.userId == mergeId) {
            changed = true;
            return p.copyWith(userId: keepId);
          }
          return p;
        }).toList();

        if (changed) {
          _gameHistory[i] = game.copyWith(players: updatedPlayers);
          await StorageService.saveGame(_gameHistory[i]);
        }
      }

      // 2. 同樣處理 _currentGame
      if (_currentGame != null) {
        bool changed = false;
        final updatedPlayers = _currentGame!.players.map((p) {
          if (p.userId == mergeId) {
            changed = true;
            return p.copyWith(userId: keepId);
          }
          return p;
        }).toList();

        if (changed) {
          _currentGame = _currentGame!.copyWith(players: updatedPlayers);
          await _saveCurrentGame();
        }
      }

      // 3. 更新 kept profile：lastPlayedAt 取兩者較新的，把 mergeId 加入 mergedProfileIds
      final newerLastPlayedAt = keepProfile.lastPlayedAt.isAfter(mergeProfile.lastPlayedAt)
          ? keepProfile.lastPlayedAt
          : mergeProfile.lastPlayedAt;
      final updatedMergedIds = [...keepProfile.mergedProfileIds, mergeId];

      _playerProfiles[keepIndex] = keepProfile.copyWith(
        lastPlayedAt: newerLastPlayedAt,
        mergedProfileIds: updatedMergedIds,
      );
      await StorageService.savePlayerProfile(_playerProfiles[keepIndex], accountId: _currentAccountId!);

      // 4. 刪除 merge profile
      _playerProfiles.removeAt(mergeIndex > keepIndex ? mergeIndex : mergeIndex);
      await StorageService.deletePlayerProfile(mergeId, accountId: _currentAccountId!);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[GameProvider] mergePlayerProfiles failed: $e');
      rethrow;
    }
  }

  /// 載入玩家檔案
  Future<void> loadPlayerProfiles() async {
    if (_currentAccountId == null) return;
    _playerProfiles = await StorageService.loadPlayerProfiles(accountId: _currentAccountId!);
    notifyListeners();
  }

  /// 確保牌局中的玩家都存在於玩家清單，並更新 lastPlayedAt
  /// 同時回寫 player.userId，確保 game 內的 player 都有對應的 profileId
  Future<void> _ensurePlayersInProfiles(List<Player> players) async {
    if (_currentAccountId == null || _currentGame == null) return;
    final now = DateTime.now();
    bool gameNeedsUpdate = false;
    final updatedPlayers = List<Player>.from(_currentGame!.players);

    for (int pi = 0; pi < updatedPlayers.length; pi++) {
      final player = updatedPlayers[pi];
      int index = -1;

      // 先用 userId 查找
      if (player.userId != null) {
        index = _playerProfiles.indexWhere((p) => p.id == player.userId);
      }
      // 再用名稱查找
      if (index < 0) {
        index = _playerProfiles.indexWhere((p) => p.name == player.name);
      }

      String profileId;
      if (index >= 0) {
        // 已存在 → 更新 lastPlayedAt
        _playerProfiles[index] = _playerProfiles[index].copyWith(lastPlayedAt: now);
        await StorageService.savePlayerProfile(_playerProfiles[index], accountId: _currentAccountId!);
        profileId = _playerProfiles[index].id;
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
        profileId = profile.id;
      }

      // 回寫 userId 到 game 的 player（確保 linkedGames 查詢可命中）
      if (player.userId != profileId) {
        updatedPlayers[pi] = player.copyWith(userId: profileId);
        gameNeedsUpdate = true;
      }
    }

    if (gameNeedsUpdate) {
      _currentGame = _currentGame!.copyWith(players: updatedPlayers);
      await StorageService.saveGame(_currentGame!);
      await FirestoreService.saveGame(_currentGame!);
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

    var updatedJiangs = List<Jiang>.from(_currentGame!.jiangs);
    final currentPC = _currentGame!.dealerPassCount;

    // ★ 修正 undo 後 jiangs 殘留問題：
    //   若最後一個 Jiang 的 startDealerPassCount > currentPC，表示是 undo 後的殘留，移除它
    while (updatedJiangs.isNotEmpty &&
           updatedJiangs.last.startDealerPassCount > currentPC) {
      updatedJiangs.removeLast();
    }

    if (updatedJiangs.isEmpty) {
      final firstJiang = Jiang(
        id: _uuid.v4(),
        gameId: _currentGame!.id,
        jiangNumber: 1,
        seatOrder: _currentGame!.players.map((p) => p.id).toList(),
        startDealerSeat: _currentGame!.dealerSeat,
        startDealerPassCount: currentPC,
        startTime: DateTime.now(),
      );
      updatedJiangs.add(firstJiang);
      _currentGame = _currentGame!.copyWith(jiangs: updatedJiangs);
      return;
    }

    final currentJiang = updatedJiangs.last;
    final passCountInJiang = currentPC - currentJiang.startDealerPassCount;

    bool changed = updatedJiangs.length != _currentGame!.jiangs.length;

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
        startDealerPassCount: currentPC,
        startTime: DateTime.now(),
      );

      updatedJiangs.add(newJiang);
      changed = true;
    }

    if (changed) {
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
    List<String> handPatternIds = const [],
    Map<String, List<String>> winnerHandPatterns = const {},
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
      handPatternIds: handPatternIds,
      winnerHandPatterns: winnerHandPatterns,
    );
  }

  /// 記錄胡牌（放槍）
  Future<void> recordWin({
    required String winnerId,
    required String loserId,
    required int tai,
    required int flowers,
    List<String> handPatternIds = const [],
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
        handPatternIds: handPatternIds,
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
    List<String> handPatternIds = const [],
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
      handPatternIds: handPatternIds,
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
    Map<String, List<String>> winnerHandPatterns = const {},
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
      winnerHandPatterns: winnerHandPatterns,
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

  /// 設定 selfProfileId（設為「我的 Profile」）
  Future<void> setSelfProfileId(String? profileId) async {
    if (_currentAccountId == null) return;
    _accountSettings = _accountSettings.copyWith(
      selfProfileId: profileId,
      clearSelfProfileId: profileId == null,
    );
    await StorageService.saveAccountSettings(_accountSettings, accountId: _currentAccountId!);
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
