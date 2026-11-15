import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_paths.dart';
import '../../core/iap/purchase_service.dart';
import '../../core/storage/save_service.dart';
import '../widgets/asset_icon.dart';
import '../widgets/game_ui.dart';
import '../widgets/coin_widgets.dart';
import '../../core/rewards/wallet_provider.dart';
import '../../core/rewards/reward_rules.dart';
import '../../core/ads/ad_service.dart';
import '../../config/game_config.dart';

/// Shop: Remove Ads + Restore Purchases.
class ShopScreen extends ConsumerWidget {
  /// Creates the shop screen.
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(purchaseServiceProvider);
    final purchase = ref.read(purchaseServiceProvider.notifier);
    final adsRemoved =
        SaveService.instance.adsRemoved || status == ShopPurchaseState.owned;

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
            const SizedBox(height: 28),
            const AssetIcon(AssetPaths.shop, size: 72),
            const SizedBox(height: 16),
            Text(
              'Remove Ads',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              adsRemoved
                  ? 'Thanks! Interstitial ads are off. Rewarded helpers stay available.'
                  : 'One-time purchase. Removes interstitial ads forever. '
                        'Rewarded ads for Undo / +1 Jar / Skip stay available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (adsRemoved)
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Remove Ads — Owned'),
              )
            else ...[
              FilledButton(
                onPressed: status == ShopPurchaseState.ready
                    ? () => purchase.buyRemoveAds()
                    : null,
                child: Text(
                  status == ShopPurchaseState.pending
                      ? 'Processing…'
                      : status == ShopPurchaseState.loading
                      ? 'Loading…'
                      : status == ShopPurchaseState.unavailable
                      ? 'Store unavailable'
                      : 'Buy${purchase.priceLabel != null ? ' · ${purchase.priceLabel}' : ''}',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: status == ShopPurchaseState.pending
                    ? null
                    : () => purchase.restore(),
                child: const Text('Restore Purchases'),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Product id: remove_ads — create it in Play Console for test buys.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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
