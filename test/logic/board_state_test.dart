import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/logic/board_state.dart';
import 'package:masala_sort/game/logic/jar.dart';

void main() {
  group('BoardState', () {
    test('equality and hashCode compare jars deeply', () {
      final a = BoardState([
        Jar(capacity: 4, layers: [1, 2]),
        Jar.empty(capacity: 4),
      ]);
      final b = BoardState([
        Jar(capacity: 4, layers: [1, 2]),
        Jar.empty(capacity: 4),
      ]);
      final c = BoardState([
        Jar(capacity: 4, layers: [2, 1]),
        Jar.empty(capacity: 4),
      ]);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));

      final set = <BoardState>{a, b, c};
      expect(set.length, 2);
    });

    test('replaceJar returns new board without mutating original', () {
      final original = BoardState([
        Jar(capacity: 4, layers: [1]),
        Jar.empty(capacity: 4),
      ]);
      final next = original.replaceJar(1, Jar(capacity: 4, layers: [1]));
      expect(original.jars[1].isEmpty, isTrue);
      expect(next.jars[1].layers, [1]);
      expect(identical(original, next), isFalse);
    });

    test('withExtraEmptyJar appends one empty jar of same capacity', () {
      final original = BoardState([
        Jar(capacity: 4, layers: [0, 0]),
        Jar(capacity: 4, layers: [1, 1, 1, 1]),
        Jar.empty(capacity: 4),
      ]);
      final expanded = original.withExtraEmptyJar();
      expect(expanded.jarCount, 4);
      expect(expanded.jars.last.isEmpty, isTrue);
      expect(expanded.jars.last.capacity, 4);
      expect(original.jarCount, 3);
    });

    test('withExtraEmptyJar works with capacity 5', () {
      final board = BoardState([
        Jar(capacity: 5, layers: [2, 2, 2]),
        Jar.empty(capacity: 5),
      ]);
      final expanded = board.withExtraEmptyJar();
      expect(expanded.jars.last.capacity, 5);
      expect(expanded.jars.last.space, 5);
    });

    test('capacity is taken from first jar', () {
      final board = BoardState([
        Jar.empty(capacity: 5),
        Jar.empty(capacity: 5),
      ]);
      expect(board.capacity, 5);
    });
  });
}
