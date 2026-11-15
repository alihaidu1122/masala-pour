import 'dart:math';

import '../logic/board_state.dart';
import '../logic/jar.dart';
import '../logic/move.dart';
import '../logic/rules.dart';
import '../solver/solver.dart';
import 'level.dart';

/// Difficulty band metadata for reporting and generation.
class DifficultyBand {
  /// Creates a difficulty band.
  const DifficultyBand({
    required this.name,
    required this.startId,
    required this.endId,
  });

  final String name;
  final int startId;
  final int endId;

  /// Whether [id] falls in this band.
  bool contains(int id) => id >= startId && id <= endId;
}

/// Reporting bands.
abstract final class DifficultyBands {
  static const tutorial = DifficultyBand(
    name: '1–5 tutorial',
    startId: 1,
    endId: 5,
  );
  static const early = DifficultyBand(name: '6–30', startId: 6, endId: 30);
  static const mid = DifficultyBand(name: '31–100', startId: 31, endId: 100);
  static const late = DifficultyBand(name: '101–300', startId: 101, endId: 300);

  static const all = [tutorial, early, mid, late];
}

/// How many layers start hidden ("?") on a level.
enum HiddenMode {
  /// Nothing hidden.
  none,

  /// In each full jar, everything except the top two layers is hidden.
  some,

  /// In each full jar, everything except the top layer is hidden.
  all,
}

/// Which board to prefer among solvable candidates.
enum BoardPick {
  /// Easiest candidate (breather level after a spike).
  easiest,

  /// Typical candidate (median random-play win rate).
  typical,

  /// Hardest candidate (lowest random-play win rate).
  hardest,
}

/// Parameters for building one generated level.
class LevelGenSpec {
  /// Creates generation parameters.
  const LevelGenSpec({
    required this.colorCount,
    required this.capacity,
    this.emptyJars = 2,
    this.difficulty = LevelDifficulty.normal,
    this.hidden = HiddenMode.none,
    this.pick = BoardPick.typical,
    this.intro,
    this.locks = 0,
  });

  final int colorCount;
  final int capacity;
  final int emptyJars;
  final LevelDifficulty difficulty;
  final HiddenMode hidden;
  final BoardPick pick;
  final LevelIntro? intro;

  /// Number of jars that start locked with a colour key.
  final int locks;

  /// Level that introduces locked jars.
  static const lockedIntroLevel = 33;

  /// Level that introduces hidden "?" layers.
  static const mysteryIntroLevel = 20;

  /// Level that introduces taller 5-layer jars.
  static const tallJarsIntroLevel = 45;

  /// Max distinct colours available in the game.
  static const maxColors = 10;

  /// Base colour count on the curve (before spikes).
  static int baseColors(int id) {
    if (id <= 8) return 3;
    if (id <= 14) return 4;
    if (id <= 24) return 5;
    if (id <= 39) return 6;
    if (id <= 59) return 7;
    if (id <= 89) return 8;
    if (id <= 139) return 9;
    return 10;
  }

