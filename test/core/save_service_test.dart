import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/core/settings/settings_model.dart';
import 'package:masala_sort/core/storage/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.init();
  });

  group('SaveService - Level Progress', () {
    test('default current level is 1', () {
      expect(SaveService.instance.currentLevel, 1);
    });

    test('advanceLevel updates current level only when greater', () async {
      final save = SaveService.instance;
      await save.advanceLevel(5);
      expect(save.currentLevel, 5);

      // Attempting to advance to an earlier level does not regress progress
      await save.advanceLevel(3);
      expect(save.currentLevel, 5);

      await save.advanceLevel(6);
      expect(save.currentLevel, 6);
    });

    test('stars are saved and higher scores overwrite lower scores', () async {
      final save = SaveService.instance;
      expect(save.starsForLevel(1), 0);

      await save.saveStars(1, 2);
      expect(save.starsForLevel(1), 2);

      // Lower star score does not downgrade
      await save.saveStars(1, 1);
      expect(save.starsForLevel(1), 2);

      // Higher star score upgrades
      await save.saveStars(1, 3);
      expect(save.starsForLevel(1), 3);
    });

    test('restarts count increments and clears', () async {
      final save = SaveService.instance;
      expect(save.restartCount(4), 0);

      await save.incrementRestarts(4);
      await save.incrementRestarts(4);
      expect(save.restartCount(4), 2);

      await save.clearRestarts(4);
      expect(save.restartCount(4), 0);
    });
  });

  group('SaveService - Settings Persistence', () {
    test('loads default settings when nothing is saved', () {
      final settings = SaveService.instance.loadSettings();
      expect(settings.soundOn, isTrue);
      expect(settings.musicOn, isTrue);
      expect(settings.vibrationOn, isTrue);
      expect(settings.colorBlindMode, isFalse);
      expect(settings.fastAnimations, isFalse);
    });

    test('persists custom settings and reloads accurately', () async {
      final save = SaveService.instance;
      const custom = SettingsModel(
        soundOn: false,
        musicOn: false,
        vibrationOn: false,
        colorBlindMode: true,
        fastAnimations: true,
      );

      await save.saveSettings(custom);
      final loaded = save.loadSettings();
      expect(loaded, equals(custom));
    });
  });

  group('SaveService - Undos and Stats', () {
    test('tracks undos used lifetime counter', () async {
      final save = SaveService.instance;
      expect(save.totalUndosUsed, 0);

      await save.recordUndoUsed();
      await save.recordUndoUsed();
      expect(save.totalUndosUsed, 2);
    });

    test('saves and clears per-level undos', () async {
      final save = SaveService.instance;
      expect(save.getSavedUndos(10), isNull);

      await save.saveUndos(10, 2);
      expect(save.getSavedUndos(10), 2);

      await save.clearSavedUndos(10);
      expect(save.getSavedUndos(10), isNull);
    });

    test('records level complete stats', () async {
      final save = SaveService.instance;
      expect(save.gamesPlayed, 0);
      expect(save.totalMoves, 0);

      await save.recordLevelComplete(moves: 12);
      expect(save.gamesPlayed, 1);
      expect(save.totalMoves, 12);

      await save.recordLevelComplete(moves: 8);
      expect(save.gamesPlayed, 2);
      expect(save.totalMoves, 20);
    });

    test('removes ads flag', () async {
      final save = SaveService.instance;
      expect(save.adsRemoved, isFalse);

      await save.setAdsRemoved();
      expect(save.adsRemoved, isTrue);
    });
  });
}
