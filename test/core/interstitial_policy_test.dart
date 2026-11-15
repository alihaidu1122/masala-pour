import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/core/ads/interstitial_policy.dart';

void main() {
  const policy = InterstitialPolicy(
    startLevel: 10,
    everyNLevels: 3,
    minSeconds: 90,
  );

  test('blocks before start level', () {
    expect(
      policy.canShow(
        completedLevelId: 9,
        levelsCompletedSinceLastAd: 99,
        adsRemoved: false,
      ),
      isFalse,
    );
  });

  test('blocks when ads removed', () {
    expect(
      policy.canShow(
        completedLevelId: 12,
        levelsCompletedSinceLastAd: 3,
        adsRemoved: true,
      ),
      isFalse,
    );
  });

  test('blocks until every N levels completed', () {
    expect(
      policy.canShow(
        completedLevelId: 12,
        levelsCompletedSinceLastAd: 2,
        adsRemoved: false,
      ),
      isFalse,
    );
    expect(
      policy.canShow(
        completedLevelId: 12,
        levelsCompletedSinceLastAd: 3,
        adsRemoved: false,
      ),
      isTrue,
    );
  });

  test('blocks when too soon since last ad', () {
    expect(
      policy.canShow(
        completedLevelId: 15,
        levelsCompletedSinceLastAd: 3,
        adsRemoved: false,
        secondsSinceLastAd: const Duration(seconds: 30),
      ),
      isFalse,
    );
    expect(
      policy.canShow(
        completedLevelId: 15,
        levelsCompletedSinceLastAd: 3,
        adsRemoved: false,
        secondsSinceLastAd: const Duration(seconds: 90),
      ),
      isTrue,
    );
  });

  test('allows when never shown before and thresholds met', () {
    expect(
      policy.canShow(
        completedLevelId: 10,
        levelsCompletedSinceLastAd: 3,
        adsRemoved: false,
      ),
      isTrue,
    );
  });
}
