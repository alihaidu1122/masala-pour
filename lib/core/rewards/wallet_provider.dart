import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/progress_provider.dart';
import '../storage/save_service.dart';
import 'reward_rules.dart';

/// Coin balance plus today's login-reward status.
class WalletState {
  /// Creates a wallet snapshot.
  const WalletState({
    required this.coins,
    required this.canClaimLogin,
    required this.loginDay,
  });

  /// Coins the player has.
  final int coins;

  /// Whether today's login reward is waiting.
  final bool canClaimLogin;

  /// Streak day (1–7) shown in the login calendar.
  final int loginDay;
}

/// Owns the coin balance and reward claims; writes through to [SaveService].
class WalletNotifier extends Notifier<WalletState> {
  /// Clock override for tests.
  DateTime Function() now = DateTime.now;

  SaveService get _svc => ref.read(saveServiceProvider);

  @override
  WalletState build() => _snapshot();

  WalletState _snapshot() {
    final status = RewardRules.loginStatus(
      today: now(),
      lastClaim: _svc.loginLastClaim,
      lastDay: _svc.loginDay,
    );
    return WalletState(
      coins: _svc.coins,
      canClaimLogin: status.canClaim,
      loginDay: status.day,
    );
  }

  /// Adds [amount] coins.
  Future<void> add(int amount) async {
    if (amount <= 0) return;
    await _svc.setCoins(_svc.coins + amount);
    state = _snapshot();
  }

  /// Spends [amount] coins if the balance allows. Returns success.
  Future<bool> trySpend(int amount) async {
    if (_svc.coins < amount) return false;
    await _svc.setCoins(_svc.coins - amount);
    state = _snapshot();
    return true;
  }

  /// Claims today's login reward. Returns the coins granted (0 if none).
  Future<int> claimLogin() async {
    final status = RewardRules.loginStatus(
      today: now(),
      lastClaim: _svc.loginLastClaim,
      lastDay: _svc.loginDay,
    );
    if (!status.canClaim) return 0;
    final amount = RewardRules.loginRewards[status.day - 1];
    await _svc.recordLoginClaim(now(), status.day);
    await _svc.setCoins(_svc.coins + amount);
    state = _snapshot();
    return amount;
  }

  /// Opens the chest for [chapterIndex] once. Returns coins (0 if opened).
  Future<int> claimChest(int chapterIndex) async {
    if (_svc.chestsClaimed.contains(chapterIndex)) return 0;
    final amount = RewardRules.chapterChestCoins(chapterIndex);
    await _svc.markChestClaimed(chapterIndex);
    await _svc.setCoins(_svc.coins + amount);
    state = _snapshot();
    return amount;
  }

  /// Pays Daily Challenge coins once per [dateKey]. Returns coins granted.
  Future<int> claimDailyChallenge(String dateKey) async {
    if (_svc.dailyCoinsPaid(dateKey)) return 0;
    await _svc.markDailyCoinsPaid(dateKey);
    await _svc.setCoins(_svc.coins + RewardRules.dailyChallengeCoins);
    state = _snapshot();
    return RewardRules.dailyChallengeCoins;
  }
}

/// Provides the [WalletNotifier].
final walletProvider = NotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);
