import 'board_state.dart';
import 'jar.dart';
import 'move.dart';

/// Pour legality, applying moves, win/stuck detection.
///
/// Pure Dart — no Flutter imports.
class Rules {
  /// Stateless helper; construct freely or use [Rules.instance].
  const Rules();

  /// Shared instance for call sites that prefer a singleton style.
  static const Rules instance = Rules();

  /// How many layers would pour from [from] into [to], or 0 if illegal.
  int pourCount(BoardState board, int from, int to) {
    if (from == to) return 0;
    if (from < 0 || to < 0 || from >= board.jarCount || to >= board.jarCount) {
      return 0;
    }

    final source = board.jars[from];
    final target = board.jars[to];

    if (source.isLocked || target.isLocked) return 0;
    if (source.isEmpty || target.isFull) return 0;

    final color = source.topColor!;
    if (!target.isEmpty && target.topColor != color) return 0;

    final run = source.topRunLength;
    final space = target.space;
    return run < space ? run : space;
  }

  /// Whether pouring from [from] into [to] is legal.
  bool canPour(BoardState board, int from, int to) =>
      pourCount(board, from, to) > 0;

  /// Applies a legal pour; throws [ArgumentError] if illegal.
  ///
  /// Returns the new board and a [Move] with the poured [Move.count].
  ({BoardState board, Move move}) applyPour(
    BoardState board,
    int from,
    int to,
  ) {
    final count = pourCount(board, from, to);
    if (count == 0) {
      throw ArgumentError('Illegal pour from $from to $to');
    }

    final source = board.jars[from];
    final target = board.jars[to];
    final color = source.topColor!;

    var next = board
        .replaceJar(from, source.pop(count))
        .replaceJar(to, target.push(color, count));

    // Completing a colour opens every jar locked with that colour.
    final filled = next.jars[to];
    if (filled.isComplete) {
      for (var i = 0; i < next.jarCount; i++) {
        if (next.jars[i].lockColor == color) {
          next = next.replaceJar(i, next.jars[i].unlocked());
        }
      }
    }

    return (board: next, move: Move(from: from, to: to, count: count));
  }

  /// Jar is full of a single color.
  bool isJarComplete(Jar jar) => jar.isComplete;

  /// Every jar is empty or a complete single-color jar.
  bool isWon(BoardState board) {
    for (final jar in board.jars) {
      if (jar.isLocked) return false;
      if (jar.isEmpty) continue;
      if (!jar.isComplete) return false;
    }
    return true;
  }

  /// All legal pours on [board].
  List<Move> legalMoves(BoardState board) {
    final moves = <Move>[];
    for (var from = 0; from < board.jarCount; from++) {
      for (var to = 0; to < board.jarCount; to++) {
        final count = pourCount(board, from, to);
        if (count > 0) {
          moves.add(Move(from: from, to: to, count: count));
        }
      }
    }
    return moves;
  }

  /// Not won and no legal pour exists.
  bool isStuck(BoardState board) => !isWon(board) && legalMoves(board).isEmpty;
}
