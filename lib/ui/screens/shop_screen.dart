import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_paths.dart';
import '../widgets/asset_icon.dart';
import '../widgets/game_ui.dart';
import '../widgets/coin_widgets.dart';
import '../../core/rewards/wallet_provider.dart';
import '../../core/rewards/reward_rules.dart';
import '../../core/ads/ad_service.dart';
import '../../config/game_config.dart';

/// Shop: coins, free coins for an optional video, and helper prices.
///
/// The Remove Ads purchase is hidden for now: the game has no forced ads.
class ShopScreen extends ConsumerWidget {
  /// Creates the shop screen.
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Shop'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _CoinsSection(),
            const SizedBox(height: 18),
            const Text(
              'No forced ads: videos only play when you choose one for a '
              'helper or free coins.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GameConfig.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coin balance, free coins for an ad, and what coins buy.
class _CoinsSection extends ConsumerWidget {
  const _CoinsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinIcon(size: 40),
              const SizedBox(width: 10),
              CoinCountUp(
                value: wallet.coins,
                style: const TextStyle(
                  color: GameConfig.brandAccent,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CandyButton(
            label: 'Free coins',
            subtitle: 'Watch ad · +${RewardRules.freeCoinsAd}',
            color: CandyColor.blue,
            height: 58,
            icon: const AssetIcon(AssetPaths.play, size: 30),
            onPressed: () async {
              final ok = await ref
                  .read(adServiceProvider)
                  .showRewarded(RewardedPlacement.freeCoins);
              if (ok) {
                await ref
                    .read(walletProvider.notifier)
                    .add(RewardRules.freeCoinsAd);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ad not available, try again later'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 14),
          const _PriceRow(
            asset: AssetPaths.addJar,
            label: '+1 Jar',
            price: RewardRules.extraJarPrice,
          ),
          const _PriceRow(
            asset: AssetPaths.undo,
            label: '+3 Undos',
            price: RewardRules.undoPackPrice,
          ),
          const _PriceRow(
            asset: AssetPaths.skip,
            label: 'Skip level',
            price: RewardRules.skipPrice,
          ),
          const SizedBox(height: 6),
          const Text(
            'Earn coins by winning levels, daily rewards and chapter chests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GameConfig.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.asset,
    required this.label,
    required this.price,
  });
  final String asset;
  final String label;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AssetIcon(asset, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: GameConfig.textLight,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const CoinIcon(size: 18),
          const SizedBox(width: 4),
          Text(
            '$price',
            style: const TextStyle(
              color: GameConfig.brandAccent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
