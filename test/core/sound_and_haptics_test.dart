import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/core/audio/sound_service.dart';
import 'package:masala_sort/core/haptics/haptics_service.dart';
import 'package:masala_sort/core/settings/settings_controller.dart';
import 'package:masala_sort/core/storage/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.init();
  });

  group('HapticsService', () {
    test('calls complete safely when enabled', () async {
      const service = HapticsService(enabled: true);
      await service.tap();
      await service.pour();
      await service.jarComplete();
      await service.win();
    });

    test('calls complete safely when disabled', () async {
      const service = HapticsService(enabled: false);
      await service.tap();
      await service.pour();
      await service.jarComplete();
      await service.win();
    });

    test('provider reflects settingsController vibration state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hapticsServiceProvider).enabled, isTrue);

      await container
          .read(settingsControllerProvider.notifier)
          .setVibration(false);
      expect(container.read(hapticsServiceProvider).enabled, isFalse);
    });
  });

  group('SoundService', () {
    test('plays sounds through handler when sound is enabled', () async {
      final played = <String>[];
      final service = SoundService(
        soundEnabled: true,
        playHandler: (file, {volume = 1.0}) async => played.add(file),
      );

      await service.playTap();
      await service.playPour();
      await service.playComplete();
      await service.playWin();

      expect(
        played,
        equals([
          SoundFiles.tap,
          SoundFiles.pour,
          SoundFiles.complete,
          SoundFiles.win,
        ]),
      );
    });

    test('suppresses sound playback when sound is disabled', () async {
      final played = <String>[];
      final service = SoundService(
        soundEnabled: false,
        playHandler: (file, {volume = 1.0}) async => played.add(file),
      );

      await service.playTap();
      await service.playPour();
      await service.playComplete();
      await service.playWin();

      expect(played, isEmpty);
    });

    test('preload runs without throwing', () async {
      final service = SoundService();
      await service.preload();
    });

    test(
      'provider reflects settingsController sound and music state',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(soundServiceProvider).soundEnabled, isTrue);
        expect(container.read(soundServiceProvider).musicEnabled, isTrue);

        await container
            .read(settingsControllerProvider.notifier)
            .setSound(false);
        await container
            .read(settingsControllerProvider.notifier)
            .setMusic(false);

        expect(container.read(soundServiceProvider).soundEnabled, isFalse);
        expect(container.read(soundServiceProvider).musicEnabled, isFalse);
      },
    );
  });
}
