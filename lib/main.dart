import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'services/auth_service.dart';
import 'services/firebase_init_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitService.initialize();
  runApp(const MahjongScorerApp());
}

class MahjongScorerApp extends StatelessWidget {
  const MahjongScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..initialize()),
        ChangeNotifierProxyProvider<AuthService, GameProvider>(
          create: (_) => GameProvider(),
          update: (_, authService, gameProvider) {
            return gameProvider!..onAuthChanged(authService);
          },
        ),
      ],
      child: Consumer2<AuthService, GameProvider>(
        builder: (context, authService, gameProvider, _) {
          return MaterialApp(
            title: '牌咖 Paika',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: gameProvider.themeMode,
            // 繁體中文在地化（日期選擇器等 Material/Cupertino 內建元件）
            locale: const Locale('zh', 'TW'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'TW'),
              Locale('zh', 'HK'),
              Locale('en'),
            ],
            home: authService.isLoggedIn ? const HomeScreen() : const AuthScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
