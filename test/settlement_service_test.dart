import 'package:flutter_test/flutter_test.dart';
import 'package:paika/services/settlement_service.dart';

void main() {
  group('SettlementService.compute', () {
    int receivedBy(List<SettlementTransfer> t, String id) =>
        t.where((e) => e.toId == id).fold(0, (s, e) => s + e.amount);
    int paidBy(List<SettlementTransfer> t, String id) =>
        t.where((e) => e.fromId == id).fold(0, (s, e) => s + e.amount);

    test('使用者範例：A+1000、B+400、C-200、D-1200', () {
      final t = SettlementService.compute(
          {'A': 1000, 'B': 400, 'C': -200, 'D': -1200});

      // 各家收/付總額正確
      expect(receivedBy(t, 'A'), 1000);
      expect(receivedBy(t, 'B'), 400);
      expect(paidBy(t, 'C'), 200);
      expect(paidBy(t, 'D'), 1200);

      // 規則：最大贏家 A 的錢全由同一位輸家（D）支付
      final payersOfA = t.where((e) => e.toId == 'A').map((e) => e.fromId).toSet();
      expect(payersOfA, {'D'});

      // 具體配對：D→A 1000、D→B 200、C→B 200
      expect(t.length, 3);
      expect(t.any((e) => e.fromId == 'D' && e.toId == 'A' && e.amount == 1000), isTrue);
      expect(t.any((e) => e.fromId == 'D' && e.toId == 'B' && e.amount == 200), isTrue);
      expect(t.any((e) => e.fromId == 'C' && e.toId == 'B' && e.amount == 200), isTrue);
    });

    test('零和守恆：付出總額 == 收取總額', () {
      final t = SettlementService.compute(
          {'A': 1000, 'B': 400, 'C': -200, 'D': -1200});
      final totalPaid = t.fold<int>(0, (s, e) => s + e.amount);
      expect(totalPaid, 1400);
    });

    test('兩人對付：A+500、B-500', () {
      final t = SettlementService.compute({'A': 500, 'B': -500});
      expect(t.length, 1);
      expect(t.first.fromId, 'B');
      expect(t.first.toId, 'A');
      expect(t.first.amount, 500);
    });

    test('一個輸家剛好付清一個贏家：A+300、B+300、C-600', () {
      final t = SettlementService.compute({'A': 300, 'B': 300, 'C': -600});
      expect(t.length, 2);
      expect(paidBy(t, 'C'), 600);
      expect(receivedBy(t, 'A'), 300);
      expect(receivedBy(t, 'B'), 300);
    });

    test('無輸贏：回傳空清單', () {
      expect(SettlementService.compute({'A': 0, 'B': 0}), isEmpty);
      expect(SettlementService.compute({}), isEmpty);
    });
  });
}
