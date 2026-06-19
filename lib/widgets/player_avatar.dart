import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/player_profile.dart';
import '../providers/game_provider.dart';
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

    // 已快取則同步渲染，避免 rebuild 時 FutureBuilder 先閃回 emoji
    final cached = FirestoreService.cachedAccountAvatarByUid(uid);
    if (cached != null) {
      return _buildBase64Avatar(cached);
    }

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

/// 牌局中玩家頭像
///
/// 牌局內的 [Player] 只帶 emoji，完整頭像資訊（自訂照片 / 帳號頭像）存在
/// [PlayerProfile]。本 widget 依 `player.userId` 反查對應的 profile 後，
/// 透過 [PlayerAvatar] 正確顯示上傳照片；找不到對應 profile 時退回顯示 emoji。
class PlayerGameAvatar extends StatelessWidget {
  final Player player;
  final double size;
  final bool showBorder;

  const PlayerGameAvatar({
    super.key,
    required this.player,
    this.size = 40,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<GameProvider>().profileForPlayer(player);

    // 只有當對應 profile 真的設定了照片 / 帳號頭像時，才以 profile 渲染；
    // emoji 類型或找不到 profile 時沿用牌局中該玩家的 emoji，
    // 以保留「每局可自訂 emoji」的既有行為。
    final hasPhotoAvatar = profile != null &&
        ((profile.avatarType == AvatarType.customPhoto &&
                profile.customPhotoData != null) ||
            profile.avatarType == AvatarType.accountAvatar);

    if (hasPhotoAvatar) {
      return PlayerAvatar(
        profile: profile,
        size: size,
        showBorder: showBorder,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          player.emoji,
          style: TextStyle(fontSize: size * 0.8),
        ),
      ),
    );
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
