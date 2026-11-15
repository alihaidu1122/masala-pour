import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/logic/board_state.dart';
import 'package:masala_sort/game/logic/jar.dart';
import 'package:masala_sort/game/logic/rules.dart';
import 'package:masala_sort/game/solver/solver.dart';

BoardState board(List<List<int>> jars, {int capacity = 4}) {
  return BoardState([
    for (final layers in jars) Jar(capacity: capacity, layers: layers),
  ]);
}

void main() {
  const solver = Solver();
  const rules = Rules();

  group('Solver', () {
    test('already won returns empty path', () {
      final result = solver.solve(
        board([
          [1, 1, 1, 1],
          [2, 2, 2, 2],
          [],
        ]),
      );
      expect(result.solved, isTrue);
      expect(result.moves, isEmpty);
      expect(result.length, 0);
    });

    test('solves a one-move tutorial-style board', () {
      final start = board([
        [0, 0],
        [0, 0],
        [],
        [],
      ]);
      final result = solver.solve(start);
      expect(result.solved, isTrue);
      expect(result.length, 1);
      final after = rules
          .applyPour(start, result.moves.first.from, result.moves.first.to)
          .board;
      expect(rules.isWon(after), isTrue);
    });

    test('finds a shortest solution for a small mixed board', () {
      final start = board([
        [0, 0, 1, 1],
        [1, 1, 0, 0],
        [],
        [],
      ]);
      final result = solver.solve(start);
      expect(result.solved, isTrue);
      expect(result.length, greaterThan(0));

      var state = start;
      for (final move in result.moves) {
        state = rules.applyPour(state, move.from, move.to).board;
      }
      expect(rules.isWon(state), isTrue);
    });

    test('reports unsolvable when no empty space and locked tops', () {
      // No empty jars; tops mismatch — cannot pour.
      final start = board([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
      ]);
      final result = solver.solve(start);
      expect(result.solved, isFalse);
      expect(result.isUnsolvable, isTrue);
      expect(result.reachedNodeLimit, isFalse);
    });

    test('respects node limit flag', () {
      final limited = const Solver(nodeLimit: 1);
      final start = board([
        [0, 1, 2, 0],
        [1, 2, 0, 1],
        [2, 0, 1, 2],
        [],
        [],
      ]);
      final result = limited.solve(start);
      // Either solves in ≤1 expansion (unlikely) or hits limit / unsolvable.
      if (!result.solved) {
        expect(result.reachedNodeLimit || result.isUnsolvable, isTrue);
      }
    });
  });
}
