import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/asset_paths.dart';
import '../../config/game_config.dart';
import '../../core/audio/sound_service.dart';
import '../../core/haptics/haptics_service.dart';
import '../../core/storage/progress_provider.dart';
import '../widgets/asset_icon.dart';
import '../../game/levels/level.dart';
import '../../game/levels/level_generator_core.dart';
import '../widgets/game_ui.dart';
import '../widgets/level_banners.dart';

/// Grid of all 300 levels. Completed levels show stars, the current level
/// pulses, locked levels show a padlock. Opens scrolled to the current level.
class LevelSelectScreen extends ConsumerStatefulWidget {
  /// Creates the level-select screen.
  const LevelSelectScreen({super.key});

  static const int _totalLevels = 300;

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen> {
  static const int _cols = 5;
  static const double _spacing = 10;
  static const double _hPad = 16;
  ScrollController? _scroll;

  ScrollController _controllerFor(double width, int current) {
    if (_scroll != null) return _scroll!;
    final cell = (width - _hPad * 2 - _spacing * (_cols - 1)) / _cols;
    const perChapter = GameConfig.levelsPerChapter;
    final chapter = (current - 1) ~/ perChapter;
    final rowsPerChapter = (perChapter / _cols).ceil();
    final chapterH =
        _ChapterHeader.height +
        rowsPerChapter * cell +
        (rowsPerChapter - 1) * _spacing;
    final rowInChapter = ((current - 1) % perChapter) ~/ _cols;
    final offset =
        chapter * chapterH +
        (rowInChapter >= 2
            ? _ChapterHeader.height + (rowInChapter - 1) * (cell + _spacing)
            : 0);
    return _scroll = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final notifier = ref.read(progressProvider.notifier);
    final highestUnlocked = progress.currentLevel;

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Expanded(
                      child: Center(
                        child: OutlinedText('Select Level', fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    Widget cell(int level) {
                      final isUnlocked = level <= highestUnlocked;
                      final stars = isUnlocked ? notifier.starsFor(level) : 0;
                      return _LevelCell(
                        level: level,
                        isUnlocked: isUnlocked,
                        isCurrent: level == highestUnlocked,
                        stars: stars,
                        difficulty: level <= 5
                            ? LevelDifficulty.normal
                            : LevelGenSpec.forLevel(level).difficulty,
                        onTap: isUnlocked
                            ? () {
                                ref.read(soundServiceProvider).playTap();
                                ref.read(hapticsServiceProvider).tap();
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.game, arguments: level);
                              }
                            : null,
                      );
                    }

                    const perChapter = GameConfig.levelsPerChapter;
                    final chapterCount =
                        (LevelSelectScreen._totalLevels / perChapter).ceil();
                    return CustomScrollView(
                      controller: _controllerFor(box.maxWidth, highestUnlocked),
                      slivers: [
                        for (var c = 0; c < chapterCount; c++) ...[
                          SliverToBoxAdapter(
                            child: _ChapterHeader(
                              index: c,
                              unlocked: c * perChapter + 1 <= highestUnlocked,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _hPad,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _cols,
                                    mainAxisSpacing: _spacing,
                                    crossAxisSpacing: _spacing,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => cell(c * perChapter + i + 1),
                                childCount: perChapter,
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.level,
    required this.isUnlocked,
    required this.isCurrent,
    required this.stars,
    required this.onTap,
    this.difficulty = LevelDifficulty.normal,
  });

  final LevelDifficulty difficulty;
  final int level;
  final bool isUnlocked;
  final bool isCurrent;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors;
    final Color edge;
    if (!isUnlocked) {
      colors = const [Color(0xFF4A2A6E), Color(0xFF2E1450)];
      edge = const Color(0xFF1E0B36);
    } else if (isCurrent) {
      colors = const [Color(0xFF7BE05A), Color(0xFF3FAE2A)];
      edge = const Color(0xFF1E6B14);
    } else {
      colors = const [Color(0xFFFFC75A), Color(0xFFFF8F1F)];
      edge = const Color(0xFFB4530A);
    }

    Widget tile = Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: isUnlocked ? 0.45 : 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: edge, offset: const Offset(0, 4)),
            const BoxShadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isUnlocked)
              const Opacity(
                opacity: 0.7,
                child: AssetIcon(AssetPaths.lock, size: 26),
              )
            else
              OutlinedText('$level', fontSize: 20, strokeColor: edge),
            if (isUnlocked && !isCurrent) ...[
              const SizedBox(height: 2),
              _MiniStars(stars: stars),
            ],
          ],
        ),
      ),
    );
    if (isCurrent) tile = Pulsing(child: tile);
    if (difficulty != LevelDifficulty.normal) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: tile),
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: DifficultyBadge(difficulty, small: true),
              ),
            ),
          ),
        ],
      );
    }
    return tile;
  }
}

class _MiniStars extends StatelessWidget {
  const _MiniStars({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Image.asset(
          i < stars ? AssetPaths.starOn : AssetPaths.starOff,
          width: 13,
          height: 13,
          cacheWidth: 48,
          errorBuilder: (_, _, _) => Icon(
            i < stars ? Icons.star_rounded : Icons.star_border_rounded,
            size: 12,
            color: GameConfig.brandAccent,
          ),
        ),
      ),
    );
  }
}

/// "Chapter 2 · Chili Bazaar" header with the chapter's colours.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.index, required this.unlocked});

  static const double height = 64;

  final int index;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = GameConfig.chapters[index % GameConfig.chapters.length];
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Opacity(
          opacity: unlocked ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [theme.glow, theme.top]),
              border: Border.all(color: const Color(0x66FFFFFF)),
            ),
            child: Row(
              children: [
                OutlinedText(
                  'Chapter ${index + 1}',
                  fontSize: 16,
                  strokeWidth: 3,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    theme.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!unlocked)
                  const Icon(
                    Icons.lock_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
