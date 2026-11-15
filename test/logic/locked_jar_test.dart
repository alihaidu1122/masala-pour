import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/levels/level.dart';
import 'package:masala_sort/game/logic/board_state.dart';
import 'package:masala_sort/game/logic/jar.dart';
import 'package:masala_sort/game/logic/rules.dart';
import 'package:masala_sort/game/solver/solver.dart';

void main() {
  const rules = Rules();

  // Jar 2 is locked until colour 0 is completed.
  BoardState start() => BoardState([
    Jar(capacity: 4, layers: [0, 0, 0]),
    Jar(capacity: 4, layers: [1, 1, 1, 0]),
    Jar(capacity: 4, layers: [1], lockColor: 0),
    Jar.empty(capacity: 4),
  ]);

  test('cannot pour into or out of a locked jar', () {
    final b = start();
    expect(rules.canPour(b, 2, 3), isFalse);
    expect(rules.canPour(b, 3, 2), isFalse);
    expect(rules.legalMoves(b).any((m) => m.from == 2 || m.to == 2), isFalse);
  });

  test('completing the key colour unlocks the jar', () {
    final b = rules.applyPour(start(), 1, 0).board; // 0 completes
    expect(b.jars[0].isComplete, isTrue);
    expect(b.jars[2].isLocked, isFalse);
    expect(rules.canPour(b, 1, 2), isTrue);
  });

  test('a board with a locked jar is not won', () {
    final b = BoardState([
      Jar(capacity: 4, layers: [0, 0, 0, 0]),
      Jar(capacity: 4, layers: const [], lockColor: 1),
    ]);
    expect(rules.isWon(b), isFalse);
  });

  test('solver handles locks', () {
    final result = const Solver().solve(start());
    expect(result.solved, isTrue);
  });

  test('locks survive Level JSON and become locked jars', () {
    const level = Level(
      id: 33,
      capacity: 4,
      jars: [
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        [2, 2, 2, 2],
        [],
        [],
      ],
      par: 6,
      locks: [-1, -1, 0, -1, -1],
      intro: LevelIntro.lockedJars,
    );
    final copy = Level.fromJson(level.toJson());
    expect(copy.locks, [-1, -1, 0, -1, -1]);
    expect(copy.intro, LevelIntro.lockedJars);
    final board = copy.toBoardState();
    expect(board.jars[2].lockColor, 0);
    expect(board.jars[0].isLocked, isFalse);
  });
}
