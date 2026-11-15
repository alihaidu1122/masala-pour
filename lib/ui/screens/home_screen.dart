import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/asset_paths.dart';
import '../../config/game_config.dart';
import '../../core/audio/sound_service.dart';
import '../../core/haptics/haptics_service.dart';
import '../../core/storage/progress_provider.dart';
import '../widgets/asset_icon.dart';
import '../widgets/game_ui.dart';
import '../widgets/daily_reward_dialog.dart';
import '../widgets/coin_widgets.dart';
import '../../core/rewards/wallet_provider.dart';

/// Main menu: Play (continue), Level Select, Daily, Settings, Shop.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final level = progress.currentLevel;

    void feedback() {
      ref.read(soundServiceProvider).playClick();
      ref.read(hapticsServiceProvider).tap();
    }

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final logoH = (box.maxHeight * 0.26).clamp(140.0, 230.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const _HomeTopBar(),
                    const Spacer(flex: 2),
                    EntranceFade(
                      offsetY: -30,
                      child: Bobbing(
                        child: Image.asset(
                          AssetPaths.appLogo,
                          height: logoH,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => OutlinedText(
                            GameConfig.appName,
                            fontSize: 44,
                            color: GameConfig.brandAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const EntranceFade(
                      delay: Duration(milliseconds: 120),
                      child: Text(
                        GameConfig.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: GameConfig.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    EntranceFade(
                      delay: const Duration(milliseconds: 200),
                      child: Pulsing(
                        child: CandyButton(
                          label: 'Play',
                          subtitle: level > 1 ? 'Level $level' : null,
                          height: 72,
                          fontSize: 30,
                          icon: const AssetIcon(AssetPaths.play, size: 40),
                          onPressed: () {
                            feedback();
                            Navigator.of(context)
                                .pushNamed(AppRoutes.game, arguments: level);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    EntranceFade(
                      delay: const Duration(milliseconds: 280),
                      child: CandyButton(
                        label: 'Level Select',
                        color: CandyColor.purple,
                        height: 54,
                        fontSize: 20,
                        icon: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          feedback();
                          Navigator.of(context)
                              .pushNamed(AppRoutes.levelSelect);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    EntranceFade(
                      delay: const Duration(milliseconds: 360),
                      child: CandyButton(
                        label: 'Daily Challenge',
                        color: CandyColor.orange,
                        height: 54,
                        fontSize: 20,
                        icon: const AssetIcon(AssetPaths.daily, size: 30),
                        onPressed: () {
                          feedback();
                          Navigator.of(context).pushNamed(AppRoutes.daily);
                        },
                      ),
                    ),
                    const Spacer(flex: 2),
                    EntranceFade(
                      delay: const Duration(milliseconds: 440),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          RoundIconButton(
                            label: 'Settings',
                            onPressed: () {
                              feedback();
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.settings);
                            },
                            child: const AssetIcon(
                              AssetPaths.settings,
                              size: 40,
                            ),
                          ),
                          RoundIconButton(
                            label: 'Shop',
                            onPressed: () {
                              feedback();
                              Navigator.of(context).pushNamed(AppRoutes.shop);
                            },
                            child: const AssetIcon(AssetPaths.shop, size: 40),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Gift (daily reward) button and coin balance. Opens the daily reward
/// automatically once per app session when it is waiting.
class _HomeTopBar extends ConsumerStatefulWidget {
  const _HomeTopBar();

  static bool _autoShown = false;

  @override
  ConsumerState<_HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends ConsumerState<_HomeTopBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _HomeTopBar._autoShown || isUnderTest) return;
      if (ref.read(walletProvider).canClaimLogin) {
        _HomeTopBar._autoShown = true;
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) showDailyRewardDialog(context);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            RoundIconButton(
              size: 48,
              tooltip: 'Daily reward',
              onPressed: () => showDailyRewardDialog(context),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFFFFC93C),
                size: 28,
              ),
            ),
            if (wallet.canClaimLogin)
              Positioned(
                right: 2,
                top: 2,
                child: Pulsing(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        CoinPill(
          amount: wallet.coins,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.shop),
        ),
      ],
    );
  }
}
