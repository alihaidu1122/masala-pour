import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';

/// Audio filenames in `assets/audio/`.
abstract final class SoundFiles {
  static const String tap = 'tap.mp3';
  static const String click = 'click.mp3';
  static const String pour = 'pour.mp3';
  static const String error = 'error.mp3';
  static const String complete = 'complete.mp3';
  static const String win = 'win.mp3';

  static const List<String> allShortSounds = [
    tap,
    click,
    pour,
    error,
    complete,
    win,
  ];
}

/// Function signature for audio playback.
typedef AudioPlayerFn = Future<void> Function(String filename, {double volume});

/// Manages short sound effects and background music via [FlameAudio].
///
/// Respects user preferences in [SettingsModel]. Must not import `lib/game/`.
class SoundService {
  /// Creates the sound service. [playHandler] can be provided for unit testing.
  SoundService({
    this.soundEnabled = true,
    this.musicEnabled = true,
    AudioPlayerFn? playHandler,
  }) : _playHandler = playHandler ?? _defaultPlayHandler;

  /// Whether sound effects should play.
  final bool soundEnabled;

  /// Whether music should play.
  final bool musicEnabled;

  final AudioPlayerFn _playHandler;

  static bool _preloaded = false;

  static Future<void> _defaultPlayHandler(
    String filename, {
    double volume = 1.0,
  }) {
    return FlameAudio.play(filename, volume: volume);
  }

  /// Preloads all short SFX files into Flame AudioCache.
  Future<void> preload() async {
    if (_preloaded) return;
    try {
      await FlameAudio.audioCache.loadAll(SoundFiles.allShortSounds);
      _preloaded = true;
    } catch (_) {
      // Audio loading may fail in test environments or unsupported devices.
    }
  }

  /// Plays a short audio clip if [soundEnabled] is true.
  Future<void> _play(String filename, {double volume = 1.0}) async {
    if (!soundEnabled) return;
    try {
      await _playHandler(filename, volume: volume);
    } catch (_) {
      // Audio playback failed or device is muted.
    }
  }

  /// Soft UI / jar select tap.
  Future<void> playTap() => _play(SoundFiles.tap, volume: 0.65);

  /// Stronger button click (menus / confirms).
  Future<void> playClick() => _play(SoundFiles.click, volume: 0.7);

  /// Spice pour flow.
  Future<void> playPour() => _play(SoundFiles.pour, volume: 0.85);

  /// Illegal move / error buzz.
  Future<void> playError() => _play(SoundFiles.error, volume: 0.75);

  /// Jar completed with one color.
  Future<void> playComplete() => _play(SoundFiles.complete, volume: 0.9);

  /// Level victory.
  Future<void> playWin() => _play(SoundFiles.win, volume: 1.0);
}

/// Provides a [SoundService] instance synchronized with current user settings.
final soundServiceProvider = Provider<SoundService>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return SoundService(
    soundEnabled: settings.soundOn,
    musicEnabled: settings.musicOn,
  );
});
