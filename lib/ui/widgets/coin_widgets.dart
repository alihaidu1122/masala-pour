import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';

/// A gold coin drawn with Flutter (no image asset needed).
class CoinIcon extends StatelessWidget {
  /// Creates a coin of [size].
  const CoinIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFFFF3B0), Color(0xFFFFC93C), Color(0xFFC88A04)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(
            color: const Color(0xFF8A5A00),
            width: size * 0.07,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x66000000),
              blurRadius: size * 0.15,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.star_rounded,
            size: size * 0.62,
            color: const Color(0xFFB8740A),
          ),
        ),
      ),
    );
  }
}

/// Dark pill showing a coin and [amount]; animates when the amount changes.
class CoinPill extends StatelessWidget {
  /// Creates a coin counter.
  const CoinPill({super.key, required this.amount, this.onTap});

  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        decoration: BoxDecoration(
          color: const Color(0x8C000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: GameConfig.brandAccent.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 26),
            const SizedBox(width: 6),
            CoinCountUp(
              value: amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text that counts up (or down) smoothly to [value].
class CoinCountUp extends StatelessWidget {
  /// Creates a counting number.
  const CoinCountUp({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$prefix${v.round()}', style: style),
    );
  }
}

/// A burst of coins that fly up and fade, shown when coins are earned.
class CoinBurst extends StatefulWidget {
  /// Creates a burst of [count] coins.
  const CoinBurst({super.key, this.count = 10});

  final int count;

  @override
  State<CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  final _rand = Random(7);
  late final List<(double, double, double)> _coins = List.generate(
    widget.count,
    (_) => (
      (_rand.nextDouble() - 0.5) * 2, // x direction
      0.6 + _rand.nextDouble() * 0.6, // speed
      _rand.nextDouble() * 0.25, // delay
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => SizedBox(
          width: 220,
          height: 160,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (dx, speed, delay) in _coins)
                () {
                  final t = ((_c.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                  final x = 110 + dx * 90 * t;
                  final y = 120 - speed * 150 * t + 160 * t * t;
                  return Positioned(
                    left: x - 11,
                    top: y - 11,
                    child: Opacity(
                      opacity: t <= 0 ? 0 : (1 - t).clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: t * 6 * dx,
                        child: const CoinIcon(size: 22),
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
      ),
    );
  }
}
