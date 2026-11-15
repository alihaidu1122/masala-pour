import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/logic/board_state.dart';
import 'package:masala_sort/game/logic/jar.dart';
import 'package:masala_sort/game/logic/rules.dart';
import 'package:masala_sort/game/logic/undo_stack.dart';

BoardState board(List<List<int>> jars) {
  return BoardState([
    for (final layers in jars) Jar(capacity: 4, layers: layers),
  ]);
}

void main() {
  const rules = Rules();

  group('UndoStack', () {
    test('starts with optional initial state', () {
      final start = board([
        [1],
        [],
      ]);
      final stack = UndoStack(initial: start);
      expect(stack.current, start);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });

    test('undo restores previous board after pours', () {
      final start = board([
        [1, 1],
        [],
      ]);
      final stack = UndoStack(initial: start);

      final after = rules.applyPour(start, 0, 1).board;
      stack.push(after);
      expect(stack.canUndo, isTrue);
      expect(stack.current, after);

      final undone = stack.undo();
      expect(undone, start);
      expect(stack.current, start);
      expect(stack.canRedo, isTrue);
    });

    test('redo reapplies undone state', () {
      final start = board([
        [2, 2],
        [2],
        [],
      ]);
      final stack = UndoStack(initial: start);
      final mid = rules.applyPour(start, 0, 1).board;
      stack.push(mid);
      final end = rules.applyPour(mid, 1, 2).board;
      stack.push(end);

      stack.undo();
      stack.undo();
      expect(stack.current, start);

      expect(stack.redo(), mid);
      expect(stack.redo(), end);
      expect(stack.canRedo, isFalse);
    });

    test('push after undo clears redo branch', () {
      final a = board([
        [1],
        [],
      ]);
      final b = rules.applyPour(a, 0, 1).board;
      final stack = UndoStack(initial: a)..push(b);
      stack.undo();

      final c = board([
        [3, 3],
        [],
      ]);
      stack.push(c);
      expect(stack.canRedo, isFalse);
      expect(stack.current, c);
    });

    test('reset clears history and sets new initial', () {
      final a = board([
        [1],
        [],
      ]);
      final b = rules.applyPour(a, 0, 1).board;
      final stack = UndoStack(initial: a)..push(b);
      final fresh = board([
        [9, 9, 9, 9],
        [],
      ]);
      stack.reset(fresh);
      expect(stack.current, fresh);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });

    test('undo returns null at base and does not change current', () {
      final start = board([
        [1],
        [],
      ]);
      final stack = UndoStack(initial: start);
      expect(stack.undo(), isNull);
      expect(stack.current, start);
    });

    test('duplicate push of same board is ignored', () {
      final start = board([
        [1],
        [],
      ]);
      final stack = UndoStack(initial: start)..push(start);
      expect(stack.undoDepth, 0);
      expect(stack.canUndo, isFalse);
    });

    test('full pour-undo-redo round trip matches boards', () {
      var state = board([
        [0, 1, 1],
        [1],
        [],
      ]);
      final stack = UndoStack(initial: state);

      state = rules.applyPour(state, 0, 1).board;
      stack.push(state);
      state = rules.applyPour(state, 1, 2).board;
      stack.push(state);

      final afterTwo = state;
      expect(stack.undo(), isNot(equals(afterTwo)));
      expect(stack.redo(), afterTwo);
      expect(stack.current!.jars[2].layers, [1, 1, 1]);
    });
  });
}
