import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/player_profile.dart';
import '../models/settings.dart';

/// Firestore 雲端服務
class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // --- User Profile ---

  /// 建立/更新用戶 profile
  static Future<void> saveUserProfile(String localAccountId, String localAccountName) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.set({
      'localAccountId': localAccountId,
      'localAccountName': localAccountName,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- Games ---

  /// 儲存牌局
  static Future<void> saveGame(Game game) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.collection('games').doc(game.id).set(game.toJson());
  }

  /// 載入所有牌局
  static Future<List<Game>> loadGames() async {
    final doc = _userDoc;
    if (doc == null) return [];

    final snapshot = await doc.collection('games').get();
    return snapshot.docs.map((d) => Game.fromJson(d.data())).toList();
  }

  /// 刪除牌局
  static Future<void> deleteGame(String gameId) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.collection('games').doc(gameId).delete();
  }

  // --- Settings ---

  /// 儲存設定
  static Future<void> saveSettings(GameSettings settings) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.collection('settings').doc('default').set(settings.toJson());
  }

  /// 載入設定
  static Future<GameSettings?> loadSettings() async {
    final doc = _userDoc;
    if (doc == null) return null;

    final snapshot = await doc.collection('settings').doc('default').get();
    if (!snapshot.exists) return null;
    return GameSettings.fromJson(snapshot.data()!);
  }

  // --- Player Profiles ---

  /// 儲存玩家檔案
  static Future<void> savePlayerProfile(PlayerProfile profile) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.collection('playerProfiles').doc(profile.id).set(profile.toJson());
  }

  /// 載入所有玩家檔案
  static Future<List<PlayerProfile>> loadPlayerProfiles() async {
    final doc = _userDoc;
    if (doc == null) return [];

    final snapshot = await doc.collection('playerProfiles').get();
    return snapshot.docs.map((d) => PlayerProfile.fromJson(d.data())).toList();
  }

  /// 刪除玩家檔案
  static Future<void> deletePlayerProfile(String id) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.collection('playerProfiles').doc(id).delete();
  }

  // --- Saved Players ---

  /// 儲存快速選擇列表
  static Future<void> saveSavedPlayers(List<Player> players) async {
    final doc = _userDoc;
    if (doc == null) return;

    await doc.collection('savedPlayers').doc('default').set({
      'players': players.map((p) => p.toJson()).toList(),
    });
  }

  /// 載入快速選擇列表
  static Future<List<Player>> loadSavedPlayers() async {
    final doc = _userDoc;
    if (doc == null) return [];

    final snapshot = await doc.collection('savedPlayers').doc('default').get();
    if (!snapshot.exists) return [];
    final data = snapshot.data()!;
    final list = data['players'] as List? ?? [];
    return list.map((p) => Player.fromJson(p as Map<String, dynamic>)).toList();
  }

  // --- Sync ---

  /// 從雲端同步所有資料到本地（回傳各類資料供呼叫端寫入 SharedPreferences）
  static Future<SyncResult?> syncFromCloud() async {
    final doc = _userDoc;
    if (doc == null) return null;

    try {
      final results = await Future.wait([
        loadGames(),
        loadSettings(),
        loadPlayerProfiles(),
        loadSavedPlayers(),
      ]);

      return SyncResult(
        games: results[0] as List<Game>,
        settings: results[1] as GameSettings?,
        playerProfiles: results[2] as List<PlayerProfile>,
        savedPlayers: results[3] as List<Player>,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[Firestore] syncFromCloud failed: $e');
      }
      return null;
    }
  }
}

/// 同步結果容器
class SyncResult {
  final List<Game> games;
  final GameSettings? settings;
  final List<PlayerProfile> playerProfiles;
  final List<Player> savedPlayers;

  SyncResult({
    required this.games,
    required this.settings,
    required this.playerProfiles,
    required this.savedPlayers,
  });
}
