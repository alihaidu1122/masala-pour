import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/core/rewards/reward_rules.dart';
import 'package:masala_sort/core/rewards/wallet_provider.dart';
import 'package:masala_sort/core/storage/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RewardRules', () {
    test('level coins scale with stars and difficulty', () {
      expect(RewardRules.levelCoins(stars: 1, difficultyTier: 0), 10);
      expect(RewardRules.levelCoins(stars: 3, difficultyTier: 0), 20);
      expect(RewardRules.levelCoins(stars: 3, difficultyTier: 1), 40);
      expect(RewardRules.levelCoins(stars: 2, difficultyTier: 2), 45);
    });

    test('login streak continues, wraps after 7, resets after a gap', () {
      final d = DateTime(2026, 11, 14);
      expect(RewardRules.loginStatus(today: d, lastClaim: null, lastDay: 0), (
        canClaim: true,
        day: 1,
      ));
      expect(
        RewardRules.loginStatus(today: d, lastClaim: d, lastDay: 3).canClaim,
        isFalse,
      );
      final yesterday = d.subtract(const Duration(days: 1));
      expect(
        RewardRules.loginStatus(today: d, lastClaim: yesterday, lastDay: 3),
        (canClaim: true, day: 4),
      );
      expect(
        RewardRules.loginStatus(today: d, lastClaim: yesterday, lastDay: 7).day,
        1,
      );
      expect(
        RewardRules.loginStatus(
          today: d,
          lastClaim: d.subtract(const Duration(days: 3)),
          lastDay: 5,
        ).day,
        1,
      );
    });

    test('chapter chests grow', () {
      expect(
        RewardRules.chapterChestCoins(3),
        greaterThan(RewardRules.chapterChestCoins(0)),
      );
    });
  });

  group('WalletNotifier', () {
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveService.init();
      c = ProviderContainer();
    });
    tearDown(() => c.dispose());

    test('add, spend and refuse overspending', () async {
      final w = c.read(walletProvider.notifier);
      await w.add(100);
      expect(c.read(walletProvider).coins, 100);
      expect(await w.trySpend(60), isTrue);
      expect(c.read(walletProvider).coins, 40);
      expect(await w.trySpend(60), isFalse);
      expect(c.read(walletProvider).coins, 40);
    });

    test('login reward can be claimed once per day', () async {
      final w = c.read(walletProvider.notifier)
        ..now = () => DateTime(2026, 11, 14);
      expect(await w.claimLogin(), RewardRules.loginRewards[0]);
      expect(await w.claimLogin(), 0);
      w.now = () => DateTime(2026, 11, 15);
      expect(await w.claimLogin(), RewardRules.loginRewards[1]);
    });

    test('chapter chest and daily challenge pay only once', () async {
      final w = c.read(walletProvider.notifier);
      expect(await w.claimChest(0), RewardRules.chapterChestCoins(0));
      expect(await w.claimChest(0), 0);
      expect(await w.claimDailyChallenge('2026-11-14'), 50);
      expect(await w.claimDailyChallenge('2026-11-14'), 0);
    });
  });
}
