import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/hand_pattern.dart';
import '../providers/game_provider.dart';

/// 自訂牌型管理頁面
class CustomPatternsScreen extends StatelessWidget {
  const CustomPatternsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自訂牌型'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增',
            onPressed: () => _showAddPatternDialog(context),
          ),
        ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          final customPatterns = provider.settings.customPatterns;
          final systemPatterns = HandPattern.systemPatterns;

          return ListView(
            children: [
              // 系統預設（唯讀，僅供參考）
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '系統預設',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              ...systemPatterns.map((p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.lock_outline, size: 16),
                    title: Text(p.name),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${p.referenceTai} 台',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )),

              const Divider(height: 32),

              // 使用者自訂
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '我的牌型',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('新增'),
                      onPressed: () => _showAddPatternDialog(context),
                    ),
                  ],
                ),
              ),

              if (customPatterns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('尚無自訂牌型', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...customPatterns.map((p) => ListTile(
                      title: Text(p.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${p.referenceTai} 台',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deletePattern(context, provider, p.id),
                          ),
                        ],
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  void _showAddPatternDialog(BuildContext context) {
    final provider = context.read<GameProvider>();
    final nameCtrl = TextEditingController();
    int tai = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增牌型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '牌型名稱',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('參考台數：'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: tai > 0
                        ? () => setDialogState(() => tai--)
                        : null,
                  ),
                  Text('$tai', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setDialogState(() => tai++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final newPattern = HandPattern(
                  id: const Uuid().v4(),
                  name: name,
                  referenceTai: tai,
                  isSystem: false,
                );
                final updated = [...provider.settings.customPatterns, newPattern];
                provider.updateSettings(
                  provider.settings.copyWith(customPatterns: updated),
                );
                Navigator.pop(ctx);
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePattern(BuildContext context, GameProvider provider, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除牌型'),
        content: const Text('確定要刪除這個自訂牌型嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final updated = provider.settings.customPatterns
                  .where((p) => p.id != id)
                  .toList();
              provider.updateSettings(
                provider.settings.copyWith(customPatterns: updated),
              );
              Navigator.pop(ctx);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
