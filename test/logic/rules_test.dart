import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/logic/board_state.dart';
import 'package:masala_sort/game/logic/jar.dart';
import 'package:masala_sort/game/logic/rules.dart';

BoardState board(List<List<int>> jars, {int capacity = 4}) {
  return BoardState([
    for (final layers in jars) Jar(capacity: capacity, layers: layers),
  ]);
}

void main() {
  const rules = Rules();

  group('Rules.canPour / pourCount', () {
    test('rejects empty source', () {
      final b = board([
        [],
        [1, 1],
      ]);
      expect(rules.canPour(b, 0, 1), isFalse);
      expect(rules.pourCount(b, 0, 1), 0);
    });

    test('rejects full target', () {
      final b = board([
        [1],
        [2, 2, 2, 2],
      ]);
      expect(rules.canPour(b, 0, 1), isFalse);
    });

    test('rejects mismatched top colors', () {
      final b = board([
        [1, 1],
        [2],
      ]);
      expect(rules.canPour(b, 0, 1), isFalse);
    });

    test('rejects pouring into self', () {
      final b = board([
        [1, 1],
        [],
      ]);
      expect(rules.canPour(b, 0, 0), isFalse);
    });

    test('allows pour into empty jar', () {
      final b = board([
        [1, 1],
        [],
      ]);
      expect(rules.canPour(b, 0, 1), isTrue);
      expect(rules.pourCount(b, 0, 1), 2);
    });

    test('allows pour onto matching top color', () {
      final b = board([
        [0, 1, 1],
        [1],
      ]);
      expect(rules.canPour(b, 0, 1), isTrue);
      expect(rules.pourCount(b, 0, 1), 2);
    });

    test('partial pour when target lacks space', () {
      final b = board([
        [2, 2, 2],
        [2, 2, 2],
      ]);
      // target has 1 space; source top run is 3 → pour 1
      expect(rules.pourCount(b, 0, 1), 1);
      expect(rules.canPour(b, 0, 1), isTrue);
    });

    test('rejects out-of-range indices', () {
      final b = board([
        [1],
        [],
      ]);
      expect(rules.canPour(b, -1, 1), isFalse);
      expect(rules.canPour(b, 0, 2), isFalse);
    });
  });

  group('Rules.applyPour', () {
    test('pours full matching run into empty jar', () {
      final b = board([
        [0, 1, 1],
        [],
        [],
      ]);
      final result = rules.applyPour(b, 0, 1);
      expect(result.move.count, 2);
      expect(result.board.jars[0].layers, [0]);
      expect(result.board.jars[1].layers, [1, 1]);
      expect(result.board.jars[2].layers, isEmpty);
    });

    test('pours multi-layer run onto matching color', () {
      final b = board([
        [3, 3, 3],
        [3],
        [],
      ]);
      final result = rules.applyPour(b, 0, 1);
      expect(result.move.count, 3);
      expect(result.board.jars[0].isEmpty, isTrue);
      expect(result.board.jars[1].layers, [3, 3, 3, 3]);
    });

    test('partial pour leaves remainder on source', () {
      final b = board([
        [4, 4, 4, 4],
        [4, 4, 4],
      ]);
      final result = rules.applyPour(b, 0, 1);
      expect(result.move.count, 1);
      expect(result.board.jars[0].layers, [4, 4, 4]);
      expect(result.board.jars[1].layers, [4, 4, 4, 4]);
    });

    test('throws on illegal pour', () {
      final b = board([
        [1],
        [2],
      ]);
      expect(() => rules.applyPour(b, 0, 1), throwsArgumentError);
    });

    test('does not mutate original board', () {
      final b = board([
        [1, 1],
        [],
      ]);
      final before = b.jars[0].layers.toList();
      rules.applyPour(b, 0, 1);
      expect(b.jars[0].layers, before);
      expect(b.jars[1].isEmpty, isTrue);
    });
  });

  group('Rules win / complete / stuck', () {
    test('isJarComplete matches jar.isComplete', () {
      final complete = Jar(capacity: 4, layers: [2, 2, 2, 2]);
      final partial = Jar(capacity: 4, layers: [2, 2]);
      expect(rules.isJarComplete(complete), isTrue);
      expect(rules.isJarComplete(partial), isFalse);
    });

    test('isWon when every jar is empty or complete', () {
      final won = board([
        [1, 1, 1, 1],
        [2, 2, 2, 2],
        [],
        [],
      ]);
      expect(rules.isWon(won), isTrue);
    });

    test('isWon false when a jar is mono but not full', () {
      final notWon = board([
        [1, 1, 1],
        [],
      ]);
      expect(rules.isWon(notWon), isFalse);
    });

    test('isWon false when a jar is mixed', () {
      final notWon = board([
        [1, 1, 1, 2],
        [2, 2, 2],
        [],
      ]);
      expect(rules.isWon(notWon), isFalse);
    });

    test('empty board of empty jars is won', () {
      final empty = board([[], [], []]);
      expect(rules.isWon(empty), isTrue);
      expect(rules.isStuck(empty), isFalse);
    });

    test('isStuck when no legal moves and not won', () {
      // Two full mixed jars — nothing can pour.
      final stuck = board([
        [1, 2, 1, 2],
        [2, 1, 2, 1],
      ]);
      expect(rules.isWon(stuck), isFalse);
      expect(rules.legalMoves(stuck), isEmpty);
      expect(rules.isStuck(stuck), isTrue);
    });

    test('not stuck when a legal move exists', () {
      final b = board([
        [1, 1],
        [1],
        [],
      ]);
      expect(rules.isStuck(b), isFalse);
      expect(rules.legalMoves(b), isNotEmpty);
    });

    test('won board is not stuck even with no moves', () {
      final won = board([
        [0, 0, 0, 0],
        [1, 1, 1, 1],
      ]);
      expect(rules.legalMoves(won), isEmpty);
      expect(rules.isStuck(won), isFalse);
    });
  });

  group('Rules.legalMoves', () {
    test('lists every legal from/to with correct counts', () {
      final b = board([
        [1, 1],
        [1],
        [],
      ]);
      final moves = rules.legalMoves(b);
      expect(moves.length, greaterThanOrEqualTo(3));
      expect(
        moves.any((m) => m.from == 0 && m.to == 2 && m.count == 2),
        isTrue,
      );
      expect(
        moves.any((m) => m.from == 0 && m.to == 1 && m.count == 2),
        isTrue,
      );
      expect(
        moves.any((m) => m.from == 1 && m.to == 2 && m.count == 1),
        isTrue,
      );
    });
  });
}
