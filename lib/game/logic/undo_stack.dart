import 'board_state.dart';

/// Undo/redo history over immutable [BoardState] snapshots.
///
/// Pure Dart — no Flutter imports.
class UndoStack {
  /// Creates an empty stack. Optionally seed with [initial].
  UndoStack({BoardState? initial}) {
    if (initial != null) {
      _past.add(initial);
    }
  }

  final List<BoardState> _past = [];
  final List<BoardState> _future = [];

  /// Current board, or `null` if empty.
  BoardState? get current => _past.isEmpty ? null : _past.last;

  /// Whether [undo] can run.
  bool get canUndo => _past.length > 1;

  /// Whether [redo] can run.
  bool get canRedo => _future.isNotEmpty;

  /// Depth of undoable steps (excludes the initial snapshot).
  int get undoDepth => _past.isEmpty ? 0 : _past.length - 1;

  /// Clears history and starts from [state].
  void reset(BoardState state) {
    _past
      ..clear()
      ..add(state);
    _future.clear();
  }

  /// Records [state] as the new current board; clears redo branch.
  void push(BoardState state) {
    if (_past.isNotEmpty && _past.last == state) return;
    _past.add(state);
    _future.clear();
  }

  /// Reverts to the previous board, or `null` if none.
  BoardState? undo() {
    if (!canUndo) return null;
    _future.add(_past.removeLast());
    return _past.last;
  }

  /// Re-applies a previously undone board, or `null` if none.
  BoardState? redo() {
    if (!canRedo) return null;
    final state = _future.removeLast();
    _past.add(state);
    return state;
  }
}
