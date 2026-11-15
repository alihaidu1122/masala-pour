import 'package:flutter/foundation.dart';

/// Immutable user preference values.
///
/// Must not import `lib/game/`.
@immutable
class SettingsModel {
  /// Creates settings with defaults or specified values.
  const SettingsModel({
    this.soundOn = true,
    this.musicOn = true,
    this.vibrationOn = true,
    this.colorBlindMode = false,
    this.fastAnimations = false,
  });

  /// Whether sound effects (SFX) are enabled.
  final bool soundOn;

  /// Whether background music is enabled.
  final bool musicOn;

  /// Whether haptic feedback vibration is enabled.
  final bool vibrationOn;

  /// Whether color-blind symbols are displayed on spice layers.
  final bool colorBlindMode;

  /// Whether animations run at accelerated speed (2x).
  final bool fastAnimations;

  /// Returns a copy of [SettingsModel] with the specified fields replaced.
  SettingsModel copyWith({
    bool? soundOn,
    bool? musicOn,
    bool? vibrationOn,
    bool? colorBlindMode,
    bool? fastAnimations,
  }) {
    return SettingsModel(
      soundOn: soundOn ?? this.soundOn,
      musicOn: musicOn ?? this.musicOn,
      vibrationOn: vibrationOn ?? this.vibrationOn,
      colorBlindMode: colorBlindMode ?? this.colorBlindMode,
      fastAnimations: fastAnimations ?? this.fastAnimations,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModel &&
          runtimeType == other.runtimeType &&
          soundOn == other.soundOn &&
          musicOn == other.musicOn &&
          vibrationOn == other.vibrationOn &&
          colorBlindMode == other.colorBlindMode &&
          fastAnimations == other.fastAnimations;

  @override
  int get hashCode => Object.hash(
    soundOn,
    musicOn,
    vibrationOn,
    colorBlindMode,
    fastAnimations,
  );

  @override
  String toString() =>
      'SettingsModel(sound: $soundOn, music: $musicOn, vib: $vibrationOn, '
      'colorBlind: $colorBlindMode, fastAnim: $fastAnimations)';
}
