/// A pour from jar [from] into jar [to], moving [count] top layers.
///
/// Pure Dart — no Flutter imports.
class Move {
  /// Creates a pour move. [count] may be 0 until [Rules.applyPour] fills it.
  const Move({required this.from, required this.to, this.count = 0});

  /// Source jar index.
  final int from;

  /// Target jar index.
  final int to;

  /// How many layers were (or will be) poured.
  final int count;

  /// Copy with a concrete pour [count].
  Move withCount(int count) => Move(from: from, to: to, count: count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          from == other.from &&
          to == other.to &&
          count == other.count;

  @override
  int get hashCode => Object.hash(from, to, count);

  @override
  String toString() => 'Move($from → $to ×$count)';
}
