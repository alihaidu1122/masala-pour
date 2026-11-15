/// A single jar holding colored layers from bottom to top.
///
/// Colors are integer spice IDs. Pure Dart — no Flutter imports.
class Jar {
  /// Creates a jar with [capacity] and optional bottom→top [layers].
  Jar({required this.capacity, List<int> layers = const [], this.lockColor})
    : assert(capacity > 0, 'capacity must be > 0'),
      assert(
        layers.length <= capacity,
        'layers length ${layers.length} exceeds capacity $capacity',
      ),
      layers = List<int>.unmodifiable(layers);

  /// Empty jar with the given [capacity].
  factory Jar.empty({required int capacity}) => Jar(capacity: capacity);

  /// Maximum number of layers this jar can hold.
  final int capacity;

  /// Layer color IDs from bottom (index 0) to top (last).
  final List<int> layers;

  /// When set, the jar is locked until a jar of this colour is completed.
  /// Locked jars can't be poured into or out of.
  final int? lockColor;

  /// Whether the jar is currently locked.
  bool get isLocked => lockColor != null;

  /// Copy without the lock.
  Jar unlocked() => Jar(capacity: capacity, layers: layers);

  /// Whether the jar has no layers.
  bool get isEmpty => layers.isEmpty;

  /// Whether the jar has no free space.
  bool get isFull => layers.length >= capacity;

  /// Free slots remaining.
  int get space => capacity - layers.length;

  /// Top color, or `null` if empty.
  int? get topColor => isEmpty ? null : layers.last;

  /// Length of the contiguous same-color run at the top.
  int get topRunLength {
    if (isEmpty) return 0;
    final color = layers.last;
    var count = 0;
    for (var i = layers.length - 1; i >= 0; i--) {
      if (layers[i] != color) break;
      count++;
    }
    return count;
  }

  /// Full and every layer is the same color.
  bool get isComplete =>
      isFull && layers.isNotEmpty && layers.every((c) => c == layers.first);

  /// Returns a copy with [count] layers of [color] pushed on top.
  Jar push(int color, [int count = 1]) {
    assert(count > 0, 'count must be > 0');
    assert(count <= space, 'not enough space');
    return Jar(
      capacity: capacity,
      layers: [...layers, ...List<int>.filled(count, color)],
      lockColor: lockColor,
    );
  }

  /// Returns a copy with the top [count] layers removed.
  Jar pop(int count) {
    assert(count > 0, 'count must be > 0');
    assert(count <= layers.length, 'not enough layers');
    return Jar(
      capacity: capacity,
      layers: layers.sublist(0, layers.length - count),
      lockColor: lockColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Jar) return false;
    if (capacity != other.capacity ||
        lockColor != other.lockColor ||
        layers.length != other.layers.length) {
      return false;
    }
    for (var i = 0; i < layers.length; i++) {
      if (layers[i] != other.layers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = capacity + (lockColor == null ? 0 : 97 * (lockColor! + 1));
    for (final color in layers) {
      hash = 0x1fffffff & (hash + color);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  @override
  String toString() =>
      'Jar($capacity, $layers${lockColor == null ? '' : ', lock=$lockColor'})';
}
