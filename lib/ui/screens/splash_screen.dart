import 'package:flutter/material.dart';

import '../../app.dart';
import '../../config/asset_paths.dart';
import '../../config/game_config.dart';
import '../widgets/game_ui.dart';

/// Brief branded splash that routes to [AppRoutes.home].
class SplashScreen extends StatefulWidget {
  /// Creates the splash screen.
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: GameConfig.splashDuration,
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(GameConfig.splashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.5, curve: Curves.elasticOut),
    );
    return Scaffold(
      body: GameBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(pop),
                child: Image.asset(
                  AssetPaths.appLogo,
                  semanticLabel: GameConfig.appName,
                  height: 200,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const OutlinedText(
                    GameConfig.appName,
                    fontSize: 44,
                    color: GameConfig.brandAccent,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => LinearProgressIndicator(
                      value: Curves.easeInOut.transform(_c.value),
                      minHeight: 10,
                      backgroundColor: const Color(0x55000000),
                      color: GameConfig.brandAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
