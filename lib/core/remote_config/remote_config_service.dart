import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/ads_config.dart';
import '../ads/interstitial_policy.dart';

/// Remote Config knobs with local defaults.
///
/// After FlutterFire setup, swap [fetch] to read Firebase Remote Config.
/// Must not import `lib/game/`.
class RemoteConfigService {
  /// Creates a remote config service with [AdsConfig] defaults.
  RemoteConfigService({
    this.interstitialStartLevel = AdsConfig.interstitialStartLevel,
    this.interstitialEveryNLevels = AdsConfig.interstitialEveryNLevels,
    this.interstitialMinSeconds = AdsConfig.interstitialMinSeconds,
    this.freeUndosPerLevel = AdsConfig.freeUndosPerLevel,
  });

  int interstitialStartLevel;
  int interstitialEveryNLevels;
  int interstitialMinSeconds;
  int freeUndosPerLevel;

  /// No-op fetch until Firebase is wired; keeps defaults.
  Future<void> fetch() async {}

  /// Builds an [InterstitialPolicy] from current knobs.
  InterstitialPolicy get interstitialPolicy => InterstitialPolicy(
    startLevel: interstitialStartLevel,
    everyNLevels: interstitialEveryNLevels,
    minSeconds: interstitialMinSeconds,
  );
}

final remoteConfigProvider = Provider<RemoteConfigService>((_) {
  return RemoteConfigService();
});
