import 'package:flutter_test/flutter_test.dart';
import 'package:paika/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MahjongScorerApp());
    
    // Wait for the provider to initialize
    await tester.pumpAndSettle();

    // Verify that we can find the app title
    expect(find.text('🀄 麻將記分'), findsOneWidget);
    
    // Verify that we can find the start new game button
    expect(find.text('開始新局'), findsOneWidget);
  });
}
