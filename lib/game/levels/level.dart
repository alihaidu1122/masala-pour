import '../logic/board_state.dart';
import '../logic/jar.dart';

/// How hard a level is presented to the player.
enum LevelDifficulty {
  /// Regular level.
  normal,

  /// Difficulty spike (every 5th level), shown with a red "Hard" badge.
  hard,

  /// Big spike (every 25th level), shown with a "Super Hard" badge.
  superHard;

  /// Parses the JSON name, defaulting to [normal].
  static LevelDifficulty parse(Object? raw) => switch (raw) {
    'hard' => LevelDifficulty.hard,
    'superHard' => LevelDifficulty.superHard,
    _ => LevelDifficulty.normal,
  };
}

/// A mechanic introduced to the player for the first time on a level.
enum LevelIntro {
  /// Hidden "?" layers that reveal when they reach the top.
  mystery,

  /// Taller jars holding 5 layers.
  tallJars,

  /// Jars locked with a colour key.
  lockedJars;

  /// Parses the JSON name, or null.
  static LevelIntro? parse(Object? raw) => switch (raw) {
    'mystery' => LevelIntro.mystery,
    'tallJars' => LevelIntro.tallJars,
    'lockedJars' => LevelIntro.lockedJars,
    _ => null,
  };
}

/// One playable level: jar layout, capacity, and par moves.
class Level {
  /// Creates a level definition.
  const Level({
    required this.id,
    required this.capacity,
    required this.jars,
    required this.par,
    this.difficulty = LevelDifficulty.normal,
    this.hidden = const [],
    this.locks = const [],
    this.intro,
  });

  /// 1-based level id.
  final int id;

  /// Layers each jar can hold.
  final int capacity;

  /// Bottom→top color indices per jar (empty list = empty jar).
  final List<List<int>> jars;

  /// Target move count from the solver (min or best-found).
  final int par;

  /// Difficulty badge shown to the player.
  final LevelDifficulty difficulty;

  /// Per jar: how many bottom layers start hidden ("?"). Empty = none hidden.
  final List<int> hidden;

  /// Per jar: key colour that unlocks it, or -1 when not locked.
  final List<int> locks;

  /// Lock colour for jar [index], or null.
  int? lockAt(int index) =>
      index < locks.length && locks[index] >= 0 ? locks[index] : null;

  /// Whether any jar starts locked.
  bool get hasLocks => locks.any((l) => l >= 0);

  /// Mechanic introduced on this level (shows an explainer), if any.
  final LevelIntro? intro;

  /// Hidden-layer count for jar [index] (0 when not set).
  int hiddenAt(int index) => index < hidden.length ? hidden[index] : 0;

  /// Whether any layer starts hidden.
  bool get hasHidden => hidden.any((h) => h > 0);

  /// Converts this level into an immutable [BoardState].
  BoardState toBoardState() {
    return BoardState([
      for (var i = 0; i < jars.length; i++)
        Jar(capacity: capacity, layers: jars[i], lockColor: lockAt(i)),
    ]);
  }

  /// Parses a level JSON object.
  factory Level.fromJson(Map<String, dynamic> json) {
    final rawJars = json['jars'] as List<dynamic>;
    final rawHidden = json['hidden'] as List<dynamic>?;
    final rawLocks = json['locks'] as List<dynamic>?;
    return Level(
      id: json['id'] as int,
      capacity: json['capacity'] as int,
      jars: [
        for (final jar in rawJars)
          [for (final color in jar as List<dynamic>) color as int],
      ],
      par: json['par'] as int,
      difficulty: LevelDifficulty.parse(json['difficulty']),
      hidden: rawHidden == null
          ? const []
          : [for (final h in rawHidden) h as int],
      locks: rawLocks == null ? const [] : [for (final l in rawLocks) l as int],
      intro: LevelIntro.parse(json['intro']),
    );
  }

  /// Serializes to the on-disk JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'capacity': capacity,
    'jars': [
      for (final jar in jars) [...jar],
    ],
    'par': par,
    if (difficulty != LevelDifficulty.normal) 'difficulty': difficulty.name,
    if (hasHidden) 'hidden': [...hidden],
    if (hasLocks) 'locks': [...locks],
    if (intro != null) 'intro': intro!.name,
  };

  /// Copy with some fields replaced.
  Level copyWith({int? id}) => Level(
    id: id ?? this.id,
    capacity: capacity,
    jars: jars,
    par: par,
    difficulty: difficulty,
    hidden: hidden,
    locks: locks,
    intro: intro,
  );

  @override
  String toString() =>
      'Level($id, ${difficulty.name}, par=$par, cap=$capacity, jars=$jars)';
}
