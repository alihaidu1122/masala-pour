import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/levels/level.dart';
import 'package:masala_sort/game/levels/level_repository.dart';
import 'package:masala_sort/game/logic/rules.dart';
import 'package:masala_sort/game/solver/solver.dart';

void main() {
  const rules = Rules();
  // Generous limit for verifying shipped levels (weighted A*: full-shuffle
  // boards are too big for exhaustive BFS).
  const solver = Solver(nodeLimit: 400000);

  late List<Level> levels;

  setUpAll(() {
    final file = File('assets/levels/levels_001_300.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Run: dart run tool/level_generator.dart',
    );
    levels = LevelRepository.parseLevelsJson(file.readAsStringSync());
  });

  test('JSON contains exactly 300 levels with ids 1..300', () {
    expect(levels, hasLength(300));
    expect(levels.map((l) => l.id).toList(), List.generate(300, (i) => i + 1));
  });

  test('every level is solvable and par > 0', () {
    for (final level in levels) {
      expect(level.par, greaterThan(0), reason: 'level ${level.id} par');
      final board = level.toBoardState();
      expect(rules.isWon(board), isFalse, reason: 'level ${level.id} solved');

      final result = solver.solveFast(board);
      expect(
        result.solved,
        isTrue,
        reason:
            'level ${level.id} unsolvable '
            '(nodes=${result.nodesExplored}, limit=${result.reachedNodeLimit})',
      );
      // Par is the best solution the generator found; a fresh search should
      // not need dramatically more moves.
      expect(
        level.par,
        lessThanOrEqualTo(result.length + 2),
        reason: 'level ${level.id} par ${level.par} vs found ${result.length}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('Level.fromJson round-trip preserves fields', () {
    final original = levels[41];
    final copy = Level.fromJson(original.toJson());
    expect(copy.id, original.id);
    expect(copy.capacity, original.capacity);
    expect(copy.par, original.par);
    expect(copy.jars, original.jars);
  });

  test('Level JSON keeps difficulty, hidden layers and intro', () {
    const level = Level(
      id: 21,
      capacity: 5,
      jars: [
        [0, 1, 0, 1, 0],
        [1, 0, 1, 0, 1],
        [],
      ],
      par: 9,
      difficulty: LevelDifficulty.hard,
      hidden: [3, 3, 0],
      intro: LevelIntro.mystery,
    );
    final copy = Level.fromJson(level.toJson());
    expect(copy.difficulty, LevelDifficulty.hard);
    expect(copy.hidden, [3, 3, 0]);
    expect(copy.intro, LevelIntro.mystery);
    expect(copy.capacity, 5);
  });

  test('campaign has sawtooth spikes and new mechanics', () {
    final byId = {for (final l in levels) l.id: l};
    expect(byId[10]!.difficulty, LevelDifficulty.hard);
    expect(byId[25]!.difficulty, LevelDifficulty.superHard);
    expect(byId[21]!.intro, LevelIntro.mystery);
    expect(byId[21]!.hasHidden, isTrue);
    expect(byId[46]!.intro, LevelIntro.tallJars);
    expect(byId[46]!.capacity, 5);
    expect(byId[33]!.intro, LevelIntro.lockedJars);
    expect(byId[33]!.hasLocks, isTrue);
    expect(levels.where((l) => l.hasLocks).length, greaterThan(40));
    // Every colour jar starts full (no half-empty free space).
    for (final l in levels.where((l) => l.id > 5)) {
      final filled = l.jars.where((j) => j.isNotEmpty);
      expect(
        filled.every((j) => j.length == l.capacity),
        isTrue,
        reason: 'level ${l.id} has a part-filled jar',
      );
    }
    // Later levels use more colours than early ones.
    int colors(Level l) => {for (final j in l.jars) ...j}.length;
    expect(colors(byId[150]!), greaterThan(colors(byId[12]!)));
  });
}
