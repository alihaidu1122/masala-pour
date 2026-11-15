import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings_model.dart';

/// Storage keys used by [SaveService].
abstract final class _Keys {
  static const String currentLevel = 'current_level';
  static const String restartCountPrefix = 'restarts_';
  static const String removeAds = 'remove_ads';
  static const String gamesPlayed = 'games_played';
  static const String totalMoves = 'total_moves';
  static const String undosUsed = 'undos_used';
  static const String levelUndosPrefix = 'level_undos_';
  static const String starsMap = 'stars_map';
  static const String dailyCompleted = 'daily_completed_dates';
  static const String coins = 'coins';
  static const String loginLastClaim = 'login_last_claim';
  static const String loginDay = 'login_day';
  static const String chestsClaimed = 'chests_claimed';
  static const String dailyCoinsDates = 'daily_coins_dates';

  // Settings
  static const String soundOn = 'setting_sound_on';
  static const String musicOn = 'setting_music_on';
  static const String vibrationOn = 'setting_vibration_on';
  static const String colorBlindMode = 'setting_color_blind';
  static const String fastAnimations = 'setting_fast_animations';
}

/// Persists game progress, settings flags, and stats using [SharedPreferences].
///
/// Must not import `lib/game/`. Call [init] once at app start (and in test
/// setUp) before using any other method.
class SaveService {
  SaveService._();

  static SharedPreferences? _prefs;

  /// The initialised singleton. Throws if [init] has not been called.
  static SaveService get instance {
    assert(_prefs != null, 'SaveService.init() must be called first');
    return _singleton;
  }

  static final SaveService _singleton = SaveService._();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Initialises shared preferences. Safe to call multiple times (re-initialises
  /// the prefs instance, which allows test setUp to call it with mock values).
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p => _prefs!;

  /// Called after any saved value changes (used to schedule cloud backup).
  static void Function()? onChanged;

  static void _changed() => onChanged?.call();

  /// Every saved value, for cloud backup.
  Map<String, Object> exportSnapshot() => {
    for (final key in _p.getKeys())
      if (_p.get(key) case final Object value) key: value,
  };

  /// Replaces saved values with [snapshot] (after a cloud restore).
  Future<void> importSnapshot(Map<String, Object> snapshot) async {
    for (final entry in snapshot.entries) {
      final v = entry.value;
      switch (v) {
        case final int i:
          await _p.setInt(entry.key, i);
        case final bool b:
          await _p.setBool(entry.key, b);
        case final double d:
          await _p.setDouble(entry.key, d);
        case final String str:
          await _p.setString(entry.key, str);
        case final List<String> list:
          await _p.setStringList(entry.key, list);
        case final List<dynamic> list:
          await _p.setStringList(entry.key, [for (final e in list) '$e']);
      }
    }
  }

  // ── Current level ──────────────────────────────────────────────────────────

  /// The 1-based id of the highest level the player has reached.
  int get currentLevel => _p.getInt(_Keys.currentLevel) ?? 1;

  /// Advances [currentLevel] to [id] if [id] > current.
  Future<void> advanceLevel(int id) async {
    if (id > currentLevel) {
      await _p.setInt(_Keys.currentLevel, id);
      _changed();
    }
  }

  // ── Stars ──────────────────────────────────────────────────────────────────

  /// Stars earned for a level (0–3; 0 means not completed).
  int starsForLevel(int id) {
    final raw = _p.getString(_Keys.starsMap);
    if (raw == null) return 0;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map['$id'] as int?) ?? 0;
  }

