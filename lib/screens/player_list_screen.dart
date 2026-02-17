import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../models/player_profile.dart';
import '../services/link_service.dart';
import '../utils/constants.dart';
import '../widgets/animation_helpers.dart';
import 'player_stats_screen.dart';

class PlayerListScreen extends StatelessWidget {
  const PlayerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('玩家管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: '輸入連結碼',
            onPressed: () => _showRedeemDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          final profiles = provider.playerProfiles;

          if (profiles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '尚未登錄任何玩家',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '點擊右上角 + 新增玩家',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final selfProfile = profiles.where((p) => p.isSelf).toList();
          final otherProfiles = profiles.where((p) => !p.isSelf).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 檢測是否有自己的玩家資訊
              if (selfProfile.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person_add_alt_1, size: 48, color: Colors.amber),
                      const SizedBox(height: 12),
                      const Text(
                        '尚未建立自己的玩家資訊',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '建立後可以追蹤你的戰績和統計',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddSelfDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('建立我的資訊'),
                      ),
                    ],
                  ),
                ),

              // 自己的檔案置頂
              for (final profile in selfProfile)
                _buildProfileCard(context, profile, provider),

              // 分隔線
              if (selfProfile.isNotEmpty && otherProfiles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '你的玩家 (${otherProfiles.length})',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
              ],

              // 其他玩家
              for (final profile in otherProfiles)
                _buildProfileCard(context, profile, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, PlayerProfile profile, GameProvider provider) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final isLinked = profile.linkedAccountId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Text(profile.emoji, style: const TextStyle(fontSize: 32)),
        title: Row(
          children: [
            Flexible(child: Text(profile.name, style: const TextStyle(fontSize: 18))),
            if (profile.isSelf) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '我',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
            if (isLinked) ...[
              const SizedBox(width: 8),
              Icon(Icons.link, size: 18, color: Colors.blue.shade400),
            ],
          ],
        ),
        subtitle: Text('最後遊玩：${dateFormat.format(profile.lastPlayedAt)}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditDialog(context, profile, provider);
                break;
              case 'link':
                _showGenerateLinkDialog(context, profile, provider);
                break;
              case 'unlink':
                _confirmUnlink(context, profile, provider);
                break;
              case 'delete':
                _confirmDelete(context, profile, provider);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('編輯')),
            const PopupMenuItem(value: 'link', child: Text('產生連結碼')),
            if (isLinked)
              const PopupMenuItem(value: 'unlink', child: Text('解除連結')),
            if (!profile.isSelf)
              const PopupMenuItem(value: 'delete', child: Text('刪除')),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            FadeSlidePageRoute(page: PlayerStatsScreen(profile: profile)),
          );
        },
      ),
    );
  }

  // --- 連結碼相關 ---

  void _showGenerateLinkDialog(BuildContext context, PlayerProfile profile, GameProvider provider) async {
    final accountId = provider.currentAccountId;
    if (accountId == null) return;

    try {
      final linkCode = await LinkService.generateLinkCode(profile.id, accountId);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) {
          return _LinkCodeDialog(
            code: linkCode.code,
            playerName: profile.name,
            expiresAt: linkCode.expiresAt,
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('產生連結碼失敗：$e')),
        );
      }
    }
  }

  void _showRedeemDialog(BuildContext context) {
    final codeController = TextEditingController();
    final provider = context.read<GameProvider>();
    final accountId = provider.currentAccountId;
    if (accountId == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('輸入連結碼'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: '6 位數連結碼',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.length != 6) return;

                try {
                  await LinkService.redeemLinkCode(code, accountId);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('連結成功！')),
                    );
                    // 重新載入 profiles
                    provider.loadPlayerProfiles();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e is ArgumentError ? e.message.toString() : '連結失敗：$e')),
                    );
                  }
                }
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  void _confirmUnlink(BuildContext context, PlayerProfile profile, GameProvider provider) {
    final accountId = provider.currentAccountId;
    if (accountId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除連結'),
        content: Text('確定要解除「${profile.name}」的帳號連結嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await LinkService.unlinkPlayer(profile.id, accountId);
              provider.loadPlayerProfiles();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('解除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- 新增 / 編輯 / 刪除 ---

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedEmoji = AppConstants.defaultEmojis[0];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增玩家'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      _showEmojiPicker(context, selectedEmoji, (emoji) {
                        setDialogState(() => selectedEmoji = emoji);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(selectedEmoji, style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '玩家名稱',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    context.read<GameProvider>().addPlayerProfile(name, selectedEmoji);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('新增'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSelfDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedEmoji = AppConstants.defaultEmojis[0];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('建立我的玩家資訊'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      _showEmojiPicker(context, selectedEmoji, (emoji) {
                        setDialogState(() => selectedEmoji = emoji);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(selectedEmoji, style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '你的名稱',
                      border: OutlineInputBorder(),
                      helperText: '這將成為你的玩家資訊',
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    context.read<GameProvider>().addPlayerProfile(
                      name, 
                      selectedEmoji,
                      isSelf: true, // 設定為自己
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('建立'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, PlayerProfile profile, GameProvider provider) {
    final nameController = TextEditingController(text: profile.name);
    String selectedEmoji = profile.emoji;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('編輯玩家'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      _showEmojiPicker(context, selectedEmoji, (emoji) {
                        setDialogState(() => selectedEmoji = emoji);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(selectedEmoji, style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '玩家名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    provider.updatePlayerProfile(profile.id, name: name, emoji: selectedEmoji);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmojiPicker(BuildContext context, String current, void Function(String) onSelected) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('選擇圖示'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              children: AppConstants.availableEmojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    onSelected(emoji);
                    Navigator.pop(context);
                  },
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, PlayerProfile profile, GameProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除玩家'),
        content: Text('確定要刪除「${profile.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.deletePlayerProfile(profile.id);
              Navigator.pop(context);
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 連結碼顯示 Dialog（含倒數計時）
class _LinkCodeDialog extends StatefulWidget {
  final String code;
  final String playerName;
  final DateTime expiresAt;

  const _LinkCodeDialog({
    required this.code,
    required this.playerName,
    required this.expiresAt,
  });

  @override
  State<_LinkCodeDialog> createState() => _LinkCodeDialogState();
}

class _LinkCodeDialogState extends State<_LinkCodeDialog> {
  late Timer _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    setState(() {
      _secondsLeft = remaining.inSeconds.clamp(0, 600);
    });
    if (_secondsLeft <= 0) {
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;

    return AlertDialog(
      title: Text('${widget.playerName} 的連結碼'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.code,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _secondsLeft > 0
                ? '有效時間：${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
                : '已過期',
            style: TextStyle(
              fontSize: 16,
              color: _secondsLeft > 0 ? Colors.grey : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '請對方在「玩家管理」頁面輸入此連結碼',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
