import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_stats.dart';
import '../models/game.dart';
import '../models/player_profile.dart';

/// 以 Firebase Auth custom claim `admin == true` 驗證管理員並提供唯讀查詢。
class AdminService with ChangeNotifier {
  AdminService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  int _claimGeneration = 0;
  bool _disposed = false;

  bool _isChecking = true;
  bool _isAdmin = false;

  bool get isChecking => _isChecking;
  bool get isAdmin => _isAdmin;

  void initialize() {
    _authSubscription?.cancel();
    _authSubscription = _auth.idTokenChanges().listen((user) {
      unawaited(_updateClaim(user));
    });
  }

  /// 重新讀取 ID token claim。敏感查詢前可使用 [forceRefresh] 取得最新 claim。
  Future<bool> refreshAdminStatus({bool forceRefresh = false}) async {
    return _updateClaim(_auth.currentUser, forceRefresh: forceRefresh);
  }

  static bool hasAdminClaim(Map<String, dynamic>? claims) =>
      claims?['admin'] == true;

  /// 依文件 ID 穩定分頁，避免一次將全部使用者讀入記憶體。
  Future<AdminUserPage> loadUsersPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 50,
  }) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', '必須大於 0');
    await _requireAdmin();
    final uid = _auth.currentUser?.uid;
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (after != null) query = query.startAfterDocument(after);
    final snapshot = await query.get();
    _ensureStillAuthorized(uid);
    return AdminUserPage(
      users: snapshot.docs
          .map((doc) => AdminUserRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false),
      cursor: snapshot.docs.lastOrNull,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<AdminUserStats> loadUserStats(AdminUserRecord user) async {
    await _requireAdmin();
    final uid = _auth.currentUser?.uid;
    final userDoc = _firestore.collection('users').doc(user.uid);
    final (snapshot, profileSnapshot) = await (
      userDoc.collection('games').get(),
      userDoc.collection('playerProfiles').get(),
    ).wait;
    final games = <Game>[];
    var invalidGameCount = 0;
    for (final doc in snapshot.docs) {
      try {
        games.add(Game.fromJson(doc.data()));
      } on Object catch (error) {
        invalidGameCount++;
        if (kDebugMode) {
          debugPrint('[AdminService] 略過無法解析的牌局 ${doc.id}: $error');
        }
      }
    }
    final profiles = <PlayerProfile>[];
    for (final doc in profileSnapshot.docs) {
      try {
        profiles.add(PlayerProfile.fromJson(doc.data()));
      } on Object catch (error) {
        if (kDebugMode) {
          debugPrint('[AdminService] 略過無法解析的玩家檔案 ${doc.id}: $error');
        }
      }
    }
    _ensureStillAuthorized(uid);
    return AdminUserStats.aggregate(
      user,
      games,
      invalidGameCount: invalidGameCount,
      profiles: profiles,
    );
  }

  Future<bool> _updateClaim(User? user, {bool forceRefresh = false}) async {
    final generation = ++_claimGeneration;
    _isChecking = true;
    _isAdmin = false;
    _notifyListenersIfActive();
    var nextValue = false;
    if (user != null) {
      try {
        final token = await user.getIdTokenResult(forceRefresh);
        nextValue = hasAdminClaim(token.claims);
      } on Object catch (error) {
        if (kDebugMode) {
          debugPrint('[AdminService] 無法讀取管理員 claim: $error');
        }
      }
    }
    if (_disposed || generation != _claimGeneration) return _isAdmin;
    _isAdmin = nextValue;
    _isChecking = false;
    _notifyListenersIfActive();
    return _isAdmin;
  }

  Future<void> _requireAdmin() async {
    if (_disposed || _isChecking || !_isAdmin) {
      throw StateError('此功能僅限管理員使用');
    }
  }

  void _ensureStillAuthorized(String? uid) {
    if (_disposed ||
        !_isAdmin ||
        uid == null ||
        _auth.currentUser?.uid != uid) {
      throw StateError('管理員權限已失效');
    }
  }

  void _notifyListenersIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _claimGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }
}

class AdminUserPage {
  const AdminUserPage({
    required this.users,
    required this.cursor,
    required this.hasMore,
  });

  final List<AdminUserRecord> users;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}