  /// Updates stars for [id] only if [stars] > current value.
  Future<void> saveStars(int id, int stars) async {
    final raw = _p.getString(_Keys.starsMap);
    final map = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};
    final current = (map['$id'] as int?) ?? 0;
    if (stars > current) {
      map['$id'] = stars;
      await _p.setString(_Keys.starsMap, jsonEncode(map));
      _changed();
    }
  }

  // ── Restart count (for skip-level unlock) ──────────────────────────────────

  /// Number of restarts on [levelId] in the current play session.
  int restartCount(int levelId) =>
      _p.getInt('${_Keys.restartCountPrefix}$levelId') ?? 0;

  /// Increments the restart counter for [levelId].
  Future<void> incrementRestarts(int levelId) async {
    final key = '${_Keys.restartCountPrefix}$levelId';
    await _p.setInt(key, (_p.getInt(key) ?? 0) + 1);
    _changed();
  }

  /// Resets the restart counter when the player completes a level.
  Future<void> clearRestarts(int levelId) async {
    await _p.remove('${_Keys.restartCountPrefix}$levelId');
    _changed();
  }

  // ── Undo counters ──────────────────────────────────────────────────────────

  /// Total number of undos consumed across all games.
  int get totalUndosUsed => _p.getInt(_Keys.undosUsed) ?? 0;

  /// Increments the lifetime count of undos used.
  Future<void> recordUndoUsed() async {
    await _p.setInt(_Keys.undosUsed, totalUndosUsed + 1);
    _changed();
  }

  /// Remaining undos saved for a specific [levelId], if any.
  int? getSavedUndos(int levelId) =>
      _p.getInt('${_Keys.levelUndosPrefix}$levelId');

  /// Saves the remaining undos count for [levelId].
  Future<void> saveUndos(int levelId, int undosLeft) async {
    await _p.setInt('${_Keys.levelUndosPrefix}$levelId', undosLeft);
    _changed();
  }

  /// Clears saved undos when a level completes or restarts.
  Future<void> clearSavedUndos(int levelId) async {
    await _p.remove('${_Keys.levelUndosPrefix}$levelId');
    _changed();
  }

  // ── Settings persistence ───────────────────────────────────────────────────

  /// Loads persisted user settings, falling back to [SettingsModel] defaults.
  SettingsModel loadSettings() {
    return SettingsModel(
      soundOn: _p.getBool(_Keys.soundOn) ?? true,
      musicOn: _p.getBool(_Keys.musicOn) ?? true,
      vibrationOn: _p.getBool(_Keys.vibrationOn) ?? true,
      colorBlindMode: _p.getBool(_Keys.colorBlindMode) ?? false,
      fastAnimations: _p.getBool(_Keys.fastAnimations) ?? false,
    );
  }

  /// Persists [settings] to storage.
  Future<void> saveSettings(SettingsModel settings) async {
    await _p.setBool(_Keys.soundOn, settings.soundOn);
    _changed();
    await _p.setBool(_Keys.musicOn, settings.musicOn);
    _changed();
    await _p.setBool(_Keys.vibrationOn, settings.vibrationOn);
    _changed();
    await _p.setBool(_Keys.colorBlindMode, settings.colorBlindMode);
    _changed();
    await _p.setBool(_Keys.fastAnimations, settings.fastAnimations);
    _changed();
  }

  // ── Remove-ads flag ────────────────────────────────────────────────────────

  bool get adsRemoved => _p.getBool(_Keys.removeAds) ?? false;

  Future<void> setAdsRemoved() async {
    await _p.setBool(_Keys.removeAds, true);
    _changed();
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  int get gamesPlayed => _p.getInt(_Keys.gamesPlayed) ?? 0;
  int get totalMoves => _p.getInt(_Keys.totalMoves) ?? 0;

  Future<void> recordLevelComplete({required int moves}) async {
    await _p.setInt(_Keys.gamesPlayed, gamesPlayed + 1);
    _changed();
    await _p.setInt(_Keys.totalMoves, totalMoves + moves);
    _changed();
  }

  // ── Daily challenge ────────────────────────────────────────────────────────

  /// Completed daily date keys (YYYY-MM-DD).
  Set<String> get completedDailyDates {
    final raw = _p.getStringList(_Keys.dailyCompleted) ?? const [];
    return raw.toSet();
  }

  bool isDailyCompleted(String dateKey) =>
      completedDailyDates.contains(dateKey);

  Future<void> markDailyCompleted(String dateKey) async {
    final set = completedDailyDates..add(dateKey);
    await _p.setStringList(_Keys.dailyCompleted, set.toList()..sort());
    _changed();
  }

  // ── Coins & rewards ────────────────────────────────────────────────────────

  /// Current coin balance.
  int get coins => _p.getInt(_Keys.coins) ?? 0;

  /// Sets the coin balance (never below zero).
  Future<void> setCoins(int value) async {
    await _p.setInt(_Keys.coins, value < 0 ? 0 : value);
    _changed();
  }

  /// Date of the last claimed login reward, or null.
  DateTime? get loginLastClaim {
    final raw = _p.getString(_Keys.loginLastClaim);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Streak day (1–7) of the last claimed login reward; 0 if never.
  int get loginDay => _p.getInt(_Keys.loginDay) ?? 0;

  /// Records a login reward claim for [date] as streak [day].
  Future<void> recordLoginClaim(DateTime date, int day) async {
    final d = DateTime(date.year, date.month, date.day);
    await _p.setString(_Keys.loginLastClaim, d.toIso8601String());
    _changed();
    await _p.setInt(_Keys.loginDay, day);
    _changed();
  }

  /// Chapter indexes whose chest was already opened.
  Set<int> get chestsClaimed => {
    for (final s in _p.getStringList(_Keys.chestsClaimed) ?? const <String>[])
      int.parse(s),
  };

  /// Marks the chest of [chapterIndex] as opened.
  Future<void> markChestClaimed(int chapterIndex) async {
    final set = chestsClaimed..add(chapterIndex);
    await _p.setStringList(_Keys.chestsClaimed, [
      for (final c in set.toList()..sort()) '$c',
    ]);
    _changed();
  }

  /// Whether Daily Challenge coins were already paid for [dateKey].
  bool dailyCoinsPaid(String dateKey) =>
      (_p.getStringList(_Keys.dailyCoinsDates) ?? const []).contains(dateKey);

  /// Marks Daily Challenge coins as paid for [dateKey].
  Future<void> markDailyCoinsPaid(String dateKey) async {
    final list = [...?_p.getStringList(_Keys.dailyCoinsDates), dateKey];
    await _p.setStringList(_Keys.dailyCoinsDates, list);
    _changed();
  }
}
