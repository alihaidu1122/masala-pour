import 'dart:collection';

import '../logic/board_state.dart';
import '../logic/move.dart';
import '../logic/rules.dart';

/// Result of a [Solver.solve] search.
class SolveResult {
  /// Creates a solve result.
  const SolveResult({
    required this.solved,
    required this.moves,
    required this.nodesExplored,
    this.reachedNodeLimit = false,
  });

  /// Whether a winning path was found.
  final bool solved;

  /// Moves from start to win (empty if already won or unsolved).
  final List<Move> moves;

  /// States expanded during search.
  final int nodesExplored;

  /// True when search stopped because [Solver.nodeLimit] was hit.
  final bool reachedNodeLimit;

  /// Unsolvable within the explored graph (limit not hit).
  bool get isUnsolvable => !solved && !reachedNodeLimit;

  /// Solution length; meaningful when [solved] is true.
  int get length => moves.length;
}

/// BFS shortest-path solver with a node budget.
///
/// Uses board hashing via [BoardState] equality. Skips pointless relocates
/// and empty-jar symmetry branches.
class Solver {
  /// Creates a solver.
  const Solver({this.nodeLimit = 200000, this.rules = const Rules()});

  /// Max states to expand before giving up as "limit reached".
  final int nodeLimit;

  /// Game rules used for moves and win checks.
  final Rules rules;

  /// Finds a shortest solution, or reports unsolvable / limit reached.
  SolveResult solve(BoardState start) {
    if (rules.isWon(start)) {
      return const SolveResult(solved: true, moves: [], nodesExplored: 0);
    }

    final visited = <BoardState>{start};
    final queue = Queue<BoardState>()..add(start);
    final cameFrom = <BoardState, (BoardState, Move)>{};

    var nodes = 0;

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      nodes++;
      if (nodes > nodeLimit) {
        return SolveResult(
          solved: false,
          moves: const [],
          nodesExplored: nodes,
          reachedNodeLimit: true,
        );
      }

      for (final move in rules.legalMoves(current)) {
        if (_isPointlessRelocate(current, move)) continue;
        if (_breaksEmptySymmetry(current, move)) continue;

        final next = rules.applyPour(current, move.from, move.to).board;
        if (!visited.add(next)) continue;

        cameFrom[next] = (current, move);

        if (rules.isWon(next)) {
          return SolveResult(
            solved: true,
            moves: _reconstruct(cameFrom, start, next),
            nodesExplored: nodes,
          );
        }

        queue.add(next);
      }
    }

    return SolveResult(solved: false, moves: const [], nodesExplored: nodes);
  }

  /// Finds *a* solution quickly using weighted A* (best-first).
  ///
  /// Used for large, fully shuffled boards where [solve] (BFS, shortest)
  /// would run out of nodes. The returned path is short but not guaranteed
  /// to be the shortest.
  SolveResult solveFast(BoardState start, {double weight = 2.5}) {
    if (rules.isWon(start)) {
      return const SolveResult(solved: true, moves: [], nodesExplored: 0);
    }
    final bestG = <BoardState, int>{start: 0};
    final cameFrom = <BoardState, (BoardState, Move)>{};
    final open = _MinHeap<_Node>((a, b) => a.f.compareTo(b.f));
    open.add(_Node(start, 0, weight * heuristic(start)));
    var nodes = 0;

    while (open.isNotEmpty) {
      final node = open.removeFirst();
      final current = node.board;
      if ((bestG[current] ?? 1 << 30) < node.g) continue;
      nodes++;
      if (nodes > nodeLimit) {
        return SolveResult(
          solved: false,
          moves: const [],
          nodesExplored: nodes,
          reachedNodeLimit: true,
        );
      }
      for (final move in rules.legalMoves(current)) {
        if (_isPointlessRelocate(current, move)) continue;
        if (_breaksEmptySymmetry(current, move)) continue;
        final next = rules.applyPour(current, move.from, move.to).board;
        final g = node.g + 1;
        final known = bestG[next];
        if (known != null && known <= g) continue;
        bestG[next] = g;
        cameFrom[next] = (current, move);
        if (rules.isWon(next)) {
          return SolveResult(
            solved: true,
            moves: _reconstruct(cameFrom, start, next),
            nodesExplored: nodes,
          );
        }
        open.add(_Node(next, g, g + weight * heuristic(next)));
      }
    }
    return SolveResult(solved: false, moves: const [], nodesExplored: nodes);
  }

  /// Lower bound-ish on remaining moves: colour runs beyond one per colour.
  static int heuristic(BoardState board) {
    var runs = 0;
    final colors = <int>{};
    for (final jar in board.jars) {
      final layers = jar.layers;
      for (var i = 0; i < layers.length; i++) {
        colors.add(layers[i]);
        if (i == 0 || layers[i] != layers[i - 1]) runs++;
      }
    }
    return runs - colors.length;
  }

  /// Moving a whole mono-color jar into an empty jar changes nothing useful.
  bool _isPointlessRelocate(BoardState board, Move move) {
    final source = board.jars[move.from];
    final target = board.jars[move.to];
    if (!target.isEmpty) return false;
    if (source.layers.isEmpty) return false;
    if (move.count != source.layers.length) return false;
    final color = source.layers.first;
    return source.layers.every((c) => c == color);
  }

  /// Pour into an empty jar only when it is the leftmost empty (symmetry).
  bool _breaksEmptySymmetry(BoardState board, Move move) {
    if (!board.jars[move.to].isEmpty) return false;
    for (var i = 0; i < move.to; i++) {
      if (board.jars[i].isEmpty) return true;
    }
    return false;
  }

  List<Move> _reconstruct(
    Map<BoardState, (BoardState, Move)> cameFrom,
    BoardState start,
    BoardState goal,
  ) {
    final path = <Move>[];
    var current = goal;
    while (current != start) {
      final entry = cameFrom[current];
      if (entry == null) {
        throw StateError('Broken path reconstruction');
      }
      final (parent, move) = entry;
      path.add(move);
      current = parent;
    }
    return path.reversed.toList(growable: false);
  }
}

class _Node {
  _Node(this.board, this.g, this.f);
  final BoardState board;
  final int g;
  final double f;
}

/// Small binary min-heap (avoids a package dependency in pure-Dart code).
class _MinHeap<T> {
  _MinHeap(this._compare);
  final int Function(T a, T b) _compare;
  final List<T> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(T item) {
    _items.add(item);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_compare(_items[i], _items[parent]) >= 0) break;
      final tmp = _items[i];
      _items[i] = _items[parent];
      _items[parent] = tmp;
      i = parent;
    }
  }

  T removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var m = i;
        if (l < _items.length && _compare(_items[l], _items[m]) < 0) m = l;
        if (r < _items.length && _compare(_items[r], _items[m]) < 0) m = r;
        if (m == i) break;
        final tmp = _items[i];
        _items[i] = _items[m];
        _items[m] = tmp;
        i = m;
      }
    }
    return first;
  }
}
