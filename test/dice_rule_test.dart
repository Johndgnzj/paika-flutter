import 'package:flutter_test/flutter_test.dart';
import 'package:paika/models/game.dart';
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
}
