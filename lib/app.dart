import 'package:flutter/material.dart';

import 'config/game_config.dart';
import 'game/levels/level.dart';
import 'ui/screens/daily_screen.dart';
import 'ui/screens/game_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/level_select_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/shop_screen.dart';
import 'ui/screens/splash_screen.dart';

/// Named routes used by [MasalaSortApp].
abstract final class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String levelSelect = '/levels';
  static const String game = '/game';
  static const String settings = '/settings';
  static const String shop = '/shop';
  static const String daily = '/daily';
}

/// Arguments for [GameScreen] when launching campaign or daily levels.
class GameRouteArgs {
  /// Campaign level by id.
  const GameRouteArgs.campaign(this.levelId)
    : dailyKey = null,
      dailyLevel = null;

  /// Daily challenge with a pre-built [dailyLevel].
  GameRouteArgs.daily({required this.dailyKey, required Level dailyLevel})
    : dailyLevel = dailyLevel,
      levelId = dailyLevel.id;

  factory GameRouteArgs.from(Object? raw) {
    if (raw is GameRouteArgs) return raw;
    if (raw is int) return GameRouteArgs.campaign(raw);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final daily = map['dailyLevel'];
      final key = map['dailyKey'] as String?;
      if (daily is Level && key != null) {
        return GameRouteArgs.daily(dailyKey: key, dailyLevel: daily);
      }
      final id = map['levelId'];
      if (id is int) return GameRouteArgs.campaign(id);
    }
    return const GameRouteArgs.campaign(1);
  }

  final int levelId;
  final String? dailyKey;
  final Level? dailyLevel;
}

/// Root MaterialApp: theme, routes, portrait-friendly layout.
class MasalaSortApp extends StatelessWidget {
  /// Creates the app shell.
  const MasalaSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: GameConfig.bgGlow,
      brightness: Brightness.dark,
      primary: GameConfig.brandAccent,
      secondary: GameConfig.brandPrimary,
      surface: GameConfig.panel,
    );
    return MaterialApp(
      title: GameConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: GameConfig.bgDeep,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: GameConfig.bgMid,
          foregroundColor: GameConfig.textLight,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: GameConfig.textLight,
          ),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: GameConfig.panel),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? GameConfig.brandPrimary
                : null,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: GameConfig.brandPrimary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: GameConfig.brandAccent,
            side: const BorderSide(color: GameConfig.brandAccent, width: 1.4),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
      case AppRoutes.levelSelect:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LevelSelectScreen(),
        );
      case AppRoutes.game:
        final args = GameRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => GameScreen(
            level: args.levelId,
            dailyKey: args.dailyKey,
            dailyLevel: args.dailyLevel,
          ),
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.shop:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ShopScreen(),
        );
      case AppRoutes.daily:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DailyScreen(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
    }
  }
}
