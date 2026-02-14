import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Email/Password 帳號驗證服務
class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get uid => _auth.currentUser?.uid;
  String? get displayName => _auth.currentUser?.displayName;
  String? get email => _auth.currentUser?.email;

  /// 初始化：監聽 auth 狀態變化
  Future<void> initialize() async {
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  /// 註冊新帳號
  Future<User> register(String email, String password, String displayName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(displayName.trim());
      await credential.user!.reload();
      notifyListeners();
      return _auth.currentUser!;
    } on FirebaseAuthException catch (e) {
      throw ArgumentError(_mapFirebaseError(e));
    }
  }

  /// 登入
  Future<User> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw ArgumentError(_mapFirebaseError(e));
    }
  }

  /// 登出
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// 修改顯示名稱
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _auth.currentUser?.reload();
    notifyListeners();
  }

  /// 寄送密碼重設信
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw ArgumentError(_mapFirebaseError(e));
    }
  }

  /// Firebase 錯誤碼翻譯成中文
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return '密碼強度不足（至少 6 碼）';
      case 'email-already-in-use':
        return '此 Email 已被註冊';
      case 'invalid-email':
        return 'Email 格式不正確';
      case 'user-not-found':
        return '找不到此帳號';
      case 'wrong-password':
        return '密碼錯誤';
      case 'user-disabled':
        return '此帳號已被停用';
      case 'too-many-requests':
        return '登入嘗試次數過多，請稍後再試';
      case 'invalid-credential':
        return 'Email 或密碼錯誤';
      default:
        return '驗證失敗：${e.message}';
    }
  }
}
