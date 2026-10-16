import 'package:flutter_test/flutter_test.dart';
import 'package:paika/models/admin_stats.dart';
import 'package:paika/models/game.dart';
import 'package:paika/models/player.dart';
import 'package:paika/models/player_profile.dart';
import 'package:paika/models/round.dart';
import 'package:paika/models/settings.dart';
import 'package:paika/services/admin_service.dart';

void main() {
  group('AdminService.hasAdminClaim', () {
    test('只有布林值 true 具有管理員權限', () {
      expect(AdminService.hasAdminClaim({'admin': true}), isTrue);
      expect(AdminService.hasAdminClaim({'admin': false}), isFalse);
      expect(AdminService.hasAdminClaim({'admin': 'true'}), isFalse);
      expect(AdminService.hasAdminClaim(null), isFalse);
    });
  });

  group('AdminUserRecord', () {
    test('可用顯示名稱或 Email 搜尋且不分大小寫', () {
      const user = AdminUserRecord(
        uid: 'user-1',
        displayName: '小明',
        email: 'Ming@example.com',
      );

      expect(user.matches('小明'), isTrue);
      expect(user.matches('EXAMPLE.COM'), isTrue);
      expect(user.matches('小華'), isFalse);
    });
  });

  group('AdminUserStats.aggregate', () {
    test('彙總所有牌局、完成場數、總局數並找出最近牌局', () {
      const user = AdminUserRecord(
        uid: 'user-1',
        displayName: '管理測試',
        email: 'admin-test@example.com',
      );
      final older = _game(
        id: 'older',
        createdAt: DateTime(2026, 1, 1),
        status: GameStatus.finished,
        roundCount: 2,
      );
      final newer = _game(
        id: 'newer',
        createdAt: DateTime(2026, 2, 1),
        status: GameStatus.playing,
        roundCount: 1,
      );

      final stats = AdminUserStats.aggregate(user, [
        older,
        newer,
      ], invalidGameCount: 3);

      expect(stats.totalGames, 2);
      expect(stats.completedGames, 1);
      expect(stats.totalRounds, 3);
      expect(stats.recentGame?.id, 'newer');
      expect(stats.games.map((game) => game.id), ['newer', 'older']);
      expect(stats.invalidGameCount, 3);
    });

    test('沒有牌局時回傳零值', () {
      const user = AdminUserRecord(uid: 'empty', displayName: '', email: '');
      final stats = AdminUserStats.aggregate(user, const []);

      expect(stats.totalGames, 0);
      expect(stats.completedGames, 0);
      expect(stats.totalRounds, 0);
      expect(stats.recentGame, isNull);
      expect(stats.games, isEmpty);
      expect(stats.invalidGameCount, 0);
      expect(stats.profiles, isEmpty);
    });

    test('玩家檔案依參與場數排序，並納入已合併的 profile ID', () {
      const user = AdminUserRecord(uid: 'owner', displayName: '', email: '');
      final games = [
        _game(
          id: 'g1',
          createdAt: DateTime(2026, 1, 1),
          status: GameStatus.finished,
          roundCount: 1,
        ),
        _game(
          id: 'g2',
          createdAt: DateTime(2026, 1, 2),
          status: GameStatus.finished,
          roundCount: 1,
          profileId: 'old-friend',
        ),
      ];
      final friend = _profile(
        'friend',
        mergedProfileIds: const ['profile-1', 'old-friend'],
      );
      final idle = _profile('idle', linkedAccountId: 'other-uid');

      final stats = AdminUserStats.aggregate(
        user,
        games,
        profiles: [idle, friend],
      );

      expect(stats.profiles.map((s) => s.profile.id), ['friend', 'idle']);
      expect(stats.profiles.first.gameCount, 2);
      expect(stats.profiles.first.isRegistered, isFalse);
      expect(stats.profiles.last.gameCount, 0);
      expect(stats.profiles.last.isRegistered, isTrue);
    });
  });
}

PlayerProfile _profile(
  String id, {
  List<String> mergedProfileIds = const [],
  String? linkedAccountId,
}) {
  return PlayerProfile(
    id: id,
    accountId: 'owner',
    name: id,
    emoji: '🀄',
    linkedAccountId: linkedAccountId,
    createdAt: DateTime(2026, 1, 1),
    lastPlayedAt: DateTime(2026, 1, 1),
    mergedProfileIds: mergedProfileIds,
  );
}

Game _game({
  required String id,
  required DateTime createdAt,
  required GameStatus status,
  required int roundCount,
  String profileId = 'profile-1',
}) {
  final player = Player(
    id: 'player-1',
    userId: profileId,
    name: '小明',
    emoji: '🀄',
  );
  return Game(
    id: id,
    createdAt: createdAt,
    settings: const GameSettings(),
    players: [player],
    rounds: List.generate(
      roundCount,
      (index) => Round(
        id: '$id-round-$index',
        timestamp: createdAt.add(Duration(minutes: index)),
        type: RoundType.draw,
        tai: 0,
        scoreChanges: const {'player-1': 0},
        dealerPassCount: index,
        dealerSeat: 0,
        jiangNumber: 1,
        jiangStartDealerPassCount: 0,
      ),
    ),
    status: status,
  );
}
