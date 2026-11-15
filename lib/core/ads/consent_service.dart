import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP consent flow (required for EU/UK before loading ads).
///
/// Must not import `lib/game/`.
class ConsentService {
  /// Creates a consent service.
  ConsentService();

  bool _privacyOptionsRequired = false;

  /// Whether Settings should show a "Privacy options" entry.
  bool get isPrivacyOptionsRequired => _privacyOptionsRequired;

  /// Runs the UMP update + form (if required). Safe to call multiple times.
  Future<void> gatherConsent() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          _privacyOptionsRequired =
              await ConsentInformation.instance
                  .getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;

          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _loadAndShowForm();
          }
        } catch (e) {
          debugPrint('UMP post-update error: $e');
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint('UMP consent info error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  Future<void> _loadAndShowForm() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint('UMP form error: ${error.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Opens the privacy options form from Settings when required.
  Future<void> showPrivacyOptions() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint('UMP privacy options error: ${error.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
