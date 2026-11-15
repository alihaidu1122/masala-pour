import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/logic/jar.dart';

void main() {
  group('Jar', () {
    test('empty jar has no top color and full space', () {
      final jar = Jar.empty(capacity: 4);
      expect(jar.isEmpty, isTrue);
      expect(jar.isFull, isFalse);
      expect(jar.space, 4);
      expect(jar.topColor, isNull);
      expect(jar.topRunLength, 0);
      expect(jar.isComplete, isFalse);
    });

    test('push and pop preserve capacity and order', () {
      var jar = Jar.empty(capacity: 4).push(1).push(1).push(2);
      expect(jar.layers, [1, 1, 2]);
      expect(jar.topColor, 2);
      expect(jar.topRunLength, 1);
      jar = jar.pop(1);
      expect(jar.layers, [1, 1]);
      expect(jar.topRunLength, 2);
    });

    test('topRunLength counts contiguous top colors only', () {
      final jar = Jar(capacity: 4, layers: [0, 1, 1, 1]);
      expect(jar.topRunLength, 3);
      expect(Jar(capacity: 4, layers: [2, 2, 2, 2]).topRunLength, 4);
    });

    test('isComplete requires full mono-color jar', () {
      expect(Jar(capacity: 4, layers: [3, 3, 3, 3]).isComplete, isTrue);
      expect(Jar(capacity: 4, layers: [3, 3, 3]).isComplete, isFalse);
      expect(Jar(capacity: 4, layers: [3, 3, 3, 2]).isComplete, isFalse);
    });

    test('equality and hashCode depend on capacity and layers', () {
      final a = Jar(capacity: 4, layers: [1, 2]);
      final b = Jar(capacity: 4, layers: [1, 2]);
      final c = Jar(capacity: 4, layers: [2, 1]);
      final d = Jar(capacity: 5, layers: [1, 2]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });
}
