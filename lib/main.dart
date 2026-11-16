import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/ads/consent_service.dart';
import 'core/audio/sound_service.dart';
import 'core/cloud/cloud_save_service.dart';
import 'core/remote_config/remote_config_service.dart';
import 'core/storage/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SaveService.init();

  // Restore this phone's cloud backup before the UI reads the save. Capped so
  // a slow or missing network never blocks the launch for long; uploads only
  // start once the backup has been checked.
  await CloudSaveService.instance.startAndRestore().timeout(
    const Duration(seconds: 4),
    onTimeout: () => false,
  );

  final remoteConfig = RemoteConfigService();
  await remoteConfig.fetch();

  final adService = AdService(
    consent: ConsentService(),
    policy: remoteConfig.interstitialPolicy,
  );

  // Ads init in background so splash is not blocked.
  unawaited(adService.initialize());
  unawaited(SoundService().preload());

  // Flutter errors → console (Crashlytics after FlutterFire — see FIREBASE_SETUP.md).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runApp(
    ProviderScope(
      overrides: [
        adServiceProvider.overrideWithValue(adService),
        remoteConfigProvider.overrideWithValue(remoteConfig),
      ],
      child: const MasalaSortApp(),
    ),
  );
}
