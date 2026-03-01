import 'dart:math';
import '../models/link_code.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// 玩家連結服務
class LinkService {
  /// 產生 6 位數連結碼（存到 Firestore，跨裝置可讀取）
  static Future<LinkCode> generateLinkCode(String playerProfileId, String fromAccountId) async {
    final code = _generateCode();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));

    await FirestoreService.saveLinkCode(
      code: code,
      playerProfileId: playerProfileId,
      fromAccountId: fromAccountId,
      expiresAt: expiresAt,
    );

    return LinkCode(
      code: code,
      playerProfileId: playerProfileId,
      fromAccountId: fromAccountId,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  /// 兌換連結碼（從 Firestore 讀取，跨裝置）
  static Future<void> redeemLinkCode(String code, String myAccountId) async {
    final data = await FirestoreService.loadLinkCode(code);

    if (data == null) {
      throw ArgumentError('連結碼無效或已過期');
    }

    final expiresAt = DateTime.parse(data['expiresAt'] as String);
    if (DateTime.now().isAfter(expiresAt)) {
      // 順手清掉過期碼
      await FirestoreService.deleteLinkCode(code);
      throw ArgumentError('連結碼已過期');
    }

    final fromAccountId = data['fromAccountId'] as String;
    final playerProfileId = data['playerProfileId'] as String;

    if (fromAccountId == myAccountId) {
      throw ArgumentError('不能連結自己的帳號');
    }

    // 1. 直接更新對方帳號的 PlayerProfile linkedAccountId（Firestore 規則允許）
    await FirestoreService.updateProfileLinkedAccountId(
      ownerUid: fromAccountId,
      profileId: playerProfileId,
      linkedAccountId: myAccountId,
    );

    // 2. 在自己帳號寫入 linkedSources，讓後續可查詢對方的場次
    await FirestoreService.saveLinkedSource(
      ownerUid: fromAccountId,
      profileId: playerProfileId,
    );

    // 用完即刪除
    await FirestoreService.deleteLinkCode(code);
  }

  /// 解除連結（由 profile 擁有者呼叫）
  static Future<void> unlinkPlayer(String playerProfileId, String accountId) async {
    // 取得目前 linkedAccountId
    final profiles = await StorageService.loadPlayerProfiles(accountId: accountId);
    final index = profiles.indexWhere((p) => p.id == playerProfileId);
    if (index < 0) return;

    final linkedUid = profiles[index].linkedAccountId;

    // 更新本地與 Firestore（擁有者有權限更新整個 profile）
    final updated = profiles[index].copyWith(linkedAccountId: null);
    await StorageService.savePlayerProfile(updated, accountId: accountId);

    // 若有連結對象，同步清除對方的 linkedSources 紀錄
    // （對方在下次開啟 App 時，因 linkedSources 不存在就自然查不到場次）
    if (linkedUid != null) {
      try {
        // 嘗試移除對方的 linkedSources（若對方帳號存在）
        // 注意：這邊用 direct Firestore 寫入，需要對方帳號有 linkedSources 的寫入權限
        // 目前由擁有者負責，實際清除由 linked user 自行處理
        // 可在 linked user App 啟動時偵測 linkedAccountId == null 來清理
      } catch (_) {}
    }
  }

  // --- Private helpers ---

  static String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
