import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../core/audio/sound_service.dart';
import '../../core/haptics/haptics_service.dart';
import '../../core/rewards/reward_rules.dart';
import '../../core/rewards/wallet_provider.dart';
import 'coin_widgets.dart';
import 'game_ui.dart';

/// Opens the 7-day login reward calendar.
Future<void> showDailyRewardDialog(BuildContext context) {
  return showGameDialog<void>(
    context,
    barrierDismissible: true,
    builder: (_) => const _DailyRewardDialog(),
  );
}

class _DailyRewardDialog extends ConsumerStatefulWidget {
  const _DailyRewardDialog();

  @override
  ConsumerState<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends ConsumerState<_DailyRewardDialog> {
  int _claimed = 0;

  Future<void> _claim() async {
    final amount = await ref.read(walletProvider.notifier).claimLogin();
    if (!mounted || amount == 0) return;
    ref.read(soundServiceProvider).playWin();
    ref.read(hapticsServiceProvider).win();
    setState(() => _claimed = amount);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final today = wallet.loginDay;
    final canClaim = wallet.canClaimLogin && _claimed == 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: GamePanel(
              padding: const EdgeInsets.fromLTRB(16, 44, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Come back every day for bigger rewards!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameConfig.textLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        _DayCard(
                          day: d,
                          coins: RewardRules.loginRewards[d - 1],
                          state: d < today || (d == today && !canClaim)
                              ? _DayState.claimed
                              : d == today
                              ? _DayState.today
                              : _DayState.later,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_claimed > 0)
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        OutlinedText(
                          '+$_claimed coins!',
                          fontSize: 28,
                          color: GameConfig.brandAccent,
                        ),
                        const Positioned(
                          top: -120,
                          child: CoinBurst(count: 14),
                        ),
                      ],
                    )
                  else
                    CandyButton(
                      label: canClaim ? 'Claim' : 'Come back tomorrow',
                      height: 58,
                      fontSize: canClaim ? 24 : 18,
                      icon: canClaim ? const CoinIcon(size: 30) : null,
                      onPressed: canClaim ? _claim : null,
                    ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      _claimed > 0 ? 'Awesome!' : 'Close',
                      style: const TextStyle(
                        color: GameConfig.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const RibbonTitle('Daily Reward', color: CandyColor.orange),
        ],
      ),
    );
  }
}

enum _DayState { claimed, today, later }

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.coins, required this.state});

  final int day;
  final int coins;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final big = day == 7;
    final colors = switch (state) {
      _DayState.today => const [Color(0xFF7BE05A), Color(0xFF3FAE2A)],
      _DayState.claimed => const [Color(0xFF6B4F8F), Color(0xFF4A3466)],
      _DayState.later => const [Color(0xFF8E4FD6), Color(0xFF5A1E9C)],
    };
    Widget card = Container(
      width: big ? 150 : 72,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border.all(
          color: state == _DayState.today
              ? Colors.white
              : const Color(0x55FFFFFF),
          width: state == _DayState.today ? 2.5 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Day $day',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (big)
                const Icon(
                  Icons.redeem_rounded,
                  color: Color(0xFFFFC93C),
                  size: 32,
                )
              else
                const CoinIcon(size: 28),
              const SizedBox(height: 4),
              Text(
                '$coins',
                style: const TextStyle(
                  color: GameConfig.brandAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (state == _DayState.claimed)
            const Positioned(
              right: -6,
              top: -6,
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF7BE05A),
                size: 20,
              ),
            ),
        ],
      ),
    );
    if (state == _DayState.today) card = Pulsing(child: card);
    return Opacity(opacity: state == _DayState.claimed ? 0.75 : 1, child: card);
  }
}
