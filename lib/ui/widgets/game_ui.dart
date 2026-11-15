import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';

/// True when looping decorative animations should run. They are off when the
/// user asked the OS to reduce motion, and under `flutter test` (so
/// `pumpAndSettle` can finish).
/// True when running under `flutter test`.
bool get isUnderTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

bool loopingAnimationsEnabled(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return false;
  return true;
}

/// Purple-magenta gradient backdrop with a soft centre glow, used behind
/// every menu screen so the whole app matches the game board and app icon.
class GameBackground extends StatelessWidget {
  /// Creates the backdrop around [child].
  const GameBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameConfig.bgMid, GameConfig.bgDeep],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.25),
            radius: 0.9,
            colors: [
              GameConfig.bgGlow.withValues(alpha: 0.55),
              GameConfig.bgGlow.withValues(alpha: 0),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Wraps [child] so it squishes down when pressed and springs back.
class Pressable extends StatefulWidget {
  /// Creates a pressable wrapper.
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: Duration(milliseconds: _down ? 70 : 220),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Text with a dark outline and drop shadow, like casual-game titles.
class OutlinedText extends StatelessWidget {
  /// Creates outlined text.
  const OutlinedText(
    this.text, {
    super.key,
    this.fontSize = 18,
    this.color = Colors.white,
    this.strokeColor = const Color(0xFF2B0A4A),
    this.strokeWidth = 4,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double fontSize;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
      height: 1.1,
    );
    return Stack(
      children: [
        // Stroke layer is a RichText so finders see only one Text widget.
        RichText(
          textAlign: textAlign,
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            text: text,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = strokeColor,
              shadows: const [
                Shadow(
                  color: Color(0x88000000),
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Colour presets for [CandyButton].
enum CandyColor {
  /// Main call to action.
  green(Color(0xFF7BE05A), Color(0xFF3FAE2A), Color(0xFF1E6B14)),

  /// Secondary action.
  orange(Color(0xFFFFC75A), Color(0xFFFF8F1F), Color(0xFFB4530A)),

  /// Neutral / tertiary action.
  purple(Color(0xFFB57CFF), Color(0xFF8040D9), Color(0xFF4A1C8C)),

  /// Ad-reward actions.
  blue(Color(0xFF6FD3FF), Color(0xFF2C8BF0), Color(0xFF14509E)),

  /// Destructive / restart.
  red(Color(0xFFFF8A80), Color(0xFFE5483B), Color(0xFF8E1F17));

  const CandyColor(this.top, this.mid, this.edge);
  final Color top;
  final Color mid;
  final Color edge;
}

/// Glossy 3D pill button used for primary actions.
class CandyButton extends StatelessWidget {
  /// Creates a candy button.
  const CandyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = CandyColor.green,
    this.icon,
    this.height = 60,
    this.fontSize = 22,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onPressed;
  final CandyColor color;
  final Widget? icon;
  final double height;
  final double fontSize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final depth = height * 0.1;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            height: height + depth,
            child: Stack(
              children: [
                // 3D edge.
                Positioned.fill(
                  top: depth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.edge,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                // Face.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.top, color.mid],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Gloss.
                        Positioned(
                          left: height * 0.35,
                          right: height * 0.35,
                          top: height * 0.08,
                          height: height * 0.32,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(height),
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                icon!,
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedText(
                                      label,
                                      fontSize: fontSize,
                                      strokeColor: color.edge,
                                    ),
                                    if (subtitle != null)
                                      OutlinedText(
                                        subtitle!,
                                        fontSize: fontSize * 0.55,
                                        strokeColor: color.edge,
                                        strokeWidth: 3,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

/// Round glossy button holding an icon image, with an optional badge.
class RoundIconButton extends StatelessWidget {
  /// Creates a round icon button.
  const RoundIconButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 60,
    this.badge,
    this.badgeColor = const Color(0xFFE5483B),
    this.label,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double size;
  final String? badge;
  final Color badgeColor;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Widget button = Pressable(
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF9B5DE5), Color(0xFF5B1FA6)],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFD36B),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(size * 0.17),
                      child: child,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          badge!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 2),
              OutlinedText(label!, fontSize: 13, strokeWidth: 3),
            ],
          ],
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}

/// Rounded purple panel with a gold border, used for dialogs and cards.
class GamePanel extends StatelessWidget {
  /// Creates a panel.
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6A2BB8), Color(0xFF3A0F6E)],
        ),
        border: Border.all(color: const Color(0xFFFFD36B), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: GameConfig.textLight),
        child: child,
      ),
    );
  }
}

/// A ribbon banner title that sits on top of a [GamePanel].
class RibbonTitle extends StatelessWidget {
  /// Creates a ribbon with [text].
  const RibbonTitle(this.text, {super.key, this.color = CandyColor.orange});

  final String text;
  final CandyColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.top, color.mid],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: color.edge, offset: const Offset(0, 4)),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: OutlinedText(text, fontSize: 24, strokeColor: color.edge),
    );
  }
}

/// Shows [child] with a pop-in scale animation (used for dialogs).
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xB3120424),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(type: MaterialType.transparency, child: builder(ctx)),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final scale = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.7, end: 1.0).animate(scale),
          child: child,
        ),
      );
    },
  );
}

/// Gently bobs [child] up and down forever.
class Bobbing extends StatefulWidget {
  /// Creates a bobbing wrapper.
  const Bobbing({super.key, required this.child, this.amplitude = 6});

  final Widget child;
  final double amplitude;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loopingAnimationsEnabled(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, sin(_c.value * 2 * pi) * widget.amplitude),
        child: child,
      ),
    );
  }
}

/// Repeating gentle scale pulse to draw the eye to a button.
class Pulsing extends StatefulWidget {
  /// Creates a pulsing wrapper.
  const Pulsing({super.key, required this.child});

  final Widget child;

  @override
  State<Pulsing> createState() => _PulsingState();
}

class _PulsingState extends State<Pulsing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loopingAnimationsEnabled(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.04,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Fades and slides [child] in after [delay].
class EntranceFade extends StatefulWidget {
  /// Creates an entrance animation.
  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 24,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + const Duration(milliseconds: 520),
  )..forward();

  late final double _start =
      widget.delay.inMilliseconds / _c.duration!.inMilliseconds;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _c,
      curve: Interval(_start, 1, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(parent: _c, curve: Interval(_start, 1));
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * widget.offsetY),
          child: child,
        ),
      ),
    );
  }
}
