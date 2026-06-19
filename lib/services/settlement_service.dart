/// 一筆結算轉帳：fromId（輸家）付 amount 給 toId（贏家）
class SettlementTransfer {
  final String fromId;
  final String toId;
  final int amount;

  const SettlementTransfer({
    required this.fromId,
    required this.toId,
    required this.amount,
  });

  @override
  String toString() => '$fromId -> $toId : $amount';
}

/// 牌局結算服務：依各家淨輸贏算出「誰付誰多少錢」
class SettlementService {
  /// 貪婪結算：將「最大的贏家」與「最大的輸家」配對，每次結清較小的一方。
  ///
  /// 這會讓一位贏家的錢盡量由同一位輸家支付，並使總轉帳筆數最少。
  /// 例：A +1000、B +400、C -200、D -1200
  ///   → D 付 A 1000、D 付 B 200、C 付 B 200
  ///   （最大贏家 A 的錢全部由同一人 D 支付）
  ///
  /// [scores] 為各玩家淨得分（正=贏、負=輸），通常為零和。
  static List<SettlementTransfer> compute(Map<String, int> scores) {
    // 贏家（待收）與輸家（待付，取正值），各依金額由大到小排序
    final creditors = <List<dynamic>>[]; // [id, 剩餘待收]
    final debtors = <List<dynamic>>[]; // [id, 剩餘待付]
    scores.forEach((id, v) {
      if (v > 0) {
        creditors.add([id, v]);
      } else if (v < 0) {
        debtors.add([id, -v]);
      }
    });
    creditors.sort((a, b) => (b[1] as int).compareTo(a[1] as int));
    debtors.sort((a, b) => (b[1] as int).compareTo(a[1] as int));

    final transfers = <SettlementTransfer>[];
    int ci = 0, di = 0;
    while (ci < creditors.length && di < debtors.length) {
      final cAmt = creditors[ci][1] as int;
      final dAmt = debtors[di][1] as int;
      final pay = cAmt < dAmt ? cAmt : dAmt;
      if (pay > 0) {
        transfers.add(SettlementTransfer(
          fromId: debtors[di][0] as String,
          toId: creditors[ci][0] as String,
          amount: pay,
        ));
      }
      creditors[ci][1] = cAmt - pay;
      debtors[di][1] = dAmt - pay;
      if ((creditors[ci][1] as int) == 0) ci++;
      if ((debtors[di][1] as int) == 0) di++;
    }
    return transfers;
  }
}
