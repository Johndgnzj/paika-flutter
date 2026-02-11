import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';

/// 帳號驗證服務
class AuthService with ChangeNotifier {
  static const String _keyAccounts = 'accounts';
  static const String _keyCurrentAccountId = 'current_account_id';
  static const _uuid = Uuid();

  Account? _currentAccount;

  Account? get currentAccount => _currentAccount;
  bool get isLoggedIn => _currentAccount != null;

  /// 初始化：嘗試自動登入
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString(_keyCurrentAccountId);
    if (currentId != null) {
      final accounts = await _loadAccounts();
      try {
        _currentAccount = accounts.firstWhere((a) => a.id == currentId);
      } catch (_) {
        // 找不到帳號，清除 ID
        await prefs.remove(_keyCurrentAccountId);
      }
    }
    notifyListeners();
  }

  /// 註冊新帳號
  Future<Account> register(String name, String password, {String? email}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('帳號名稱不能為空');
    if (password.length < 4) throw ArgumentError('密碼至少需要 4 碼');

    final accounts = await _loadAccounts();

    // 檢查重名
    if (accounts.any((a) => a.name == trimmedName)) {
      throw ArgumentError('帳號名稱「$trimmedName」已存在');
    }

    final salt = _generateSalt();
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now();

    final account = Account(
      id: _uuid.v4(),
      name: trimmedName,
      email: email?.trim().isNotEmpty == true ? email!.trim() : null,
      passwordHash: passwordHash,
      salt: salt,
      createdAt: now,
      lastLoginAt: now,
    );

    accounts.add(account);
    await _saveAccounts(accounts);

    // 自動登入
    await _setCurrentAccount(account);

    return account;
  }

  /// 登入
  Future<Account> login(String name, String password) async {
    final trimmedName = name.trim();
    final accounts = await _loadAccounts();

    Account? account;
    try {
      account = accounts.firstWhere((a) => a.name == trimmedName);
    } catch (_) {
      throw ArgumentError('找不到帳號「$trimmedName」');
    }

    final inputHash = _hashPassword(password, account.salt);
    if (inputHash != account.passwordHash) {
      throw ArgumentError('密碼錯誤');
    }

    // 更新最後登入時間
    final updated = account.copyWith(lastLoginAt: DateTime.now());
    final index = accounts.indexWhere((a) => a.id == account!.id);
    accounts[index] = updated;
    await _saveAccounts(accounts);

    await _setCurrentAccount(updated);
    return updated;
  }

  /// 登出
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentAccountId);
    _currentAccount = null;
    notifyListeners();
  }

  /// 修改帳號資料
  Future<void> updateAccount({String? name, String? email, String? newPassword}) async {
    if (_currentAccount == null) return;

    final accounts = await _loadAccounts();
    final index = accounts.indexWhere((a) => a.id == _currentAccount!.id);
    if (index < 0) return;

    var updated = accounts[index];

    if (name != null && name.trim().isNotEmpty) {
      final trimmedName = name.trim();
      if (accounts.any((a) => a.name == trimmedName && a.id != updated.id)) {
        throw ArgumentError('帳號名稱「$trimmedName」已存在');
      }
      updated = updated.copyWith(name: trimmedName);
    }

    if (email != null) {
      updated = updated.copyWith(email: email.trim().isNotEmpty ? email.trim() : null);
    }

    if (newPassword != null && newPassword.length >= 4) {
      final newSalt = _generateSalt();
      updated = updated.copyWith(
        passwordHash: _hashPassword(newPassword, newSalt),
        salt: newSalt,
      );
    }

    accounts[index] = updated;
    await _saveAccounts(accounts);
    await _setCurrentAccount(updated);
  }

  // --- Private helpers ---

  Future<void> _setCurrentAccount(Account account) async {
    _currentAccount = account;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentAccountId, account.id);
    notifyListeners();
  }

  Future<List<Account>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyAccounts) ?? [];
    return list.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return Account.fromJson(data);
    }).toList();
  }

  Future<void> _saveAccounts(List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_keyAccounts, list);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }
}
