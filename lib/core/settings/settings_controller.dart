import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/ad_service.dart';
import '../storage/save_service.dart';
import 'settings_model.dart';

/// Manages and persists [SettingsModel] state.
///
/// Must not import `lib/game/`.
class SettingsController extends Notifier<SettingsModel> {
  @override
  SettingsModel build() {
    return SaveService.instance.loadSettings();
  }

  /// Sets sound effects toggle and persists it.
  Future<void> setSound(bool value) async {
    state = state.copyWith(soundOn: value);
    await SaveService.instance.saveSettings(state);
    // Ads follow the game's sound switch.
    await ref.read(adServiceProvider).setMuted(!value);
  }

  /// Sets background music toggle and persists it.
  Future<void> setMusic(bool value) async {
    state = state.copyWith(musicOn: value);
    await SaveService.instance.saveSettings(state);
  }

  /// Sets haptics/vibration toggle and persists it.
  Future<void> setVibration(bool value) async {
    state = state.copyWith(vibrationOn: value);
    await SaveService.instance.saveSettings(state);
  }

  /// Sets color-blind mode toggle and persists it.
  Future<void> setColorBlind(bool value) async {
    state = state.copyWith(colorBlindMode: value);
    await SaveService.instance.saveSettings(state);
  }

  /// Sets animation speed toggle and persists it.
  Future<void> setFastAnimations(bool value) async {
    state = state.copyWith(fastAnimations: value);
    await SaveService.instance.saveSettings(state);
  }
}

/// Provides [SettingsController] and its [SettingsModel] state.
final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsModel>(SettingsController.new);
