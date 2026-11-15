import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/asset_paths.dart';
import '../../config/game_config.dart';
import 'asset_icon.dart';
import 'coin_widgets.dart';
import 'game_ui.dart';

/// Shared game dialogs: Win, Stuck, Out-of-undos.
///
/// All open with a pop-in animation and are non-dismissible except
/// Out-of-undos (the player must choose an action).
/// How the player chose to get a helper.
enum HelperChoice {
  /// Watched a rewarded ad.
  ad,

  /// Paid with coins.
  coins,
}

abstract final class GameDialogs {
  /// Shows the level-complete dialog.
  static Future<void> showWin(
    BuildContext context, {
    required int level,
    required int stars,
    required int moves,
    required int? par,
    required VoidCallback onNext,
    required VoidCallback onReplay,
    int coins = 0,
    int chestCoins = 0,
    String? chestLabel,
  }) {
    return showGameDialog<void>(
      context,
      builder: (_) => _WinDialog(
        level: level,
        stars: stars,
        moves: moves,
        par: par,
        onNext: onNext,
        onReplay: onReplay,
        coins: coins,
        chestCoins: chestCoins,
        chestLabel: chestLabel,
      ),
    );
  }

  /// Shows the "No moves left" dialog.
  static Future<void> showStuck(
    BuildContext context, {
    required bool canUndo,
    required bool canAddJar,
    required bool canSkip,
    required VoidCallback onUndo,
    required VoidCallback onRestart,
    required VoidCallback onAddJar,
    required VoidCallback onSkip,
  }) {
    return showGameDialog<void>(
      context,
      builder: (_) => _StuckDialog(
        canUndo: canUndo,
        canAddJar: canAddJar,
        canSkip: canSkip,
        onUndo: onUndo,
        onRestart: onRestart,
        onAddJar: onAddJar,
        onSkip: onSkip,
      ),
    );
  }

  /// Offers a helper for an ad or coins. Resolves to the player's choice,
  /// or null when dismissed.
  static Future<HelperChoice?> showHelperOffer(
    BuildContext context, {
    required String title,
    required String description,
    required String asset,
    required int price,
    required int coins,
  }) {
    return showGameDialog<HelperChoice>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _HelperOfferDialog(
        title: title,
        description: description,
        asset: asset,
        price: price,
        coins: coins,
      ),
    );
  }

  /// Shows the "Out of undos" dialog.
  static Future<void> showOutOfUndos(
    BuildContext context, {
    required VoidCallback onWatchAd,
    required VoidCallback onDismiss,
  }) {
    return showGameDialog<void>(
      context,
      barrierDismissible: true,
      builder: (_) =>
          _OutOfUndosDialog(onWatchAd: onWatchAd, onDismiss: onDismiss),
    );
  }
}

/// Panel with a ribbon title overlapping its top edge.
class _RibbonPanel extends StatelessWidget {
  const _RibbonPanel({
    required this.title,
    required this.child,
    this.color = CandyColor.orange,
  });

  final String title;
  final Widget child;
  final CandyColor color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: GamePanel(
              padding: const EdgeInsets.fromLTRB(20, 46, 20, 20),
              child: child,
            ),
          ),
          RibbonTitle(title, color: color),
        ],
      ),
    );
  }
}

// ── Win ──────────────────────────────────────────────────────────────────────

class _WinDialog extends StatefulWidget {
  const _WinDialog({
    required this.level,
    required this.stars,
    required this.moves,
    required this.par,
    required this.onNext,
    required this.onReplay,
    this.coins = 0,
    this.chestCoins = 0,
    this.chestLabel,
  });

  final int level;
  final int stars;
  final int moves;
  final int? par;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final int coins;
  final int chestCoins;
  final String? chestLabel;

