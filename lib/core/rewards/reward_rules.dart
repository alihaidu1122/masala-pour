/// Pure reward maths: coins for wins, daily streak, chapter chests, prices.
///
/// No Flutter or game imports so it is easy to unit-test and reuse.
abstract final class RewardRules {
  /// Coins for a first-time win with [stars] (1–3). [difficultyTier]:
  /// 0 = normal, 1 = hard, 2 = super hard.
  static int levelCoins({required int stars, required int difficultyTier}) {
    final base = switch (stars) {
      >= 3 => 20,
      2 => 15,
      _ => 10,
    };
    return base * (difficultyTier + 1);
  }

  /// Coins for replaying an already-completed level (kept small on purpose).
  static const int replayCoins = 5;

  /// Coins for winning today's Daily Challenge (first time each day).
  static const int dailyChallengeCoins = 50;

  /// Coins for each day of the 7-day login streak (index 0 = day 1).
  static const List<int> loginRewards = [20, 30, 40, 50, 70, 100, 250];

  /// Coins in the chest for finishing chapter [chapterIndex] (0-based).
  static int chapterChestCoins(int chapterIndex) => 200 + 50 * chapterIndex;

  /// Price of one extra jar.
  static const int extraJarPrice = 120;

  /// Price of three more undos.
  static const int undoPackPrice = 60;

  /// Price of skipping a level.
  static const int skipPrice = 200;

  /// Coins for watching a "free coins" ad in the shop.
  static const int freeCoinsAd = 25;

  /// Login streak state for [today] given the last claim.
  ///
  /// Returns whether a reward can be claimed now and which streak day
  /// (1–7) it would be. Missing a day resets the streak to day 1.
  static ({bool canClaim, int day}) loginStatus({
    required DateTime today,
    required DateTime? lastClaim,
    required int lastDay,
  }) {
    final t = DateTime(today.year, today.month, today.day);
    if (lastClaim == null) return (canClaim: true, day: 1);
    final l = DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
    final gap = t.difference(l).inDays;
    if (gap <= 0) return (canClaim: false, day: lastDay.clamp(1, 7));
    if (gap == 1) return (canClaim: true, day: lastDay >= 7 ? 1 : lastDay + 1);
    return (canClaim: true, day: 1);
  }
}
