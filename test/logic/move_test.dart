import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/logic/move.dart';

void main() {
  group('Move', () {
    test('equality includes count', () {
      const a = Move(from: 0, to: 1, count: 2);
      const b = Move(from: 0, to: 1, count: 2);
      const c = Move(from: 0, to: 1, count: 1);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('withCount returns copy', () {
      const base = Move(from: 2, to: 3);
      final filled = base.withCount(4);
      expect(filled.from, 2);
      expect(filled.to, 3);
      expect(filled.count, 4);
      expect(base.count, 0);
    });
  });
}
