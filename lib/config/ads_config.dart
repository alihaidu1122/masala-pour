import 'package:flutter/foundation.dart';

/// Ad unit IDs and default frequency knobs.
///
/// Debug builds always use Google's official test unit IDs.
/// Replace production IDs before releasing.
class AdsConfig {
  AdsConfig._();

  /// Google sample AdMob **app** id (Android). Replace for release.
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// No interstitial ads before this level (1-based).
  static const int interstitialStartLevel = 10;

  /// Show at most one interstitial every N completed levels.
  static const int interstitialEveryNLevels = 3;

  /// Minimum seconds between interstitials.
  static const int interstitialMinSeconds = 90;

  /// Free undos granted at the start of each level (also Remote Config).
  static const int freeUndosPerLevel = 3;

  // --- Google official Android test unit IDs ---
  // https://developers.google.com/admob/android/test-ads
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // --- Production unit IDs (replace before Play release) ---
  static const String releaseInterstitialAdUnitId =
      'ca-app-pub-XXXX/INTERSTITIAL';
  static const String releaseRewardedAdUnitId = 'ca-app-pub-XXXX/REWARDED';

  /// Interstitial unit for the current build mode.
  static String get interstitialAdUnitId =>
      kReleaseMode ? releaseInterstitialAdUnitId : testInterstitialAdUnitId;

  /// Rewarded unit for the current build mode.
  static String get rewardedAdUnitId =>
      kReleaseMode ? releaseRewardedAdUnitId : testRewardedAdUnitId;

  /// IAP product id for remove-ads (Play Console).
  static const String removeAdsProductId = 'remove_ads';
}
