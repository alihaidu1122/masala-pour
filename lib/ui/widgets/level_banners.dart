import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../game/levels/level.dart';
import 'game_ui.dart';

/// Colours and words for a level's difficulty badge.
extension LevelDifficultyStyle on LevelDifficulty {
  /// Badge text, or null for normal levels.
  String? get label => switch (this) {
    LevelDifficulty.normal => null,
    LevelDifficulty.hard => 'HARD',
    LevelDifficulty.superHard => 'SUPER HARD',
  };

  /// Gradient for the badge / banner.
  List<Color> get colors => switch (this) {
    LevelDifficulty.normal => const [Color(0xFFFFD36B), Color(0xFFFF9E1F)],
    LevelDifficulty.hard => const [Color(0xFFFF7A6B), Color(0xFFD62828)],
    LevelDifficulty.superHard => const [Color(0xFFE040FB), Color(0xFF6A1B9A)],
  };

  /// Dark edge colour.
  Color get edge => switch (this) {
    LevelDifficulty.normal => const Color(0xFF8A3B00),
    LevelDifficulty.hard => const Color(0xFF7A0E0E),
    LevelDifficulty.superHard => const Color(0xFF38004F),
  };
}

/// Small pill badge ("HARD" / "SUPER HARD") with a flame icon.
class DifficultyBadge extends StatelessWidget {
  /// Creates a badge for [difficulty]; renders nothing for normal levels.
  const DifficultyBadge(this.difficulty, {super.key, this.small = false});

  final LevelDifficulty difficulty;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final label = difficulty.label;
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 1 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: difficulty.colors),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: small ? 1 : 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: small ? 11 : 15,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 8.5 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big "HARD LEVEL!" banner that sweeps across the screen once when a spike
/// level starts, then disappears. Ignores touches.
class LevelStartBanner extends StatefulWidget {
  /// Creates the banner for [difficulty].
  const LevelStartBanner({
    super.key,
    required this.difficulty,
    this.label,
    this.colors,
  });

  final LevelDifficulty difficulty;

  /// Custom text (e.g. a chapter name) instead of "HARD LEVEL!".
  final String? label;

  /// Custom gradient colours.
  final List<Color>? colors;

  @override
  State<LevelStartBanner> createState() => _LevelStartBannerState();
}

class _LevelStartBannerState extends State<LevelStartBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.label != null;
    final label =
        widget.label ??
        (widget.difficulty == LevelDifficulty.superHard
            ? 'SUPER HARD!'
            : 'HARD LEVEL!');
    final colors = widget.colors ?? widget.difficulty.colors;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Slide in (0–0.2), hold, slide out (0.8–1).
          final inT = Curves.easeOutBack.transform((t / 0.2).clamp(0.0, 1.0));
          final outT = Curves.easeIn.transform(
            ((t - 0.8) / 0.2).clamp(0.0, 1.0),
          );
          final width = MediaQuery.sizeOf(context).width;
          final dx = (1 - inT) * width - outT * width;
          final opacity = t >= 1 ? 0.0 : 1.0;
          return Opacity(
            opacity: opacity,
            child: Center(
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: -0.05,
                  child: Container(
                    width: width + 40,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      border: const Border.symmetric(
                        horizontal: BorderSide(color: Colors.white, width: 3),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x99000000), blurRadius: 20),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          custom
                              ? Icons.auto_awesome_rounded
                              : Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: custom ? 30 : 40,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: OutlinedText(
                              label,
                              fontSize: custom ? 30 : 38,
                              strokeColor: widget.difficulty.edge,
                              strokeWidth: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          custom
                              ? Icons.auto_awesome_rounded
                              : Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: custom ? 30 : 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One-time explainer card when a level introduces a new mechanic.
class MechanicIntroOverlay extends StatelessWidget {
  /// Creates the explainer for [intro].
  const MechanicIntroOverlay({
    super.key,
    required this.intro,
    required this.onDismiss,
  });

  final LevelIntro intro;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (title, body, preview) = switch (intro) {
      LevelIntro.mystery => (
        'Mystery Jars!',
        'Some spices are hidden under "?". They reveal themselves when '
            'they reach the top of the jar. Plan carefully!',
        const _MiniJarPreview(hidden: true),
      ),
      LevelIntro.lockedJars => (
        'Locked Jars!',
        'A locked jar opens when you complete a jar of the colour shown on '
            'its lock. Until then you can\'t pour into it or out of it.',
        const _MiniJarPreview(hidden: false, locked: true),
      ),
      LevelIntro.tallJars => (
        'Tall Jars!',
        'These jars hold 5 scoops of spice instead of 4. '
            'More room, but more layers to sort.',
        const _MiniJarPreview(hidden: false, tall: true),
      ),
    };
    return Material(
      color: const Color(0xB3120424),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: EntranceFade(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: GamePanel(
                    padding: const EdgeInsets.fromLTRB(22, 44, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        preview,
                        const SizedBox(height: 16),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: GameConfig.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CandyButton(
                          label: 'Got it!',
                          height: 56,
                          fontSize: 22,
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
                const RibbonTitle('New!', color: CandyColor.blue),
                Positioned(
                  top: 76,
                  child: IgnorePointer(
                    child: OutlinedText(title, fontSize: 26),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny jar illustration for the explainer.
class _MiniJarPreview extends StatelessWidget {
  const _MiniJarPreview({
    required this.hidden,
    this.tall = false,
    this.locked = false,
  });

  final bool hidden;
  final bool tall;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final layers = tall
        ? const [
            Color(0xFFE53935),
            Color(0xFFFFC400),
            Color(0xFF7CB342),
            Color(0xFF2F7BFF),
            Color(0xFFFF5FA2),
          ]
        : const [
            Color(0xFF7CB342),
            Color(0xFF2F7BFF),
            Color(0xFFFF7A00),
            Color(0xFFFFC400),
          ];
    final jar = Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Container(
        width: 64,
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(10),
            bottom: Radius.circular(18),
          ),
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = layers.length - 1; i >= 0; i--)
                Container(
                  height: 22,
                  color: hidden && i < layers.length - 1
                      ? const Color(0xFF3B2160)
                      : layers[i],
                  alignment: Alignment.center,
                  child: hidden && i < layers.length - 1
                      ? const Text(
                          '?',
                          style: TextStyle(
                            color: Color(0xFFFFE082),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (!locked) return jar;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.6, child: jar),
        Padding(
          padding: const EdgeInsets.only(top: 34),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE53935),
              border: Border.all(color: const Color(0xFFFFD36B), width: 3),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
