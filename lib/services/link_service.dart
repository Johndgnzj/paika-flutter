import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/link_code.dart';
import '../models/player_profile.dart';
import 'storage_service.dart';

/// 玩家連結服務
class LinkService {
  static const String _keyLinkCodes = 'link_codes';

  /// 產生 6 位數連結碼
  static Future<LinkCode> generateLinkCode(String playerProfileId, String fromAccountId) async {
    final code = _generateCode();
    final now = DateTime.now();
    final linkCode = LinkCode(
      code: code,
      playerProfileId: playerProfileId,
      fromAccountId: fromAccountId,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );

    final codes = await _loadCodes();
    // 移除過期碼
    codes.removeWhere((c) => c.isExpired);
    codes.add(linkCode);
    await _saveCodes(codes);

    return linkCode;
  }

  /// 兌換連結碼
  static Future<void> redeemLinkCode(String code, String myAccountId) async {
    final codes = await _loadCodes();
    // 移除過期碼
    codes.removeWhere((c) => c.isExpired);

    LinkCode? target;
    try {
      target = codes.firstWhere((c) => c.code == code);
    } catch (_) {
      throw ArgumentError('連結碼無效或已過期');
    }

    if (target.fromAccountId == myAccountId) {
      throw ArgumentError('不能連結自己的帳號');
    }

    // 更新對應 PlayerProfile 的 linkedAccountId
    final profiles = await StorageService.loadPlayerProfiles(accountId: target.fromAccountId);
    final index = profiles.indexWhere((p) => p.id == target!.playerProfileId);
    if (index < 0) {
      throw ArgumentError('找不到對應的玩家檔案');
    }

    profiles[index] = profiles[index].copyWith(linkedAccountId: myAccountId);
    // 直接更新 storage
    await StorageService.savePlayerProfile(profiles[index], accountId: target.fromAccountId);

    // 用完即刪除
    codes.remove(target);
    await _saveCodes(codes);
  }

  /// 解除連結
  static Future<void> unlinkPlayer(String playerProfileId, String accountId) async {
    final profiles = await StorageService.loadPlayerProfiles(accountId: accountId);
    final index = profiles.indexWhere((p) => p.id == playerProfileId);
    if (index < 0) return;

    // 建立一個新的 PlayerProfile，但 linkedAccountId 為 null
    final profile = profiles[index];
    final updated = PlayerProfile(
      id: profile.id,
      accountId: profile.accountId,
      name: profile.name,
      emoji: profile.emoji,
      linkedAccountId: null,
      createdAt: profile.createdAt,
      lastPlayedAt: profile.lastPlayedAt,
    );
    await StorageService.savePlayerProfile(updated, accountId: accountId);
  }

  // --- Private helpers ---

  static String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  static Future<List<LinkCode>> _loadCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyLinkCodes) ?? [];
    return list.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return LinkCode.fromJson(data);
    }).toList();
  }

  static Future<void> _saveCodes(List<LinkCode> codes) async {
    final prefs = await SharedPreferences.getInstance();
    final list = codes.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_keyLinkCodes, list);
  }
}
