import 'dart:convert';

import 'package:flutter/services.dart';

import 'level.dart';

/// Loads and caches levels from `assets/levels/levels_001_300.json`.
class LevelRepository {
  /// Creates a repository. [bundle] is overridable for tests.
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/levels/levels_001_300.json';

  final AssetBundle _bundle;
  List<Level>? _cache;

  AssetBundle get _assets => _bundle;

  /// Whether levels have been loaded into memory.
  bool get isLoaded => _cache != null;

  /// Number of cached levels (0 if not loaded).
  int get count => _cache?.length ?? 0;

  /// Loads and caches all levels (idempotent).
  Future<List<Level>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await _assets.loadString(assetPath);
    _cache = parseLevelsJson(raw);
    return _cache!;
  }

  /// Returns a level by 1-based [id].
  Future<Level> getById(int id) async {
    final levels = await loadAll();
    return levels.firstWhere(
      (level) => level.id == id,
      orElse: () => throw StateError('Level $id not found'),
    );
  }

  /// Clears the in-memory cache (mainly for tests).
  void clearCache() => _cache = null;

  /// Parses the levels JSON document into models.
  static List<Level> parseLevelsJson(String raw) {
    final decoded = jsonDecode(raw);
    final List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      list = decoded['levels'] as List<dynamic>;
    } else if (decoded is List<dynamic>) {
      list = decoded;
    } else {
      throw const FormatException('Unexpected levels JSON root');
    }
    return [
      for (final item in list) Level.fromJson(item as Map<String, dynamic>),
    ];
  }
}
