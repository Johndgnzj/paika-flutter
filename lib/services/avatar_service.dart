import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'firestore_service.dart';

// 條件導入：Web 用 dart:html 實作
import 'avatar_service_stub.dart'
    if (dart.library.html) 'avatar_service_web.dart' as web_picker;

/// 頭像服務（使用 Firestore base64 儲存）
class AvatarService {
  static final ImagePicker _picker = ImagePicker();

  /// 最大圖片大小（bytes）
  static const int _maxImageSize = 200 * 1024; // 200KB

  /// 直接選擇圖片並轉換為 base64 data URI
  /// Web 平台使用 dart:html 直接觸發 file input（保留 gesture context）
  /// 手機平台使用 image_picker
  static Future<String?> pickImageAsBase64({ImageSource source = ImageSource.gallery}) async {
    if (kIsWeb) {
      // Web：使用 dart:html FileUploadInputElement
      // 必須在 user gesture 的同步鏈中呼叫，不能有任何 await 在前面
      return web_picker.pickImageAsBase64Web();
    } else {
      // 手機：繼續用 image_picker
      try {
        final XFile? file = await _picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );
        if (file == null) return null;

        final bytes = await file.readAsBytes();

        // 檢查大小
        if (bytes.length > _maxImageSize * 2) {
          if (kDebugMode) {
            print('[AvatarService] Image too large (${bytes.length} bytes)');
          }
          return null;
        }

        final base64Str = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64Str';
      } catch (e) {
        if (kDebugMode) print('[AvatarService] pickImageAsBase64 failed: $e');
        return null;
      }
    }
  }

  /// 選擇照片來源（舊方法，為相容性保留）
  /// Web 平台不支援 ImageSource.camera，強制使用 gallery
  @Deprecated('Use pickImageAsBase64() instead for Web compatibility')
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

  /// 將圖片轉換為 base64 data URI（舊方法，為相容性保留）
  /// 壓縮至 <= 200KB
  @Deprecated('Use pickImageAsBase64() instead')
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
  static Future<String?> uploadProfilePhotoFromBase64(String profileId, String base64Data) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      return base64Data;
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadProfilePhotoFromBase64 failed: $e');
      return null;
    }
  }

  /// 上傳玩家自訂頭像（舊方法，為相容性保留）
  @Deprecated('Use uploadProfilePhotoFromBase64() instead')
  static Future<String?> uploadProfilePhoto(String profileId, XFile imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      // ignore: deprecated_member_use_from_same_package
      return await imageToBase64(imageFile);
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadProfilePhoto failed: $e');
      return null;
    }
  }

  /// 上傳帳號頭像（從 base64 data URI 存入 Firestore）
  static Future<String?> uploadAccountAvatarFromBase64(String base64Data) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      // 更新 Firestore（使用新的 data 欄位）
      await FirestoreService.saveAccountAvatar(base64Data);

      return base64Data;
    } catch (e) {
      if (kDebugMode) print('[AvatarService] uploadAccountAvatarFromBase64 failed: $e');
      return null;
    }
  }

  /// 上傳帳號頭像（舊方法，為相容性保留）
  @Deprecated('Use uploadAccountAvatarFromBase64() instead')
  static Future<String?> uploadAccountAvatar(XFile imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      // ignore: deprecated_member_use_from_same_package
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
