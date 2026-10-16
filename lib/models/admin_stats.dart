import 'package:cloud_firestore/cloud_firestore.dart';

import 'game.dart';
import 'player_profile.dart';

/// 管理員可查詢的使用者基本資料。
class AdminUserRecord {
  final String uid;
  final String displayName;
  final String email;
  final DateTime? createdAt;

  const AdminUserRecord({
    required this.uid,
    required this.displayName,
    required this.email,
    this.createdAt,
  });

  factory AdminUserRecord.fromMap(String uid, Map<String, dynamic> data) {
    return AdminUserRecord(
      uid: uid,
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      email: (data['email'] as String?)?.trim() ?? '',
      createdAt: _parseDate(data['createdAt']),
    );
  }

  String get label =>
      displayName.isEmpty ? (email.isEmpty ? uid : email) : displayName;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return displayName.toLowerCase().contains(normalized) ||
        email.toLowerCase().contains(normalized);
  }

  static DateTime? _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// 單一帳號的所有牌局彙總。
class AdminUserStats {
  final AdminUserRecord user;
  final List<Game> games;
  final int totalGames;
  final int completedGames;
  final int totalRounds;
  final Game? recentGame;
  final int invalidGameCount;
  final List<AdminProfileSummary> profiles;

  AdminUserStats._({
    required this.user,
    required this.games,
    required this.totalGames,
    required this.completedGames,
    required this.totalRounds,
    required this.recentGame,
    required this.invalidGameCount,
    required this.profiles,
  });

  factory AdminUserStats.aggregate(
    AdminUserRecord user,
    Iterable<Game> source, {
    int invalidGameCount = 0,
    Iterable<PlayerProfile> profiles = const [],
  }) {
    final games = source.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final profileSummaries =
        profiles
            .map((profile) => AdminProfileSummary.fromGames(profile, games))
            .toList()
          ..sort((a, b) {
            final byGames = b.gameCount.compareTo(a.gameCount);
            return byGames != 0
                ? byGames
                : a.profile.name.compareTo(b.profile.name);
          });
    return AdminUserStats._(
      user: user,
      games: List.unmodifiable(games),
      totalGames: games.length,
      completedGames: games
          .where((game) => game.status == GameStatus.finished)
          .length,
      totalRounds: games.fold(0, (total, game) => total + game.rounds.length),
      recentGame: games.isEmpty ? null : games.first,
      invalidGameCount: invalidGameCount,
      profiles: List.unmodifiable(profileSummaries),
    );
  }
}

/// 帳號底下的單一玩家檔案（含未註冊的好友）及其參與場數。
class AdminProfileSummary {
  final PlayerProfile profile;
  final int gameCount;

  const AdminProfileSummary({required this.profile, required this.gameCount});

  factory AdminProfileSummary.fromGames(
    PlayerProfile profile,
    Iterable<Game> games,
  ) {
    final ids = profileIdsOf(profile);
    return AdminProfileSummary(
      profile: profile,
      gameCount: games
          .where((game) => game.players.any((p) => ids.contains(p.userId)))
          .length,
    );
  }

  /// 統計時需一併納入已合併進此檔案的舊 profile ID。
  static Set<String> profileIdsOf(PlayerProfile profile) => {
    profile.id,
    ...profile.mergedProfileIds,
  };

  Set<String> get profileIds => profileIdsOf(profile);

  bool get isRegistered => profile.isSelf || profile.linkedAccountId != null;
}
