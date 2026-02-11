import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/game_provider.dart';
import '../models/player.dart';
import '../models/settings.dart';
import '../utils/constants.dart';
import '../widgets/animation_helpers.dart';
import 'game_play_screen.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final _uuid = const Uuid();
  
  // 玩家資料
  late List<Player> _players;
  
  // 設定
  int _baseScore = 50;
  int _maxTai = 20;
  bool _selfDrawAddTai = true;
  bool _dealerTai = true;
  bool _consecutiveTai = true;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化預設玩家
    _players = List.generate(4, (index) {
      return Player(
        id: _uuid.v4(),
        name: AppConstants.defaultNames[index],
        emoji: AppConstants.defaultEmojis[index],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新局設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 底台設定
            _buildScoreSettings(),
            const SizedBox(height: 32),
            
            // 進階設定
            _buildAdvancedSettings(),
            const SizedBox(height: 32),
            
            // 玩家設定
            _buildPlayersSection(),
            const SizedBox(height: 32),
            
            // 開始按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                child: const Text(
                  '開始打牌',
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '底台設定',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // 快速選擇
        const Text('快速選擇：', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GameSettings.defaultCombinations.map((combo) {
            final base = combo['base']!;
            final max = combo['max']!;
            final isSelected = base == _baseScore && max == _maxTai;
            
            return FilterChip(
              label: Text('$base×$max'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _baseScore = base;
                  _maxTai = max;
                });
              },
            );
          }).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // 自訂底分
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('底：', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 3,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: '元',
                  isDense: true,
                ),
                controller: TextEditingController(text: _baseScore.toString()),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() {
                      _baseScore = parsed;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 上限台數
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('台：', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 3,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: '台',
                  isDense: true,
                ),
                controller: TextEditingController(text: _maxTai.toString()),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() {
                      _maxTai = parsed;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '進階設定',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        SwitchListTile(
          title: const Text('自摸加台', style: TextStyle(fontSize: 16)),
          subtitle: const Text('自摸時額外加 1 台', style: TextStyle(fontSize: 14)),
          value: _selfDrawAddTai,
          onChanged: (value) {
            setState(() {
              _selfDrawAddTai = value;
            });
          },
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        
        SwitchListTile(
          title: const Text('自動計算莊家台數', style: TextStyle(fontSize: 16)),
          subtitle: const Text('莊家胡牌自動多算 1 台', style: TextStyle(fontSize: 14)),
          value: _dealerTai,
          onChanged: (value) {
            setState(() {
              _dealerTai = value;
            });
          },
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        
        SwitchListTile(
          title: const Text('自動計算連莊台數', style: TextStyle(fontSize: 16)),
          subtitle: const Text('連莊時自動多算對應台數', style: TextStyle(fontSize: 14)),
          value: _consecutiveTai,
          onChanged: (value) {
            setState(() {
              _consecutiveTai = value;
            });
          },
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ],
    );
  }

  Widget _buildPlayersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '玩家設定',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // 四個玩家
        Column(
          children: List.generate(4, (index) {
            return _buildPlayerCard(index);
          }),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(int index) {
    final player = _players[index];
    final windName = AppConstants.windNames[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 風位
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  windName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Emoji
            InkWell(
              onTap: () => _editEmoji(index),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  player.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 名稱
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '輸入名稱',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: TextEditingController(text: player.name),
                onChanged: (value) {
                  setState(() {
                    _players[index] = player.copyWith(name: value);
                  });
                },
              ),
            ),

            const SizedBox(width: 8),

            // 選擇已有玩家
            IconButton(
              icon: const Icon(Icons.person_search, size: 24),
              tooltip: '選擇已有玩家',
              onPressed: () => _showProfilePicker(index),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePicker(int index) {
    final profiles = context.read<GameProvider>().playerProfiles;
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未登錄任何玩家，請先到「玩家管理」新增')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('選擇已有玩家', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: profiles.length,
                  itemBuilder: (context, i) {
                    final profile = profiles[i];
                    return ListTile(
                      leading: Text(profile.emoji, style: const TextStyle(fontSize: 28)),
                      title: Text(profile.name),
                      onTap: () {
                        setState(() {
                          _players[index] = _players[index].copyWith(
                            userId: profile.id,
                            name: profile.name,
                            emoji: profile.emoji,
                          );
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editEmoji(int index) {
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
              children: [
                '🦁', '🐱', '🐸', '🐼', '🐶', '🐰', '🐻', '🦊',
                '🐯', '🐷', '🐮', '🐵', '🦅', '🦉', '🐧', '🦆',
              ].map((emoji) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _players[index] = _players[index].copyWith(emoji: emoji);
                    });
                    Navigator.pop(context);
                  },
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startGame() async {
    // 驗證
    if (_players.any((p) => p.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫所有玩家名稱')),
      );
      return;
    }

    final settings = GameSettings(
      baseScore: _baseScore,
      maxTai: _maxTai,
      selfDrawAddTai: _selfDrawAddTai,
      dealerTai: _dealerTai,
      consecutiveTai: _consecutiveTai,
    );

    final provider = context.read<GameProvider>();
    await provider.createGame(
      players: _players,
      customSettings: settings,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        FadeSlidePageRoute(page: const GamePlayScreen()),
      );
    }
  }
}
