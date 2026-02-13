import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/player_profile.dart';
import '../models/settings.dart';
import 'firestore_service.dart';

/// 本地儲存服務（含 Write-Through 雲端同步）
class StorageService {
  static const String _keyGames = 'games';
  static const String _keyThemeMode = 'theme_mode';

  /// 雲端同步開關
  static bool _cloudEnabled = false;

  /// 啟用雲端同步
  static void enableCloud() {
    _cloudEnabled = true;
  }

  /// 非同步雲端寫入（fire-and-forget，錯誤只 log）
  static void _syncToCloudAsync(Future<void> Function() action) {
    if (!_cloudEnabled) return;
    action().catchError((e) {
      if (kDebugMode) {
        print('[Cloud Sync] Error: $e');
      }
    });
  }

  // 帳號隔離 key 生成
  static String _currentGameKey(String accountId) => 'current_game_$accountId';
  static String _playersKey(String accountId) => 'players_$accountId';
  static String _settingsKey(String accountId) => 'settings_$accountId';
  static String _playerProfilesKey(String accountId) => 'player_profiles_$accountId';

  /// 儲存遊戲（全域 games 列表，accountId 存在 Game 物件內）
  static Future<void> saveGame(Game game) async {
    final prefs = await SharedPreferences.getInstance();

    final gamesJson = prefs.getStringList(_keyGames) ?? [];
    final gameJson = jsonEncode(game.toJson());

    final index = gamesJson.indexWhere((g) {
      final data = jsonDecode(g) as Map<String, dynamic>;
      return data['id'] == game.id;
    });

    if (index >= 0) {
      gamesJson[index] = gameJson;
    } else {
      gamesJson.add(gameJson);
    }

    await prefs.setStringList(_keyGames, gamesJson);
    _syncToCloudAsync(() => FirestoreService.saveGame(game));
  }

  /// 載入所有遊戲（可選 accountId 過濾）
  static Future<List<Game>> loadGames({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList(_keyGames) ?? [];

    final games = gamesJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Game.fromJson(data);
    }).toList();

