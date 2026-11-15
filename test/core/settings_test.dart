import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/core/settings/settings_controller.dart';
import 'package:masala_sort/core/settings/settings_model.dart';
import 'package:masala_sort/core/storage/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.init();
  });

  group('SettingsModel', () {
    test('default constructor values', () {
      const s = SettingsModel();
      expect(s.soundOn, isTrue);
      expect(s.musicOn, isTrue);
      expect(s.vibrationOn, isTrue);
      expect(s.colorBlindMode, isFalse);
      expect(s.fastAnimations, isFalse);
    });

    test('copyWith replaces specific fields', () {
      const s = SettingsModel();
      final updated = s.copyWith(soundOn: false, colorBlindMode: true);
      expect(updated.soundOn, isFalse);
      expect(updated.musicOn, isTrue);
      expect(updated.colorBlindMode, isTrue);
    });

    test('equality and hashCode match for identical properties', () {
      const a = SettingsModel(soundOn: false, fastAnimations: true);
      const b = SettingsModel(soundOn: false, fastAnimations: true);
      const c = SettingsModel(soundOn: true, fastAnimations: true);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('SettingsController', () {
    test('initial state loads from SaveService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(settingsControllerProvider);
      expect(settings.soundOn, isTrue);
    });

    test('setters update state and write through to SaveService', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(settingsControllerProvider.notifier);

      await controller.setSound(false);
      expect(container.read(settingsControllerProvider).soundOn, isFalse);
      expect(SaveService.instance.loadSettings().soundOn, isFalse);

      await controller.setMusic(false);
      expect(container.read(settingsControllerProvider).musicOn, isFalse);

      await controller.setVibration(false);
      expect(container.read(settingsControllerProvider).vibrationOn, isFalse);

      await controller.setColorBlind(true);
      expect(container.read(settingsControllerProvider).colorBlindMode, isTrue);
      expect(SaveService.instance.loadSettings().colorBlindMode, isTrue);

      await controller.setFastAnimations(true);
      expect(container.read(settingsControllerProvider).fastAnimations, isTrue);
      expect(SaveService.instance.loadSettings().fastAnimations, isTrue);
    });
  });
}
