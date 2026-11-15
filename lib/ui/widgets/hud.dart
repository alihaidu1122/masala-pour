import 'package:flutter/material.dart';

import '../../config/asset_paths.dart';
import '../../config/game_config.dart';
import 'asset_icon.dart';
import '../../game/levels/level.dart';
import 'game_ui.dart';
import 'level_banners.dart';

/// In-game HUD: level banner, move counter, settings, and the round action
/// buttons (undo, restart, +1 jar).
class GameHud extends StatelessWidget {
  /// Creates the HUD.
  const GameHud({
    super.key,
    required this.levelLabel,
    required this.moveCount,
    required this.undosLeft,
    required this.par,
    required this.canUndo,
    required this.canAddJar,
    required this.onUndo,
    required this.onRestart,
    required this.onAddJar,
    required this.onSettings,
    this.onHome,
    this.difficulty = LevelDifficulty.normal,
  });

  /// Display label ("12" or "Daily").
  final String levelLabel;
  final int moveCount;
  final int undosLeft;
  final int? par;
  final bool canUndo;
  final bool canAddJar;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final VoidCallback onAddJar;
  final VoidCallback onSettings;
  final VoidCallback? onHome;

  /// Difficulty of the current level (colours the banner, adds a badge).
  final LevelDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: onHome == null
                    ? null
                    : RoundIconButton(
                        size: 46,
                        tooltip: 'Home',
                        onPressed: onHome,
                        child: const Icon(
                          Icons.home_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _LevelBanner(
                      levelLabel == 'Daily' ? 'Daily' : 'Level $levelLabel',
                      difficulty: difficulty,
                    ),
                    if (difficulty != LevelDifficulty.normal) ...[
                      const SizedBox(height: 4),
                      DifficultyBadge(difficulty),
                    ],
                    const SizedBox(height: 6),
                    _MovesChip(moveCount: moveCount, par: par),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: RoundIconButton(
                  size: 46,
                  tooltip: 'Settings',
                  onPressed: onSettings,
                  child: const AssetIcon(AssetPaths.settings, size: 30),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RoundIconButton(
                tooltip: 'Undo',
                label: 'Undo',
                badge: undosLeft > 0 ? '$undosLeft' : 'AD',
                badgeColor: undosLeft > 0
                    ? const Color(0xFFE5483B)
                    : const Color(0xFF2C8BF0),
                onPressed: canUndo ? onUndo : null,
                child: const AssetIcon(AssetPaths.undo, size: 40),
              ),
              RoundIconButton(
                tooltip: 'Restart',
                label: 'Restart',
                onPressed: onRestart,
                child: const AssetIcon(AssetPaths.restart, size: 40),
              ),
              RoundIconButton(
                tooltip: '+1 Jar',
                label: '+1 Jar',
                badge: 'AD',
                badgeColor: const Color(0xFF2C8BF0),
                onPressed: canAddJar ? onAddJar : null,
                child: const AssetIcon(AssetPaths.addJar, size: 40),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelBanner extends StatelessWidget {
  const _LevelBanner(this.text, {required this.difficulty});
  final String text;
  final LevelDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: difficulty.colors,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: difficulty.edge, offset: const Offset(0, 3)),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: OutlinedText(text, fontSize: 22, strokeColor: difficulty.edge),
    );
  }
}

class _MovesChip extends StatelessWidget {
  const _MovesChip({required this.moveCount, required this.par});
  final int moveCount;
  final int? par;

  @override
  Widget build(BuildContext context) {
    final overPar = par != null && moveCount > par!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overPar
              ? const Color(0x66FF8A80)
              : GameConfig.brandAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.swap_vert_rounded,
            size: 16,
            color: GameConfig.textMuted,
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(
              par != null ? 'Moves $moveCount / $par' : 'Moves $moveCount',
              key: ValueKey(moveCount),
              style: const TextStyle(
                color: GameConfig.textLight,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
