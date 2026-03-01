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
    return FutureBuilder<String?>(
      future: FirestoreService.loadAccountAvatarByUid(profile.accountId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _buildImageAvatar(snapshot.data!);
        }
        // 若帳號頭像不存在，fallback 到 emoji
        return _buildEmojiAvatar();
      },
    );
  }

  Widget _buildCustomPhotoAvatar() {
    if (profile.customPhotoUrl == null) {
      return _buildEmojiAvatar();
    }
    return _buildImageAvatar(profile.customPhotoUrl!);
  }

  Widget _buildImageAvatar(String url) {
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
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
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