  /// Spec for [levelId] (≥ 6) on a sawtooth curve: steady growth, a hard
  /// spike every 5th level, a super-hard spike every 25th, and an easier
  /// breather right after each spike. New mechanics arrive on fixed levels.
  factory LevelGenSpec.forLevel(int levelId) {
    final id = levelId;
    var colors = baseColors(id);
    var capacity = 4;
    var difficulty = LevelDifficulty.normal;
    var pick = BoardPick.typical;
    var hidden = HiddenMode.none;
    LevelIntro? intro;

    if (id >= 10 && id % 25 == 0) {
      difficulty = LevelDifficulty.superHard;
      pick = BoardPick.hardest;
      colors += 1;
    } else if (id >= 10 && id % 5 == 0) {
      difficulty = LevelDifficulty.hard;
      pick = BoardPick.hardest;
      colors += 1;
    } else if (id > 10 && id % 5 == 1) {
      pick = BoardPick.easiest; // breather after a spike
      colors -= 1;
    }

    // Mystery layers.
    if (id == mysteryIntroLevel + 1) {
      intro = LevelIntro.mystery;
      hidden = HiddenMode.some;
      pick = BoardPick.easiest;
      colors = baseColors(id) - 1;
    } else if (id > mysteryIntroLevel + 1) {
      if (id >= 80 && id % 3 == 0) {
        hidden = HiddenMode.all;
      } else if (id % 3 == 0 ||
          (id >= 60 && difficulty != LevelDifficulty.normal)) {
        hidden = HiddenMode.some;
      }
    }

    // Taller jars (5 layers): more layers per colour, so one colour fewer.
    if (id == tallJarsIntroLevel + 1) {
      intro = LevelIntro.tallJars;
      capacity = 5;
      pick = BoardPick.easiest;
      hidden = HiddenMode.none;
      colors = baseColors(id) - 2;
    } else if (id > tallJarsIntroLevel + 1 &&
        (id % 7 == 3 ||
            (id >= 100 && difficulty == LevelDifficulty.superHard))) {
      capacity = 5;
      colors -= 1;
    }

    // Locked jars.
    var locks = 0;
    if (id == lockedIntroLevel) {
      intro = LevelIntro.lockedJars;
      locks = 1;
      pick = BoardPick.easiest;
      hidden = HiddenMode.none;
      colors = baseColors(id) - 1;
    } else if (id > lockedIntroLevel && intro == null) {
      if (id % 4 == 1 || difficulty == LevelDifficulty.superHard) locks = 1;
      if (id >= 120 && id % 8 == 1) locks = 2;
    }

    return LevelGenSpec(
      colorCount: colors.clamp(3, maxColors),
      capacity: capacity,
      difficulty: difficulty,
      hidden: hidden,
      pick: pick,
      intro: intro,
      locks: locks,
    );
  }
}

/// A solvable candidate board with its measured difficulty.
class _Candidate {
  _Candidate(this.board, this.par, this.winRate);
  final BoardState board;
  final int par;

  /// Share of random play-throughs that reach a win (lower = harder).
  final double winRate;
}

/// Builds reproducible levels and verifies them with [Solver].
class LevelGeneratorCore {
  /// Creates a generator core.
  LevelGeneratorCore({
    this.baseSeed = 20261114,
    Solver? solver,
    this.rules = const Rules(),
    this.candidates = 10,
    this.playouts = 40,
  }) : solver = solver ?? const Solver(nodeLimit: 150000);

  /// Root seed mixed with level id for reproducibility.
  final int baseSeed;

  /// Solver used to verify boards and compute par.
  final Solver solver;

  final Rules rules;

  /// Solvable boards compared per level (more = better difficulty control).
  final int candidates;

  /// Random play-throughs used to measure each candidate's difficulty.
  final int playouts;

  /// Hand-written tutorial levels 1–5 (each color appears exactly [capacity] times).
  List<Level> tutorials() {
    final boards = <({int id, BoardState board})>[
      (
        id: 1,
        board: BoardState([
          Jar(capacity: 4, layers: [0, 0]),
          Jar(capacity: 4, layers: [0, 0]),
          Jar.empty(capacity: 4),
          Jar.empty(capacity: 4),
        ]),
      ),
      (
        id: 2,
        board: BoardState([
          Jar(capacity: 4, layers: [0, 0, 1, 1]),
          Jar(capacity: 4, layers: [1, 1, 0]),
          Jar(capacity: 4, layers: [0]),
          Jar.empty(capacity: 4),
        ]),
      ),
      (
        id: 3,
        board: BoardState([
          Jar(capacity: 4, layers: [0, 1, 0, 1]),
          Jar(capacity: 4, layers: [1, 0, 1, 0]),
          Jar.empty(capacity: 4),
          Jar.empty(capacity: 4),
        ]),
      ),
      (
        id: 4,
        board: BoardState([
          Jar(capacity: 4, layers: [0, 1, 2, 0]),
          Jar(capacity: 4, layers: [1, 2, 0, 1]),
          Jar(capacity: 4, layers: [2, 0, 1, 2]),
          Jar.empty(capacity: 4),
          Jar.empty(capacity: 4),
        ]),
      ),
      (
        id: 5,
        board: BoardState([
          Jar(capacity: 4, layers: [0, 0, 1, 2]),
          Jar(capacity: 4, layers: [1, 1, 2, 0]),
          Jar(capacity: 4, layers: [2, 2, 0, 1]),
          Jar.empty(capacity: 4),
          Jar.empty(capacity: 4),
        ]),
      ),
    ];

    return [
      for (final entry in boards)
        Level(
          id: entry.id,
          capacity: 4,
          jars: [
            for (final jar in entry.board.jars) [...jar.layers],
          ],
          par: _parOrThrow(entry.board),
        ),
    ];
  }

