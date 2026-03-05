import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import '../services/firestore_service.dart';

/// 玩家頭像 Widget
/// 根據 avatarType 顯示 emoji、帳號頭像或自訂照片
class PlayerAvatar extends StatelessWidget {
  final PlayerProfile profile;
  final double size;
  final bool showBorder;

  const PlayerAvatar({
    super.key,
    required this.profile,
    this.size = 40,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (profile.avatarType) {
      case AvatarType.emoji:
        return _buildEmojiAvatar();
      case AvatarType.accountAvatar:
        return _buildAccountAvatar();
      case AvatarType.customPhoto:
        return _buildCustomPhotoAvatar();
    }
  }

  Widget _buildEmojiAvatar() {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          profile.emoji,
          style: TextStyle(fontSize: size * 0.8),
        ),
      ),
    );
  }

  Widget _buildAccountAvatar() {
    // linkedAccountId 優先：這個玩家已連結自己的帳號，頭像來自連結帳號
    // fallback 到 accountId：自己的 self profile（isSelf=true），頭像來自自己帳號
    final uid = profile.linkedAccountId ?? profile.accountId;
    return FutureBuilder<String?>(
      future: FirestoreService.loadAccountAvatarByUid(uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _buildBase64Avatar(snapshot.data!);
        }
        // 若帳號頭像不存在，fallback 到 emoji
        return _buildEmojiAvatar();
      },
    );
  }

  Widget _buildCustomPhotoAvatar() {
    if (profile.customPhotoData == null) {
      return _buildEmojiAvatar();
    }
    return _buildBase64Avatar(profile.customPhotoData!);
  }

  /// 從 base64 data URI 渲染圖片
  Widget _buildBase64Avatar(String dataUri) {
    try {
      // 解析 data URI：data:image/jpeg;base64,XXXXX
      final base64String = dataUri.split(',').last;
      final Uint8List bytes = base64Decode(base64String);

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(color: Colors.grey.shade300, width: 2)
              : null,
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 載入失敗時 fallback 到 emoji
              return Center(
                child: Text(
                  profile.emoji,
                  style: TextStyle(fontSize: size * 0.8),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      // base64 解析失敗時 fallback 到 emoji
      return _buildEmojiAvatar();
    }
  }
}

/// 大尺寸頭像（用於玩家詳情頁）
class PlayerAvatarLarge extends StatelessWidget {
  final PlayerProfile profile;
  final double size;
  final VoidCallback? onTap;

  const PlayerAvatarLarge({
    super.key,
    required this.profile,
    this.size = 80,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PlayerAvatar(
        profile: profile,
        size: size,
        showBorder: true,
      ),
    );
  }
}
