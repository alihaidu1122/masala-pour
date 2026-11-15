import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';

/// Wraps Flutter's built-in [HapticFeedback] to provide tactile responses
/// that respect user vibration preferences.
///
/// Must not import `lib/game/`.
class HapticsService {
  /// Creates the haptics service.
  const HapticsService({this.enabled = true});

  /// Whether haptic feedback is allowed by user settings.
  final bool enabled;

  /// Light impact for UI taps and jar selection.
  Future<void> tap() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Haptics unavailable on this platform/device.
    }
  }

  /// Medium impact on beginning a pour transfer.
  Future<void> pour() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Haptics unavailable on this platform/device.
    }
  }

  /// Heavy impact when a jar is fully completed.
  Future<void> jarComplete() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Haptics unavailable on this platform/device.
    }
  }

  /// Celebratory vibration on level victory.
  Future<void> win() async {
    if (!enabled) return;
    try {
      await HapticFeedback.vibrate();
    } catch (_) {
      // Haptics unavailable on this platform/device.
    }
  }
}

/// Provides a [HapticsService] configured according to the active settings.
final hapticsServiceProvider = Provider<HapticsService>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return HapticsService(enabled: settings.vibrationOn);
});
