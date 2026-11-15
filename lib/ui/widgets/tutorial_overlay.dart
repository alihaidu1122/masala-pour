import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/asset_paths.dart';
import '../../config/game_config.dart';
import 'asset_icon.dart';
import 'game_ui.dart';

/// Full-screen overlay shown on Level 1 that guides the player through the
/// first pour with an animated hand pointer.
///
/// Calls [onDismiss] when the player taps "Got it!".
class TutorialOverlay extends StatefulWidget {
  /// Creates the tutorial overlay.
  const TutorialOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // One cycle = tap jar 1, then tap jar 2.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    // Mirror the board layout for level 1 (4 jars in one row) so the hand
    // points at the first two jars.
    const jarW = 78.0;
    const gap = 16.0;
    final startX = (size.width - (4 * jarW + 3 * gap)) / 2 + jarW / 2;
    final areaTop = mq.padding.top + 96;
    final areaBottom = size.height - mq.padding.bottom - 112;
    final rowCenter = (areaTop + areaBottom) / 2;

    return Material(
      color: const Color(0x99120424),
      child: Stack(
        children: [
          // ── Instruction card ──────────────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            top: mq.padding.top + 90,
            child: EntranceFade(
              child: GamePanel(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    OutlinedText('How to play', fontSize: 26),
                    SizedBox(height: 12),
                    _Step(
                      icon: Icons.touch_app_rounded,
                      text: 'Tap or drag a bottle to pour',
                    ),
                    _Step(
                      icon: Icons.swap_horiz_rounded,
                      text: 'Match colors onto each other',
                    ),
                    _Step(
                      icon: Icons.check_circle_rounded,
                      text: 'Fill each jar with one spice to win',
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tip: you can only pour matching colors on top!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: GameConfig.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Animated hand: taps jar 1, then jar 2 ─────────────────────
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final v = _controller.value;
              final second = v >= 0.5;
              final x = startX + (second ? jarW + gap : 0);
              final phase = (v * 2) % 1.0;
              final bob = -18 * math.sin(phase * math.pi);
              return Positioned(
                left: x - 10,
                top: rowCenter + bob,
                child: child!,
              );
            },
            child: Transform.rotate(
              angle: 0.35,
              child: const AssetIcon(AssetPaths.hand, size: 72),
            ),
          ),
          // ── Got it button ─────────────────────────────────────────────
          Positioned(
            left: 48,
            right: 48,
            bottom: mq.padding.bottom + 130,
            child: CandyButton(
              label: 'Got it! Let me play',
              height: 58,
              fontSize: 20,
              icon: const AssetIcon(AssetPaths.play, size: 30),
              onPressed: widget.onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 22, color: GameConfig.brandAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: GameConfig.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
