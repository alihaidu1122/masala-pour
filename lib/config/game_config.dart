import 'package:flutter/material.dart';

/// Central theme, branding, and spice-color definitions for Masala Sort.
///
/// Change this file alone to re-theme the game (e.g. chai cups or gems).
class GameConfig {
  GameConfig._();

  static const String appName = 'Masala Pour';
  static const String appTagline = 'Spice Color Puzzle';
  static const String packageName = 'com.masalapour.app';

  /// Default layers each jar can hold.
  static const int defaultJarCapacity = 4;

  /// Free undos granted at the start of each level.
  static const int freeUndosPerLevel = 3;

  /// Default pour animation duration (ms). Settings can speed this up.
  static const int pourAnimationMs = 650;

  /// Splash screen display before navigating home.
  static const Duration splashDuration = Duration(milliseconds: 1200);

  // ── Visual theme (matches the purple-magenta app icon) ─────────────────

  /// Deepest background purple (edges of the radial glow).
  static const Color bgDeep = Color(0xFF1A0633);

  /// Mid background purple.
  static const Color bgMid = Color(0xFF3B0F6B);

  /// Magenta glow at the centre of the background.
  static const Color bgGlow = Color(0xFF9C27B0);

  /// In-game Flame canvas fallback background.
  static const Color gameBackground = bgDeep;

  /// Menu gradient top (kept for older widgets).
  static const Color menuTop = bgMid;

  /// Menu gradient bottom (kept for older widgets).
  static const Color menuBottom = bgDeep;

  /// Primary call-to-action green (Play / Next buttons).
  static const Color brandPrimary = Color(0xFF43A047);

  /// Darker edge of the primary button.
  static const Color brandPrimaryDark = Color(0xFF1B5E20);

  /// Accent (saffron gold) — highlights, selection glow, stars.
  static const Color brandAccent = Color(0xFFFFC400);

  /// Panel surface for cards and dialogs.
  static const Color panel = Color(0xFF2A0D4D);

  /// Lighter panel border / divider.
  static const Color panelBorder = Color(0xFF7E3FBF);

  /// Main text colour on dark backgrounds.
  static const Color textLight = Color(0xFFFFF8E7);

  /// Secondary text colour on dark backgrounds.
  static const Color textMuted = Color(0xFFCDB8E8);

  /// Ten clearly different spice colours (bright on the purple background),
  /// each with a colour-blind symbol.
  static const List<SpiceColor> spices = [
    SpiceColor(id: 0, name: 'Turmeric', color: Color(0xFFFFC400), symbol: '★'),
    SpiceColor(id: 1, name: 'Chili', color: Color(0xFFE53935), symbol: '▲'),
    SpiceColor(id: 2, name: 'Cardamom', color: Color(0xFF7CB342), symbol: '■'),
    SpiceColor(id: 3, name: 'Saffron', color: Color(0xFFFF7A00), symbol: '●'),
    SpiceColor(id: 4, name: 'Rose', color: Color(0xFFFF5FA2), symbol: '◆'),
    SpiceColor(
      id: 5,
      name: 'Butterfly Pea',
      color: Color(0xFF2F7BFF),
      symbol: '✦',
    ),
    SpiceColor(id: 6, name: 'Mint', color: Color(0xFF1DE9B6), symbol: '◇'),
    SpiceColor(id: 7, name: 'Lavender', color: Color(0xFFB388FF), symbol: '✶'),
    SpiceColor(id: 8, name: 'Cinnamon', color: Color(0xFF8D4E2A), symbol: '✧'),
    SpiceColor(id: 9, name: 'Salt', color: Color(0xFFF2F2F2), symbol: '✪'),
  ];

  static SpiceColor spiceById(int id) => spices[id];

  /// Levels per chapter.
  static const int levelsPerChapter = 25;

  /// One themed "spice market" per 25 levels, each with its own backdrop.
  static const List<ChapterTheme> chapters = [
    ChapterTheme(
      'Saffron Street',
      Color(0xFF3B0F6B),
      Color(0xFF1A0633),
      Color(0xFF9C27B0),
    ),
    ChapterTheme(
      'Chili Bazaar',
      Color(0xFF5A0F1E),
      Color(0xFF24040B),
      Color(0xFFE53935),
    ),
    ChapterTheme(
      'Cardamom Gardens',
      Color(0xFF0D4A3C),
      Color(0xFF04201A),
      Color(0xFF26A69A),
    ),
    ChapterTheme(
      'Turmeric Palace',
      Color(0xFF5A3A07),
      Color(0xFF241503),
      Color(0xFFFFB300),
    ),
    ChapterTheme(
      'Indigo Night',
      Color(0xFF0F1F5C),
      Color(0xFF050A26),
      Color(0xFF3D5AFE),
    ),
    ChapterTheme(
      'Rose Courtyard',
      Color(0xFF5C0F45),
      Color(0xFF26041C),
      Color(0xFFEC407A),
    ),
    ChapterTheme(
      'Mint Harbor',
      Color(0xFF0A4552),
      Color(0xFF031C22),
      Color(0xFF26C6DA),
    ),
    ChapterTheme(
      'Cinnamon Desert',
      Color(0xFF5E2A12),
      Color(0xFF260F05),
      Color(0xFFFF7043),
    ),
    ChapterTheme(
      'Lavender Fields',
      Color(0xFF3F2A78),
      Color(0xFF170C33),
      Color(0xFFB388FF),
    ),
    ChapterTheme(
      'Pepper Peaks',
      Color(0xFF263238),
      Color(0xFF0B1013),
      Color(0xFF78909C),
    ),
    ChapterTheme(
      'Golden Souk',
      Color(0xFF4E3B0A),
      Color(0xFF1F1702),
      Color(0xFFFFD54F),
    ),
    ChapterTheme(
      'Royal Masala',
      Color(0xFF2A0845),
      Color(0xFF0E0118),
      Color(0xFFFFC400),
    ),
  ];

  /// 0-based chapter index for a campaign [levelId].
  static int chapterIndex(int levelId) =>
      ((levelId - 1) ~/ levelsPerChapter) % chapters.length;

  /// Theme for a campaign [levelId].
  static ChapterTheme chapterFor(int levelId) =>
      chapters[chapterIndex(levelId)];
}

/// Backdrop colours and name for one chapter.
class ChapterTheme {
  /// Creates a chapter theme.
  const ChapterTheme(this.name, this.top, this.bottom, this.glow);

  final String name;

  /// Gradient top colour.
  final Color top;

  /// Gradient bottom colour.
  final Color bottom;

  /// Centre glow colour.
  final Color glow;
}

/// One named spice color used as a jar layer.
class SpiceColor {
  const SpiceColor({
    required this.id,
    required this.name,
    required this.color,
    required this.symbol,
  });

  final int id;
  final String name;
  final Color color;

  /// Shown on layers when color-blind mode is enabled.
  final String symbol;
}
