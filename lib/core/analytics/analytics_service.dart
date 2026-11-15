import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Typed analytics events for product insights.
///
/// Logs to debug console until Firebase is configured (see FIREBASE_SETUP.md).
/// Must not import `lib/game/`.
class AnalyticsService {
  /// Creates an analytics service.
  const AnalyticsService();

  void _log(String name, [Map<String, Object?> params = const {}]) {
    debugPrint('analytics:$name $params');
  }

  void levelStart(int level) => _log('level_start', {'level': level});

  void levelComplete({
    required int level,
    required int moves,
    required int stars,
    required int seconds,
  }) => _log('level_complete', {
    'level': level,
    'moves': moves,
    'stars': stars,
    'seconds': seconds,
  });

  void levelRestart(int level) => _log('level_restart', {'level': level});

  void levelStuck(int level) => _log('level_stuck', {'level': level});

  void undoUsed() => _log('undo_used');

  void rewardedOffer(String placement) =>
      _log('rewarded_offer', {'placement': placement});

  void rewardedWatched(String placement) =>
      _log('rewarded_watched', {'placement': placement});

  void interstitialShown() => _log('interstitial_shown');

  void removeAdsPurchased() => _log('remove_ads_purchased');

  void tutorialComplete() => _log('tutorial_complete');

  void dailyComplete(String dateKey) =>
      _log('daily_complete', {'date': dateKey});
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (_) => const AnalyticsService(),
);
