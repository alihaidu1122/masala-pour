import 'dart:convert';

/// Merges a cloud backup with the phone's local save, keeping the best of
/// both so a reinstall never loses progress (pure Dart, unit-tested).
abstract final class SaveMerge {
  static const _level = 'current_level';
  static const _coins = 'coins';
  static const _stars = 'stars_map';
  static const _loginClaim = 'login_last_claim';
  static const _loginDay = 'login_day';
  static const _removeAds = 'remove_ads';

  /// Keys unioned as string lists.
  static const _unionLists = {
    'daily_completed_dates',
    'daily_coins_dates',
    'chests_claimed',
  };

  /// Stats where the larger value wins.
  static const _maxInts = {'games_played', 'total_moves', 'undos_used'};

  /// Per-session keys that should stay local.
  static bool _localOnly(String key) =>
      key.startsWith('restarts_') || key.startsWith('level_undos_');

  /// "Progress" used to decide which side is ahead.
  static (int, int) _rank(Map<String, Object> s) =>
      ((s[_level] as int?) ?? 1, (s[_coins] as int?) ?? 0);

  /// Whether [cloud] is ahead of [local].
  static bool cloudIsAhead(
    Map<String, Object> local,
    Map<String, Object> cloud,
  ) {
    final (ll, lc) = _rank(local);
    final (cl, cc) = _rank(cloud);
    return cl > ll || (cl == ll && cc > lc);
  }

  /// Returns the merged save.
  static Map<String, Object> merge(
    Map<String, Object> local,
    Map<String, Object> cloud,
  ) {
    final aheadIsCloud = cloudIsAhead(local, cloud);
    final ahead = aheadIsCloud ? cloud : local;
    final behind = aheadIsCloud ? local : cloud;

    final out = <String, Object>{...behind, ...ahead};

    for (final key in {...local.keys, ...cloud.keys}) {
      if (_localOnly(key)) {
        if (local.containsKey(key)) {
          out[key] = local[key]!;
        } else {
          out.remove(key);
        }
      }
    }

    out[_level] = _maxInt(local[_level], cloud[_level], 1);
    for (final key in _maxInts) {
      if (local.containsKey(key) || cloud.containsKey(key)) {
        out[key] = _maxInt(local[key], cloud[key], 0);
      }
    }
    for (final key in _unionLists) {
      final a = _list(local[key]);
      final b = _list(cloud[key]);
      if (a.isNotEmpty || b.isNotEmpty) {
        out[key] = ({...a, ...b}.toList()..sort());
      }
    }
    if (local[_removeAds] == true || cloud[_removeAds] == true) {
      out[_removeAds] = true;
    }

    final stars = _mergeStars(local[_stars], cloud[_stars]);
    if (stars != null) out[_stars] = stars;

    // Login streak follows the most recent claim.
    final lClaim = DateTime.tryParse('${local[_loginClaim] ?? ''}');
    final cClaim = DateTime.tryParse('${cloud[_loginClaim] ?? ''}');
    final useCloudLogin =
        cClaim != null && (lClaim == null || cClaim.isAfter(lClaim));
    final loginSide = useCloudLogin ? cloud : local;
    for (final key in [_loginClaim, _loginDay]) {
      if (loginSide.containsKey(key)) {
        out[key] = loginSide[key]!;
      } else {
        out.remove(key);
      }
    }
    return out;
  }

  static int _maxInt(Object? a, Object? b, int fallback) {
    final x = (a as int?) ?? fallback;
    final y = (b as int?) ?? fallback;
    return x > y ? x : y;
  }

  static List<String> _list(Object? v) => switch (v) {
    final List<String> l => l,
    final List<dynamic> l => [for (final e in l) '$e'],
    _ => const [],
  };

  static String? _mergeStars(Object? a, Object? b) {
    Map<String, dynamic> parse(Object? v) =>
        v is String ? jsonDecode(v) as Map<String, dynamic> : {};
    final x = parse(a);
    final y = parse(b);
    if (x.isEmpty && y.isEmpty) return null;
    final out = <String, int>{};
    for (final key in {...x.keys, ...y.keys}) {
      final sx = (x[key] as int?) ?? 0;
      final sy = (y[key] as int?) ?? 0;
      out[key] = sx > sy ? sx : sy;
    }
    return jsonEncode(out);
  }
}