    if (accountId != null) {
      return games.where((g) => g.accountId == accountId || g.accountId == null).toList();
    }
    return games;
  }

  /// 載入單一遊戲
  static Future<Game?> loadGame(String gameId) async {
    final games = await loadGames();
    try {
      return games.firstWhere((g) => g.id == gameId);
    } catch (e) {
      return null;
    }
  }

  /// 刪除遊戲
  static Future<void> deleteGame(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList(_keyGames) ?? [];

    gamesJson.removeWhere((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data['id'] == gameId;
    });

    await prefs.setStringList(_keyGames, gamesJson);
    _syncToCloudAsync(() => FirestoreService.deleteGame(gameId));
  }

  /// 儲存當前進行中的遊戲（帳號隔離）
  static Future<void> saveCurrentGame(Game game, {required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentGameKey(accountId), jsonEncode(game.toJson()));
    await saveGame(game);
  }

  /// 載入當前進行中的遊戲（帳號隔離）
  static Future<Game?> loadCurrentGame({required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_currentGameKey(accountId));

    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Game.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// 清除當前遊戲（帳號隔離）
  static Future<void> clearCurrentGame({required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentGameKey(accountId));
  }

  /// 儲存玩家列表（帳號隔離）
  static Future<void> savePlayers(List<Player> players, {required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = players.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_playersKey(accountId), playersJson);
    _syncToCloudAsync(() => FirestoreService.saveSavedPlayers(players));
  }

  /// 載入玩家列表（帳號隔離）
  static Future<List<Player>> loadPlayers({required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = prefs.getStringList(_playersKey(accountId)) ?? [];

    return playersJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Player.fromJson(data);
    }).toList();
  }

  /// 儲存遊戲設定（帳號隔離）
  static Future<void> saveSettings(GameSettings settings, {required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey(accountId), jsonEncode(settings.toJson()));
    _syncToCloudAsync(() => FirestoreService.saveSettings(settings));
  }

  /// 載入遊戲設定（帳號隔離）
  static Future<GameSettings> loadSettings({required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey(accountId));

    if (json == null) {
      return const GameSettings();
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return GameSettings.fromJson(data);
    } catch (e) {
      return const GameSettings();
    }
  }

  // --- PlayerProfile CRUD ---

  /// 儲存 PlayerProfile
  static Future<void> savePlayerProfile(PlayerProfile profile, {required String accountId}) async {
    final profiles = await loadPlayerProfiles(accountId: accountId);
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await _savePlayerProfiles(profiles, accountId: accountId);
    _syncToCloudAsync(() => FirestoreService.savePlayerProfile(profile));
  }

  /// 載入所有 PlayerProfile
  static Future<List<PlayerProfile>> loadPlayerProfiles({required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_playerProfilesKey(accountId)) ?? [];
    return list.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return PlayerProfile.fromJson(data);
    }).toList();
  }

  /// 刪除 PlayerProfile
  static Future<void> deletePlayerProfile(String id, {required String accountId}) async {
    final profiles = await loadPlayerProfiles(accountId: accountId);
    profiles.removeWhere((p) => p.id == id);
    await _savePlayerProfiles(profiles, accountId: accountId);
    _syncToCloudAsync(() => FirestoreService.deletePlayerProfile(id));
  }

  static Future<void> _savePlayerProfiles(List<PlayerProfile> profiles, {required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = profiles.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_playerProfilesKey(accountId), list);
  }

  // --- 全域（非帳號隔離） ---

  /// 儲存主題模式
  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  /// 載入主題模式
  static Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  /// 清除所有資料（用於測試或重置）
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- 雲端同步 ---

  /// 從 Firestore 拉取資料覆蓋本地
  static Future<void> syncFromCloud({required String accountId}) async {
    if (!_cloudEnabled) return;

    try {
      final result = await FirestoreService.syncFromCloud();
      if (result == null) return;

      final prefs = await SharedPreferences.getInstance();

      // 合併牌局（雲端有的覆蓋本地，本地獨有的保留）
      if (result.games.isNotEmpty) {
        final localGamesJson = prefs.getStringList(_keyGames) ?? [];
        final localGames = <String, String>{};
        for (final json in localGamesJson) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          localGames[data['id'] as String] = json;
        }
        for (final game in result.games) {
          localGames[game.id] = jsonEncode(game.toJson());
        }
        await prefs.setStringList(_keyGames, localGames.values.toList());
      }

      // 設定（雲端覆蓋）
      if (result.settings != null) {
        await prefs.setString(
          _settingsKey(accountId),
          jsonEncode(result.settings!.toJson()),
        );
      }

      // 玩家檔案（雲端覆蓋）
      if (result.playerProfiles.isNotEmpty) {
        final list = result.playerProfiles
            .map((p) => jsonEncode(p.toJson()))
            .toList();
        await prefs.setStringList(_playerProfilesKey(accountId), list);
      }

      // 快速選擇列表（雲端覆蓋）
      if (result.savedPlayers.isNotEmpty) {
        final list = result.savedPlayers
            .map((p) => jsonEncode(p.toJson()))
            .toList();
        await prefs.setStringList(_playersKey(accountId), list);
      }

      if (kDebugMode) {
        print('[Cloud Sync] Synced: ${result.games.length} games, '
            '${result.playerProfiles.length} profiles');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Cloud Sync] syncFromCloud failed: $e');
      }
    }
  }

  // --- 資料遷移 ---

  /// 將舊版無 accountId 的牌局遷移到指定帳號
  static Future<void> migrateOrphanGames(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList(_keyGames) ?? [];
    bool changed = false;

    for (int i = 0; i < gamesJson.length; i++) {
      final data = jsonDecode(gamesJson[i]) as Map<String, dynamic>;
      if (data['accountId'] == null) {
        data['accountId'] = accountId;
        gamesJson[i] = jsonEncode(data);
        changed = true;
      }
    }

    if (changed) {
      await prefs.setStringList(_keyGames, gamesJson);
    }

    // 遷移舊的 current_game（無帳號 prefix 的 key）
    final oldCurrentGame = prefs.getString('current_game');
    if (oldCurrentGame != null) {
      await prefs.setString(_currentGameKey(accountId), oldCurrentGame);
      await prefs.remove('current_game');
    }

    // 遷移舊的 players
    final oldPlayers = prefs.getStringList('players');
    if (oldPlayers != null) {
      await prefs.setStringList(_playersKey(accountId), oldPlayers);
      await prefs.remove('players');
    }

    // 遷移舊的 settings
    final oldSettings = prefs.getString('settings');
    if (oldSettings != null) {
      await prefs.setString(_settingsKey(accountId), oldSettings);
      await prefs.remove('settings');
    }
  }
}
