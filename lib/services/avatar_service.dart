import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'firestore_service.dart';

/// 頭像上傳服務
class AvatarService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  /// 選擇照片來源
  /// Web 平台不支援 ImageSource.camera，強制使用 gallery
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      // Web 不支援 camera，強制改為 gallery
      final actualSource = kIsWeb ? ImageSource.gallery : source;
      final XFile? image = await _picker.pickImage(
        source: actualSource,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      if (kDebugMode) print('[AvatarService] pickImage failed: $e');
      return null;
    }
  }

  /// 上傳玩家自訂頭像
  /// 路徑：profilePhotos/{uid}/{profileId}.jpg
  /// 回傳帶時間戳的 URL
  static Future<String?> uploadProfilePhoto(String profileId, XFile imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final path = 'profilePhotos/$uid/$profileId.jpg';
      final ref = _storage.ref().child(path);

      // 刪除舊檔（如果存在）
      try {
        await ref.delete();
      } catch (_) {
        // 檔案不存在，忽略
      }

      // 上傳新檔
      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);

      // 取得下載 URL 並加上時間戳強制刷新
      final downloadUrl = await ref.getDownloadURL();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '$downloadUrl?v=$timestamp';
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadProfilePhoto failed: $e');
      return null;
    }
  }

  /// 上傳帳號頭像
  /// 路徑：accountAvatars/{uid}/avatar.jpg
  /// 上傳後自動更新 Firestore
  static Future<String?> uploadAccountAvatar(XFile imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final path = 'accountAvatars/$uid/avatar.jpg';
      final ref = _storage.ref().child(path);

      // 刪除舊檔（如果存在）
      try {
        await ref.delete();
      } catch (_) {
        // 檔案不存在，忽略
      }

      // 上傳新檔
      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);

      // 取得下載 URL 並加上時間戳強制刷新
      final downloadUrl = await ref.getDownloadURL();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlWithTimestamp = '$downloadUrl?v=$timestamp';

      // 更新 Firestore
      await FirestoreService.saveAccountAvatar(urlWithTimestamp);

      return urlWithTimestamp;
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadAccountAvatar failed: $e');
      return null;
    }
  }

  /// 刪除玩家自訂頭像
  static Future<void> deleteProfilePhoto(String profileId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final path = 'profilePhotos/$uid/$profileId.jpg';
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      if (kDebugMode) print('[AvatarService] deleteProfilePhoto failed: $e');
    }
  }
}
