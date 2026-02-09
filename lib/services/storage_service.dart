import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/settings.dart';

/// 本地儲存服務
class StorageService {
  static const String _keyGames = 'games';
  static const String _keyCurrentGame = 'current_game';
  static const String _keyPlayers = 'players';
  static const String _keySettings = 'settings';

  /// 儲存遊戲
  static Future<void> saveGame(Game game) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 儲存到遊戲列表
    final gamesJson = prefs.getStringList(_keyGames) ?? [];
    final gameJson = jsonEncode(game.toJson());
    
    // 更新或添加
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
  }

  /// 載入所有遊戲
  static Future<List<Game>> loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList(_keyGames) ?? [];
    
    return gamesJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Game.fromJson(data);
    }).toList();
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
  }

  /// 儲存當前進行中的遊戲
  static Future<void> saveCurrentGame(Game game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentGame, jsonEncode(game.toJson()));
    await saveGame(game); // 同時儲存到遊戲列表
  }

  /// 載入當前進行中的遊戲
  static Future<Game?> loadCurrentGame() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCurrentGame);
    
    if (json == null) return null;
    
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Game.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// 清除當前遊戲
  static Future<void> clearCurrentGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentGame);
  }

  /// 儲存玩家列表（常用玩家）
  static Future<void> savePlayers(List<Player> players) async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = players.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_keyPlayers, playersJson);
  }

  /// 載入玩家列表
  static Future<List<Player>> loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final playersJson = prefs.getStringList(_keyPlayers) ?? [];
    
    return playersJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Player.fromJson(data);
    }).toList();
  }

  /// 儲存遊戲設定
  static Future<void> saveSettings(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  /// 載入遊戲設定
  static Future<GameSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keySettings);
    
    if (json == null) {
      return const GameSettings(); // 回傳預設設定
    }
    
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return GameSettings.fromJson(data);
    } catch (e) {
      return const GameSettings();
    }
  }

  /// 清除所有資料（用於測試或重置）
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
