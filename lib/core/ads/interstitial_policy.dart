import '../../config/ads_config.dart';

/// Decides when an interstitial may be shown after a win → next transition.
///
/// Rules (defaults from [AdsConfig], overridable via Remote Config):
/// - Never before [startLevel]
/// - At most one every [everyNLevels] completed levels
/// - At least [minSeconds] between shows
/// - Never after loss/restart (caller must only ask on win→next)
/// - Off when [adsRemoved] is true
class InterstitialPolicy {
  /// Creates a policy with optional Remote Config overrides.
  const InterstitialPolicy({
    this.startLevel = AdsConfig.interstitialStartLevel,
    this.everyNLevels = AdsConfig.interstitialEveryNLevels,
    this.minSeconds = AdsConfig.interstitialMinSeconds,
  });

  final int startLevel;
  final int everyNLevels;
  final int minSeconds;

  /// Whether an interstitial may show now.
  ///
  /// [completedLevelId] is the level just finished (1-based).
  /// [levelsCompletedSinceLastAd] counts wins since the last interstitial.
  /// [secondsSinceLastAd] is elapsed time since the last show (null = never).
  bool canShow({
    required int completedLevelId,
    required int levelsCompletedSinceLastAd,
    required bool adsRemoved,
    Duration? secondsSinceLastAd,
  }) {
    if (adsRemoved) return false;
    if (completedLevelId < startLevel) return false;
    if (everyNLevels <= 0) return false;
    if (levelsCompletedSinceLastAd < everyNLevels) return false;
    if (secondsSinceLastAd != null &&
        secondsSinceLastAd.inSeconds < minSeconds) {
      return false;
    }
    return true;
  }
}
