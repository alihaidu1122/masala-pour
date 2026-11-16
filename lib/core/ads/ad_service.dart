import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/ads_config.dart';
import '../storage/save_service.dart';
import 'consent_service.dart';
import 'interstitial_policy.dart';

/// Placement ids for rewarded ads (analytics + UI messaging).
abstract final class RewardedPlacement {
  static const String undo = 'undo';
  static const String extraJar = 'extra_jar';
  static const String skip = 'skip';
  static const String freeCoins = 'free_coins';
}

/// Loads and shows rewarded / interstitial ads via AdMob.
///
/// Must not import `lib/game/`.
class AdService {
  /// Creates an ad service.
  AdService({ConsentService? consent, InterstitialPolicy? policy})
    : _consent = consent ?? ConsentService(),
      _policy = policy ?? const InterstitialPolicy();

  final ConsentService _consent;
  final InterstitialPolicy _policy;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _initialized = false;

  int _levelsSinceInterstitial = 0;
  DateTime? _lastInterstitialAt;

  ConsentService get consent => _consent;

  bool _muted = !SaveServiceSound.soundOn;

  /// Mutes ad audio (follows the game's sound setting).
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (!_initialized) return;
    try {
      await MobileAds.instance.setAppMuted(muted);
      await MobileAds.instance.setAppVolume(muted ? 0 : 1);
    } catch (e) {
      debugPrint('AdService mute failed: $e');
    }
  }

  /// Initializes Mobile Ads after consent, then preloads one of each ad.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _consent.gatherConsent();
      await MobileAds.instance.initialize();
      // Family-safe ads only (no mature / suggestive content).
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      _initialized = true;
      await setMuted(_muted);
      await Future.wait([
        _loadRewarded(),
        if (AdsConfig.interstitialsEnabled) _loadInterstitial(),
      ]);
    } catch (e) {
      debugPrint('AdService init failed: $e');
    }
  }

  Future<void> _loadRewarded() async {
    final completer = Completer<void>();
    await RewardedAd.load(
      adUnitId: AdsConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded load failed: ${error.message}');
          _rewarded = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    return completer.future;
  }

  Future<void> _loadInterstitial() async {
    final completer = Completer<void>();
    await InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial load failed: ${error.message}');
          _interstitial = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    return completer.future;
  }

  /// Starts loading a rewarded video if none is ready.
  Future<void> preloadRewarded() async {
    if (_rewarded == null && _initialized) await _loadRewarded();
  }

  /// Whether a rewarded video is loaded and ready to show.
  bool get isRewardedReady => _rewarded != null;

  /// Shows a rewarded ad. Returns true only if the user earned the reward.
  Future<bool> showRewarded(String placement) async {
    final ad = _rewarded;
    if (ad == null) {
      await _loadRewarded();
      return false;
    }

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        unawaited(_loadRewarded());
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded show failed: ${error.message}');
        ad.dispose();
        _rewarded = null;
        unawaited(_loadRewarded());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );

    return completer.future;
  }

  /// Records a level completion toward interstitial frequency.
  void onLevelCompleted() {
    _levelsSinceInterstitial++;
  }

  /// Shows an interstitial on win→next if policy allows.
  /// Returns true if an ad was shown.
  Future<bool> maybeShowInterstitialAfterWin({
    required int completedLevelId,
  }) async {
    if (!AdsConfig.interstitialsEnabled) return false;
    final adsRemoved = SaveService.instance.adsRemoved;
    final elapsed = _lastInterstitialAt == null
        ? null
        : DateTime.now().difference(_lastInterstitialAt!);

    final allowed = _policy.canShow(
      completedLevelId: completedLevelId,
      levelsCompletedSinceLastAd: _levelsSinceInterstitial,
      adsRemoved: adsRemoved,
      secondsSinceLastAd: elapsed,
    );
    if (!allowed) return false;

    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        unawaited(_loadInterstitial());
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitial = null;
        unawaited(_loadInterstitial());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show();
    _levelsSinceInterstitial = 0;
    _lastInterstitialAt = DateTime.now();
    return completer.future;
  }
}

/// App-wide [AdService]. Prefer overriding in [main] after [AdService.initialize].
final adServiceProvider = Provider<AdService>((ref) => AdService());

/// Reads the saved sound flag without depending on the settings layer.
abstract final class SaveServiceSound {
  static bool get soundOn {
    try {
      return SaveService.instance.loadSettings().soundOn;
    } catch (_) {
      return true;
    }
  }
}
