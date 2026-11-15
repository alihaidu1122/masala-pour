# Firebase setup

Project: **masala-pour-game**  
Package / Bundle ID: **com.masalapour.app**

Config files already in the repo:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist` (included in Runner target)

## Enable Flutter Firebase SDKs

```bash
flutter pub add firebase_core firebase_analytics firebase_crashlytics firebase_remote_config
dart pub global activate flutterfire_cli
flutterfire configure --project=masala-pour-game \
  --platforms=android,ios \
  --android-package-name=com.masalapour.app \
  --ios-bundle-id=com.masalapour.app
```

Then in `main.dart`:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

Point [AnalyticsService] / [RemoteConfigService] at the Firebase SDKs (keep the
same method names). Remote Config keys:

| Key | Default |
| --- | --- |
| `interstitial_start_level` | 10 |
| `interstitial_every_n_levels` | 3 |
| `interstitial_min_seconds` | 90 |
| `free_undos_per_level` | 3 |

## Verify

- Analytics DebugView (ADB): `adb shell setprop debug.firebase.analytics.app com.masalapour.app`
- Crashlytics: force a test crash once in a non-store build
- Remote Config: change a key and confirm interstitial timing updates after fetch

## Cloud backup (anonymous login + Firestore)

The app backs up each player's save to `players/{key}` in Firestore, where
`key` is a SHA-256 hash of a phone id that survives uninstall/reinstall
(Android `ANDROID_ID`; iOS: random id in the Keychain). Code:
`lib/core/cloud/cloud_save_service.dart`, merge rules in `save_merge.dart`.

One-time console setup (project **masala-pour-game**):

1. Authentication → Get started → Sign-in method → enable **Anonymous**.
2. Firestore Database → Create database → production mode → pick a region
   near your players.
3. Firestore → Rules → paste the contents of `firestore.rules` → Publish.

Until steps 1–2 are done the app logs
`CloudSave: start failed … CONFIGURATION_NOT_FOUND` and simply plays offline.

Play Console → Data safety: declare **Device or other IDs** and **App activity
(game progress)**, collected for **App functionality**, not shared.