  int _parOrThrow(BoardState board) {
    final result = solver.solve(board);
    if (!result.solved || result.length <= 0) {
      throw StateError('Tutorial board not solvable: $board');
    }
    return result.length;
  }

  /// Generates all 300 levels deterministically.
  List<Level> generateAll({
    void Function(int id, Level level, double winRate)? onLevel,
  }) {
    final levels = <Level>[...tutorials()];
    for (final level in levels) {
      onLevel?.call(level.id, level, 1);
    }
    for (var id = 6; id <= 300; id++) {
      final (level, winRate) = _generate(id);
      levels.add(level);
      onLevel?.call(id, level, winRate);
    }
    return levels;
  }

  /// Generates a single level [id].
  Level generateOne(int id) {
    if (id <= 5) return tutorials().firstWhere((l) => l.id == id);
    return _generate(id).$1;
  }

  (Level, double) _generate(int id) {
    final spec = LevelGenSpec.forLevel(id);
    final found = <_Candidate>[];
    final wanted = spec.pick == BoardPick.typical ? candidates : candidates + 4;

    for (
      var attempt = 0;
      attempt < wanted * 6 && found.length < wanted;
      attempt++
    ) {
      final random = Random(_seedFor(id, attempt));
      final shuffled = _shuffledBoard(spec, random);
      if (!_isInteresting(shuffled, spec)) continue;
      final board = _addLocks(shuffled, spec, random);
      if (board == null) continue;
      final result = solver.solveFast(board);
      if (!result.solved || result.length <= 0) continue;
      final par = _par(board, result.length);
      final rate = playouts <= 0
          ? 0.5
          : _winRate(board, Random(_seedFor(id, 7777 + attempt)));
      found.add(_Candidate(board, par, rate));
    }
    if (found.isEmpty) throw StateError('Failed to generate level $id');

    found.sort((a, b) => a.winRate.compareTo(b.winRate));
    final chosen = switch (spec.pick) {
      BoardPick.hardest => found.first,
      BoardPick.easiest => found.last,
      BoardPick.typical => found[found.length ~/ 2],
    };

    final level = Level(
      id: id,
      capacity: spec.capacity,
      jars: [
        for (final jar in chosen.board.jars) [...jar.layers],
      ],
      par: chosen.par,
      difficulty: spec.difficulty,
      hidden: _hiddenFor(chosen.board, spec),
      locks: chosen.board.jars.any((j) => j.isLocked)
          ? [for (final j in chosen.board.jars) j.lockColor ?? -1]
          : const [],
      intro: spec.intro,
    );
    return (level, chosen.winRate);
  }

  int _par(BoardState board, int fastLength) {
    // Try for the true shortest on smaller boards.
    final exact = const Solver(nodeLimit: 25000).solve(board);
    if (exact.solved && exact.length > 0) return exact.length;
    return fastLength;
  }

  int _seedFor(int levelId, int attempt) =>
      baseSeed ^ (levelId * 2654435761) ^ (attempt * 40503);

