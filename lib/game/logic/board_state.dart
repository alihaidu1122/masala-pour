import 'jar.dart';

/// Immutable snapshot of every jar on the puzzle board.
///
/// Pure Dart — no Flutter imports.
class BoardState {
  /// Creates a board from [jars] (copied into an unmodifiable list).
  BoardState(List<Jar> jars) : jars = List<Jar>.unmodifiable(jars);

  /// All jars left→right (or as stored by the level).
  final List<Jar> jars;

  /// Number of jars.
  int get jarCount => jars.length;

  /// Shared capacity used when adding an extra empty jar.
  int get capacity {
    if (jars.isEmpty) {
      throw StateError('Board has no jars to infer capacity from');
    }
    return jars.first.capacity;
  }

  /// Returns a new board with jar [index] replaced.
  BoardState replaceJar(int index, Jar jar) {
    final next = List<Jar>.of(jars);
    next[index] = jar;
    return BoardState(next);
  }

  /// Adds one empty jar with the board's capacity (+1 Jar helper).
  BoardState withExtraEmptyJar() {
    return BoardState([...jars, Jar.empty(capacity: capacity)]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BoardState) return false;
    if (jars.length != other.jars.length) return false;
    for (var i = 0; i < jars.length; i++) {
      if (jars[i] != other.jars[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = jars.length;
    for (final jar in jars) {
      hash = 0x1fffffff & (hash + jar.hashCode);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  @override
  String toString() => 'BoardState($jars)';
}