  @override
  State<_WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<_WinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _star(int i) {
    final on = i < widget.stars;
    final start = 0.2 + i * 0.18;
    final anim = CurvedAnimation(
      parent: _c,
      curve: Interval(
        start,
        (start + 0.35).clamp(0, 1),
        curve: Curves.elasticOut,
      ),
    );
    final size = i == 1 ? 76.0 : 60.0;
    return Padding(
      padding: EdgeInsets.only(top: i == 1 ? 0 : 18, left: 2, right: 2),
      child: ScaleTransition(
        scale: anim,
        child: RotationTransition(
          turns: Tween(begin: -0.15, end: 0.0).animate(anim),
          child: Image.asset(
            on ? AssetPaths.starOn : AssetPaths.starOff,
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(
              on ? Icons.star_rounded : Icons.star_border_rounded,
              color: GameConfig.brandAccent,
              size: size,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final par = widget.par;
    final title = widget.level <= 0
        ? 'Daily Complete!'
        : 'Level ${widget.level} Complete!';
    final praise = switch (widget.stars) {
      3 => 'Perfect pour!',
      2 => 'Great job!',
      _ => 'Well done!',
    };
    return _RibbonPanel(
      title: widget.stars >= 3 ? 'Perfect!' : 'Complete!',
      color: CandyColor.green,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_star(0), _star(1), _star(2)],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GameConfig.textLight,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            praise,
            style: const TextStyle(
              color: GameConfig.brandAccent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatTile(label: 'Moves', value: '${widget.moves}'),
              if (par != null && par > 0) ...[
                const SizedBox(width: 12),
                _StatTile(label: 'Par', value: '$par'),
              ],
            ],
          ),
          if (widget.coins > 0) ...[
            const SizedBox(height: 14),
            _EarnedCoins(amount: widget.coins),
          ],
          if (widget.chestCoins > 0) ...[
            const SizedBox(height: 12),
            _ChestReward(amount: widget.chestCoins, label: widget.chestLabel),
          ],
          const SizedBox(height: 22),
          CandyButton(
            label: 'Next Level',
            height: 60,
            fontSize: 24,
            icon: const AssetIcon(AssetPaths.skip, size: 30),
            onPressed: widget.onNext,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: widget.onReplay,
            icon: const Icon(Icons.replay_rounded, color: GameConfig.textMuted),
            label: const Text(
              'Replay',
              style: TextStyle(
                color: GameConfig.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x44000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: GameConfig.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: GameConfig.textLight,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stuck ────────────────────────────────────────────────────────────────────

class _StuckDialog extends StatelessWidget {
  const _StuckDialog({
    required this.canUndo,
    required this.canAddJar,
    required this.canSkip,
    required this.onUndo,
    required this.onRestart,
    required this.onAddJar,
    required this.onSkip,
  });

  final bool canUndo;
  final bool canAddJar;
  final bool canSkip;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final VoidCallback onAddJar;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _RibbonPanel(
      title: 'No moves left',
      color: CandyColor.red,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No legal pour right now. Try one of these:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GameConfig.textLight,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (canAddJar) ...[
            CandyButton(
              label: '+1 Jar',
              subtitle: 'Watch ad',
              color: CandyColor.blue,
              height: 56,
              icon: const AssetIcon(AssetPaths.addJar, size: 30),
              onPressed: onAddJar,
            ),
            const SizedBox(height: 10),
          ],
          if (canUndo) ...[
            CandyButton(
              label: 'Undo',
              color: CandyColor.purple,
              height: 52,
              fontSize: 20,
              icon: const AssetIcon(AssetPaths.undo, size: 28),
              onPressed: onUndo,
            ),
            const SizedBox(height: 10),
          ],
          if (canSkip) ...[
            CandyButton(
              label: 'Skip',
              subtitle: 'Watch ad',
              color: CandyColor.orange,
              height: 52,
              fontSize: 20,
              icon: const AssetIcon(AssetPaths.skip, size: 28),
              onPressed: onSkip,
            ),
            const SizedBox(height: 10),
          ],
          CandyButton(
            label: 'Restart',
            color: CandyColor.green,
            height: 52,
            fontSize: 20,
            icon: const AssetIcon(AssetPaths.restart, size: 28),
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}

// ── Out of undos ─────────────────────────────────────────────────────────────

class _OutOfUndosDialog extends StatelessWidget {
  const _OutOfUndosDialog({required this.onWatchAd, required this.onDismiss});

  final VoidCallback onWatchAd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _RibbonPanel(
      title: 'Out of Undos',
      color: CandyColor.purple,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AssetIcon(AssetPaths.undo, size: 72),
          const SizedBox(height: 12),
          const Text(
            'You used all your free undos for this level.\n'
            'Watch a short ad to get +3 more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GameConfig.textLight,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          CandyButton(
            label: 'Watch ad (+3)',
            color: CandyColor.blue,
            height: 56,
            fontSize: 22,
            icon: const AssetIcon(AssetPaths.play, size: 30),
            onPressed: onWatchAd,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onDismiss,
            child: const Text(
              'Not now',
              style: TextStyle(
                color: GameConfig.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "+N coins" row with a count-up and a coin burst.
class _EarnedCoins extends StatelessWidget {
  const _EarnedCoins({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x88FFD36B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 30),
              const SizedBox(width: 8),
              CoinCountUp(
                value: amount,
                prefix: '+',
                duration: const Duration(milliseconds: 1100),
                style: const TextStyle(
                  color: GameConfig.brandAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Positioned(top: -120, child: CoinBurst(count: 12)),
      ],
    );
  }
}

/// Chapter chest that wobbles, pops open and shows its coins.
class _ChestReward extends StatefulWidget {
  const _ChestReward({required this.amount, this.label});
  final int amount;
  final String? label;

  @override
  State<_ChestReward> createState() => _ChestRewardState();
}

class _ChestRewardState extends State<_ChestReward>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        final wobble = t < 0.5 ? sin(t * 40) * 0.12 * (1 - t * 2) : 0.0;
        final open = t >= 0.5;
        final pop = open
            ? Curves.elasticOut.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0))
            : 0.0;
        return Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8E4FD6), Color(0xFF4A1C8C)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD36B), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: wobble,
                child: Icon(
                  open ? Icons.redeem_rounded : Icons.card_giftcard_rounded,
                  color: const Color(0xFFFFC93C),
                  size: 40,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label ?? 'Chapter chest!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GameConfig.textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Opacity(
                      opacity: open ? 1 : 0,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * pop,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CoinIcon(size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '+${widget.amount}',
                              style: const TextStyle(
                                color: GameConfig.brandAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HelperOfferDialog extends StatelessWidget {
  const _HelperOfferDialog({
    required this.title,
    required this.description,
    required this.asset,
    required this.price,
    required this.coins,
  });

  final String title;
  final String description;
  final String asset;
  final int price;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= price;
    return _RibbonPanel(
      title: title,
      color: CandyColor.blue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssetIcon(asset, size: 72),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GameConfig.textLight,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          CandyButton(
            label: 'Watch ad',
            subtitle: 'Free',
            color: CandyColor.blue,
            height: 56,
            icon: const AssetIcon(AssetPaths.play, size: 30),
            onPressed: () => Navigator.of(context).pop(HelperChoice.ad),
          ),
          const SizedBox(height: 10),
          CandyButton(
            label: 'Use $price',
            subtitle: canAfford
                ? 'You have $coins'
                : 'Need ${price - coins} more',
            color: CandyColor.orange,
            height: 56,
            icon: const CoinIcon(size: 30),
            onPressed: canAfford
                ? () => Navigator.of(context).pop(HelperChoice.coins)
                : null,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Not now',
              style: TextStyle(
                color: GameConfig.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
