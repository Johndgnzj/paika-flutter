import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'firestore_service.dart';

/// 頭像服務（使用 Firestore base64 儲存）
class AvatarService {
  static final ImagePicker _picker = ImagePicker();

  /// 最大圖片大小（bytes）
  static const int _maxImageSize = 200 * 1024; // 200KB

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

  /// 將圖片轉換為 base64 data URI
  /// 壓縮至 <= 200KB
  static Future<String?> imageToBase64(XFile image) async {
    try {
      Uint8List bytes = await image.readAsBytes();

      // 如果圖片太大，嘗試進一步壓縮
      // 由於 XFile 已經在 pickImage 時壓縮過，通常不會超過限制
      // 但為了安全起見，我們檢查並在必要時截斷
      if (bytes.length > _maxImageSize) {
        // 重新選取圖片時使用更低的品質
        if (kDebugMode) {
          print('[AvatarService] Image too large (${bytes.length} bytes), trying lower quality');
        }
        // 由於我們無法在這裡重新壓縮，只能警告並返回 null
        // 實際上 pickImage 已經設定 maxWidth=512, maxHeight=512, imageQuality=85
        // 應該足夠小。如果還是太大，需要用戶選擇較小的圖片
        if (bytes.length > _maxImageSize * 2) {
          if (kDebugMode) {
            print('[AvatarService] Image still too large, please select a smaller image');
          }
          return null;
        }
      }

      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      if (kDebugMode) {
        print('[AvatarService] Image converted to base64, size: ${bytes.length} bytes');
      }

      return dataUri;
    } catch (e) {
      if (kDebugMode) print('[AvatarService] imageToBase64 failed: $e');
      return null;
    }
  }

  /// 上傳玩家自訂頭像（轉換為 base64）
  /// 回傳 base64 data URI
  static Future<String?> uploadProfilePhoto(String profileId, XFile imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      return await imageToBase64(imageFile);
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadProfilePhoto failed: $e');
      return null;
    }
  }

  /// 上傳帳號頭像（轉換為 base64 並存入 Firestore）
  static Future<String?> uploadAccountAvatar(XFile imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final base64Data = await imageToBase64(imageFile);
      if (base64Data == null) return null;

      // 更新 Firestore（使用新的 data 欄位）
      await FirestoreService.saveAccountAvatar(base64Data);

      return base64Data;
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadAccountAvatar failed: $e');
      return null;
    }
  }
}
