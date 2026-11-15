import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../config/ads_config.dart';
import '../analytics/analytics_service.dart';
import '../storage/save_service.dart';

/// Purchase state for the Shop UI.
enum ShopPurchaseState {
  /// Store not queried yet / idle.
  idle,

  /// Looking up the product.
  loading,

  /// Product ready to buy.
  ready,

  /// Purchase flow in progress.
  pending,

  /// Remove-ads owned.
  owned,

  /// Store unavailable or product missing.
  unavailable,
}

/// Non-consumable remove-ads purchase via [InAppPurchase].
///
/// Must not import `lib/game/`.
class PurchaseService extends Notifier<ShopPurchaseState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  /// Localized price string when available.
  String? get priceLabel => _product?.price;

  @override
  ShopPurchaseState build() {
    ref.onDispose(() => _sub?.cancel());
    if (SaveService.instance.adsRemoved) {
      return ShopPurchaseState.owned;
    }
    Future.microtask(initialize);
    return ShopPurchaseState.loading;
  }

  /// Connects to the store and loads the remove-ads product.
  Future<void> initialize() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      state = ShopPurchaseState.unavailable;
      return;
    }

    _sub ??= InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('IAP stream error: $e'),
    );

    final response = await InAppPurchase.instance.queryProductDetails({
      AdsConfig.removeAdsProductId,
    });
    if (response.error != null || response.productDetails.isEmpty) {
      debugPrint('IAP product query failed: ${response.error}');
      state = SaveService.instance.adsRemoved
          ? ShopPurchaseState.owned
          : ShopPurchaseState.unavailable;
      return;
    }

    _product = response.productDetails.first;
    state = SaveService.instance.adsRemoved
        ? ShopPurchaseState.owned
        : ShopPurchaseState.ready;
  }

  /// Starts the buy flow for remove-ads.
  Future<void> buyRemoveAds() async {
    if (_product == null || state == ShopPurchaseState.owned) return;
    state = ShopPurchaseState.pending;
    final param = PurchaseParam(productDetails: _product!);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  /// Restores previous purchases.
  Future<void> restore() async {
    state = ShopPurchaseState.pending;
    await InAppPurchase.instance.restorePurchases();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (state == ShopPurchaseState.pending) {
      state = SaveService.instance.adsRemoved
          ? ShopPurchaseState.owned
          : (_product != null
                ? ShopPurchaseState.ready
                : ShopPurchaseState.unavailable);
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AdsConfig.removeAdsProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await SaveService.instance.setAdsRemoved();
          ref.read(analyticsServiceProvider).removeAdsPurchased();
          state = ShopPurchaseState.owned;
        case PurchaseStatus.error:
          state = _product != null
              ? ShopPurchaseState.ready
              : ShopPurchaseState.unavailable;
        case PurchaseStatus.pending:
          state = ShopPurchaseState.pending;
        case PurchaseStatus.canceled:
          state = _product != null
              ? ShopPurchaseState.ready
              : ShopPurchaseState.unavailable;
      }

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }
}

final purchaseServiceProvider =
    NotifierProvider<PurchaseService, ShopPurchaseState>(PurchaseService.new);