  /// Every colour jar starts full with a uniform shuffle; empties on the end.
  BoardState _shuffledBoard(LevelGenSpec spec, Random random) {
    final deck = <int>[
      for (var c = 0; c < spec.colorCount; c++)
        for (var k = 0; k < spec.capacity; k++) c,
    ]..shuffle(random);
    final jars = <Jar>[
      for (var j = 0; j < spec.colorCount; j++)
        Jar(
          capacity: spec.capacity,
          layers: deck.sublist(j * spec.capacity, (j + 1) * spec.capacity),
        ),
      for (var e = 0; e < spec.emptyJars; e++)
        Jar.empty(capacity: spec.capacity),
    ];
    return BoardState(jars);
  }

  /// Locks [LevelGenSpec.locks] full jars. Each key colour must not appear in
  /// any locked jar (otherwise it could never be completed). Returns null
  /// when no valid placement exists.
  BoardState? _addLocks(BoardState board, LevelGenSpec spec, Random random) {
    if (spec.locks <= 0) return board;
    final candidates = [
      for (var i = 0; i < board.jarCount; i++)
        if (board.jars[i].isFull) i,
    ]..shuffle(random);
    if (candidates.length < spec.locks + 2) return null;
    final lockedIdx = candidates.take(spec.locks).toList();
    final inLocked = {for (final i in lockedIdx) ...board.jars[i].layers};
    final keys = [
      for (var c = 0; c < spec.colorCount; c++)
        if (!inLocked.contains(c)) c,
    ]..shuffle(random);
    if (keys.length < spec.locks) return null;
    var next = board;
    for (var k = 0; k < lockedIdx.length; k++) {
      final i = lockedIdx[k];
      next = next.replaceJar(
        i,
        Jar(
          capacity: spec.capacity,
          layers: board.jars[i].layers,
          lockColor: keys[k],
        ),
      );
    }
    return next;
  }

  /// Rejects boards that look too easy at a glance.
  bool _isInteresting(BoardState board, LevelGenSpec spec) {
    var longRuns = 0;
    for (final jar in board.jars) {
      if (jar.isEmpty) continue;
      if (jar.isComplete) return false;
      var run = 1;
      var best = 1;
      for (var i = 1; i < jar.layers.length; i++) {
        run = jar.layers[i] == jar.layers[i - 1] ? run + 1 : 1;
        best = max(best, run);
      }
      if (best >= spec.capacity - 1) longRuns++;
    }
    // Allow at most one jar with a near-complete run.
    return longRuns <= (spec.colorCount <= 4 ? 1 : 0);
  }

  /// Random play-throughs: share that reaches a win.
  double _winRate(BoardState start, Random random) {
    var wins = 0;
    final maxSteps = start.jarCount * start.capacity * 3;
    for (var p = 0; p < playouts; p++) {
      var board = start;
      Move? last;
      for (var step = 0; step < maxSteps; step++) {
        if (rules.isWon(board)) break;
        final moves = [
          for (final m in rules.legalMoves(board))
            if (!_pointless(board, m) &&
                !(last != null && m.from == last.to && m.to == last.from))
              m,
        ];
        if (moves.isEmpty) break;
        final m = moves[random.nextInt(moves.length)];
        board = rules.applyPour(board, m.from, m.to).board;
        last = m;
      }
      if (rules.isWon(board)) wins++;
    }
    return wins / playouts;
  }

  bool _pointless(BoardState board, Move m) {
    final src = board.jars[m.from];
    if (!board.jars[m.to].isEmpty) return false;
    return src.layers.every((c) => c == src.layers.first);
  }

  List<int> _hiddenFor(BoardState board, LevelGenSpec spec) {
    final keep = switch (spec.hidden) {
      HiddenMode.none => -1,
      HiddenMode.some => 2,
      HiddenMode.all => 1,
    };
    if (keep < 0) return const [];
    return [for (final jar in board.jars) max(0, jar.layers.length - keep)];
  }
}
