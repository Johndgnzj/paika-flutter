import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Firebase 初始化服務（靜默整合）
class FirebaseInitService {
  static bool _initialized = false;

  /// Firebase UID（Anonymous Auth）
  static String? get firebaseUid => FirebaseAuth.instance.currentUser?.uid;

  /// 是否已初始化
  static bool get isInitialized => _initialized;

  /// 初始化 Firebase（App 啟動時呼叫一次）
  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. Firebase Core
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Firestore 離線快取設定
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // 3. App Check（各平台 provider）
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('placeholder'),
      appleProvider: AppleProvider.appAttest,
      androidProvider: AndroidProvider.playIntegrity,
    );

    // 4. Anonymous Auth（靜默登入）
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    _initialized = true;

    if (kDebugMode) {
      print('[Firebase] Initialized. UID: $firebaseUid');
    }
  }
}
