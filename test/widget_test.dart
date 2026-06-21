import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paika/models/player_profile.dart';
import 'package:paika/widgets/player_avatar.dart';

void main() {
  // 註：App 根層與 Firebase 緊密耦合，整體啟動測試需 mock Firebase，
  // 此處改測不依賴 Firebase 的純 widget（emoji 類型頭像）。
  testWidgets('PlayerAvatar 在 emoji 類型時顯示對應 emoji', (WidgetTester tester) async {
    final profile = PlayerProfile(
      id: '1',
      accountId: 'acc',
      name: '測試玩家',
      emoji: '🐶',
      createdAt: DateTime(2026, 1, 1),
      lastPlayedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerAvatar(profile: profile, size: 40),
        ),
      ),
    );

    expect(find.text('🐶'), findsOneWidget);
  });
}
