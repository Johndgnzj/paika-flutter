import 'package:flutter_test/flutter_test.dart';
import 'package:paika/models/game.dart';
import 'package:paika/models/game_event.dart';
import 'package:paika/models/player.dart';
import 'package:paika/models/round.dart';
import 'package:paika/models/settings.dart';
import 'package:paika/services/calculation_service.dart';

void main() {
  // 底 50、每台 20
  const settings = GameSettings(baseScore: 50, maxTai: 20);

  group('applyDiceRule（底50、每台20、2台 → 基本 90）', () {
    test('整體加倍：(底 + 台×每台) × N', () {
      expect(CalculationService.applyDiceRule(90, settings, DiceRuleMode.total, 3), 270);
    });

    test('台數加倍：底 + (台×每台 × N)', () {
      // 90 = 50 + 40；台數加倍 → 50 + 40×3 = 170
      expect(CalculationService.applyDiceRule(90, settings, DiceRuleMode.tai, 3), 170);
    });

    test('none 或 factor<=1 維持原值', () {
      expect(CalculationService.applyDiceRule(90, settings, DiceRuleMode.none, 3), 90);
      expect(CalculationService.applyDiceRule(90, settings, DiceRuleMode.total, 1), 90);
    });
  });

  group('calculateWin 套用骰規（A 胡 B 2台；莊家未參與）', () {
    Game makeGame() {
      final players = [
        Player(id: 'P0', name: '莊', emoji: '🀄'), // dealerSeat=0
        Player(id: 'A', name: 'A', emoji: '🀄'),
        Player(id: 'B', name: 'B', emoji: '🀄'),
        Player(id: 'C', name: 'C', emoji: '🀄'),
      ];
      return Game(
        id: 'g',
        createdAt: DateTime(2026, 1, 1),
        settings: settings,
        players: players,
        dealerSeat: 0,
      );
    }

    test('整體加倍 ×3 → 贏家 +270、放槍 -270', () {
      final c = CalculationService.calculateWin(
        game: makeGame(),
        winnerId: 'A',
        loserId: 'B',
        tai: 2,
        flowers: 0,
        diceMode: DiceRuleMode.total,
        diceFactor: 3,
      );
      expect(c['A'], 270);
      expect(c['B'], -270);
      expect(c['P0'], 0);
      expect(c['C'], 0);
    });

    test('台數加倍 ×3 → 贏家 +170、放槍 -170', () {
      final c = CalculationService.calculateWin(
        game: makeGame(),
        winnerId: 'A',
        loserId: 'B',
        tai: 2,
        flowers: 0,
        diceMode: DiceRuleMode.tai,
        diceFactor: 3,
      );
      expect(c['A'], 170);
      expect(c['B'], -170);
    });

    test('無骰規 → 基本 90', () {
      final c = CalculationService.calculateWin(
        game: makeGame(),
        winnerId: 'A',
        loserId: 'B',
        tai: 2,
        flowers: 0,
      );
      expect(c['A'], 90);
      expect(c['B'], -90);
    });
  });

  test('詐胡使用牌局設定的台數，且莊家收錢時連莊', () {
    final game = Game(
      id: 'false-win',
      createdAt: DateTime(2026, 1, 1),
      settings: const GameSettings(
        baseScore: 50,
        maxTai: 20,
        falseWinTai: 3,
        falseWinPayAll: false,
      ),
      players: [
        Player(id: 'dealer', name: '莊', emoji: '🀄'),
        Player(id: 'A', name: 'A', emoji: '🀄'),
        Player(id: 'B', name: 'B', emoji: '🀄'),
        Player(id: 'C', name: 'C', emoji: '🀄'),
      ],
      dealerSeat: 0,
    );
    final changes = CalculationService.calculateFalseWin(
      game: game,
      falserId: 'A',
    );
    expect(changes['A'], -110);
    expect(changes['dealer'], 110);

    final round = Round(
      id: 'r1',
      timestamp: DateTime(2026, 1, 1),
      type: RoundType.falseWin,
      loserId: 'A',
      tai: 3,
      scoreChanges: changes,
      dealerPassCount: game.dealerPassCount,
      dealerSeat: game.dealerSeat,
      jiangNumber: 1,
      jiangStartDealerPassCount: 0,
    );
    final after = game.addRound(round);
    expect(after.dealerSeat, 0);
    expect(after.consecutiveWins, 1);
  });

  test('還原上局不會重播換位事件而改變玩家位置', () {
    final players = [
      Player(id: 'A', name: 'A', emoji: '🀄'),
      Player(id: 'B', name: 'B', emoji: '🀄'),
      Player(id: 'C', name: 'C', emoji: '🀄'),
      Player(id: 'D', name: 'D', emoji: '🀄'),
    ];
    final game = Game(
      id: 'undo',
      createdAt: DateTime(2026, 1, 1),
      settings: settings,
      players: [players[1], players[0], players[2], players[3]],
      events: [
        GameEvent(
          id: 'swap',
          timestamp: DateTime(2026, 1, 1),
          type: GameEventType.swapPlayers,
          data: {'seat1': 0, 'seat2': 1},
          afterRoundIndex: 0,
        ),
      ],
    );
    final round = Round(
      id: 'r1',
      timestamp: DateTime(2026, 1, 1),
      type: RoundType.win,
      winnerId: 'A',
      loserId: 'B',
      tai: 1,
      scoreChanges: {'A': 70, 'B': -70, 'C': 0, 'D': 0},
      dealerPassCount: 0,
      dealerSeat: 0,
      jiangNumber: 1,
      jiangStartDealerPassCount: 0,
    );
    final secondRound = round;
    final restored = game.copyWith(
      rounds: [round, secondRound],
      dealerSeat: 1,
      dealerPassCount: 2,
    ).undoLastRound();
    expect(restored.players.map((p) => p.id).toList(), ['B', 'A', 'C', 'D']);
    expect(restored.rounds, hasLength(1));
  });

  test('打完一局後換位再還原，莊家仍是同一位玩家', () {
    final round = Round(
      id: 'r1',
      timestamp: DateTime(2026, 1, 1),
      type: RoundType.draw,
      tai: 0,
      scoreChanges: const {'A': 0, 'B': 0, 'C': 0, 'D': 0},
      dealerPassCount: 0,
      dealerSeat: 0,
      jiangNumber: 1,
      jiangStartDealerPassCount: 0,
    );
    // A 在座位 0 坐莊打完一局（流局連莊），之後 A 與 B 交換座位。
    final game = Game(
      id: 'undo-after-swap',
      createdAt: DateTime(2026, 1, 1),
      settings: settings,
      players: [
        Player(id: 'B', name: 'B', emoji: '🀄'),
        Player(id: 'A', name: 'A', emoji: '🀄'),
        Player(id: 'C', name: 'C', emoji: '🀄'),
        Player(id: 'D', name: 'D', emoji: '🀄'),
      ],
      rounds: [round],
      dealerSeat: 1,
      consecutiveWins: 1,
      events: [
        GameEvent(
          id: 'swap',
          timestamp: DateTime(2026, 1, 1),
          type: GameEventType.swapPlayers,
          data: {'seat1': 0, 'seat2': 1},
          afterRoundIndex: 0,
        ),
      ],
    );

    final restored = game.undoLastRound();
    expect(restored.players.map((p) => p.id).toList(), ['B', 'A', 'C', 'D']);
    expect(restored.dealer.id, 'A');
    expect(restored.consecutiveWins, 0);
  });
}
