import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/hand_pattern.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../utils/legal_texts.dart';
import '../widgets/animation_helpers.dart';
import 'custom_patterns_screen.dart';
import 'legal_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _falseWinPayAll;
  late int _falseWinTai;
  String _version = '載入中...';
  String? _accountAvatarData;
  bool _avatarLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<GameProvider>().settings;
    _falseWinPayAll = settings.falseWinPayAll;
    _falseWinTai = settings.falseWinTai;
    _loadVersion();
    _loadAccountAvatar();
  }

  Future<void> _loadAccountAvatar() async {
    final data = await FirestoreService.loadAccountAvatar();
    if (mounted) setState(() => _accountAvatarData = data);
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _avatarLoading = true);
    try {
      final base64Data = await AvatarService.pickImageAsBase64();
      if (base64Data == null) return;

      final url = await AvatarService.uploadAccountAvatarFromBase64(base64Data);
      if (url != null && mounted) {
        setState(() => _accountAvatarData = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('大頭照已更新')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  Widget _buildAvatarWidget(String initial) {
    if (_accountAvatarData != null) {
      try {
        final base64String = _accountAvatarData!.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        // fallback
      }
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _saveSettings() async {
    final provider = context.read<GameProvider>();
    final current = provider.settings;
    await provider.updateSettings(current.copyWith(
      falseWinPayAll: _falseWinPayAll,
      falseWinTai: _falseWinTai,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          return ListView(
            children: [
              // 帳號資訊
              _buildSectionHeader('帳號'),
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  final name = auth.displayName ?? '';
                  final email = auth.email ?? '';
                  final initial = (name.isNotEmpty
                          ? name[0]
                          : email.isNotEmpty
                              ? email[0]
                              : '?')
                      .toUpperCase();
                  return ListTile(
                    leading: GestureDetector(
                      onTap: _avatarLoading ? null : _pickAndUploadAvatar,
                      child: Stack(
                        children: [
                          _buildAvatarWidget(initial),
                          if (_avatarLoading)
                            const Positioned.fill(
                              child: CircleAvatar(
                                backgroundColor: Colors.black38,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      name.isNotEmpty ? name : '（未設定名稱）',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email),
                        const Text(
                          '點擊大頭照可上傳',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // 遊戲規則
              _buildSectionHeader('遊戲規則'),

              SwitchListTile(
                title: const Text('詐胡賠三家'),
                subtitle: Text(
                  _falseWinPayAll ? '詐胡賠付所有玩家' : '詐胡僅賠付莊家',
                ),
                value: _falseWinPayAll,
                onChanged: (value) {
                  setState(() => _falseWinPayAll = value);
                  _saveSettings();
                },
              ),

              const Divider(height: 1),

              ListTile(
                title: const Text('詐胡台數'),
                subtitle: Text('詐胡賠付 $_falseWinTai 台'),
                trailing: SizedBox(
                  width: 140,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _falseWinTai > 1
                            ? () {
                                setState(() => _falseWinTai--);
                                _saveSettings();
                              }
                            : null,
                      ),
                      Text(
                        '$_falseWinTai',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() => _falseWinTai++);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 自訂牌型
              _buildSectionHeader('牌型'),
              ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('自訂牌型'),
                subtitle: Text(
                  '系統 ${HandPattern.systemPatterns.length} 種'
                  ' + 自訂 ${provider.settings.customPatterns.length} 種',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomPatternsScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 外觀
              _buildSectionHeader('外觀'),

              ListTile(
                title: const Text('深色模式'),
                subtitle: Text(_themeModeLabel(provider.themeMode)),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('自動'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('淺色'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('深色'),
                    ),
                  ],
                  selected: {provider.themeMode},
                  onSelectionChanged: (modes) {
                    provider.updateThemeMode(modes.first);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 音效
              _buildSectionHeader('音效'),

              SwitchListTile(
                title: const Text('音效'),
                subtitle: const Text('即將推出'),
                value: false,
                onChanged: null,
              ),

              const SizedBox(height: 16),

              // 資料管理
              _buildSectionHeader('資料管理'),

              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('匯出所有牌局'),
                subtitle: const Text('JSON 格式'),
                onTap: () {
                  final games = provider.gameHistory;
                  if (games.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('沒有牌局可匯出')),
                    );
                    return;
                  }
                  final json = ExportService.exportAllGamesToJson(games);
                  ExportService.shareText(json, 'paika_all_games.json');
                },
              ),

              const SizedBox(height: 32),

              // 關於
              _buildSectionHeader('關於'),

              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('使用手冊'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    FadeSlidePageRoute(page: const HelpScreen()),
                  );
                },
              ),

              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('服務條款'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    FadeSlidePageRoute(
                      page: const LegalScreen(
                        title: '服務條款',
                        content: LegalTexts.termsOfService,
                      ),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('隱私權政策'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    FadeSlidePageRoute(
                      page: const LegalScreen(
                        title: '隱私權政策',
                        content: LegalTexts.privacyPolicy,
                      ),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              ListTile(
                title: const Text('版本'),
                subtitle: Text(_version),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟隨系統';
      case ThemeMode.light:
        return '淺色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }
}
