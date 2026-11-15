# Release checklist — Masala Sort

## Build
- [x] Application ID set to `com.masalapour.app` (Android + iOS)
- [ ] Replace AdMob **app id** + **ad unit ids** in `ads_config.dart` / AndroidManifest (no test IDs in release)
- [ ] Confirm `kReleaseMode` paths never use test ad units
- [ ] Create Play product `remove_ads` (non-consumable)
- [ ] Signing: upload key / Play App Signing configured
- [ ] `flutter build appbundle --release`
- [ ] Install internal track AAB on a real device

## Privacy & compliance
- [ ] Host a public privacy policy URL and link it in Settings + Play Console
- [ ] Data safety form: ads (AdMob), analytics (if Firebase), crash logs (if Crashlytics)
- [ ] UMP consent tested with a VPN in EU/UK
- [ ] Target audience **13+** (not designed for children / no Designed for Families)
- [ ] Content rating questionnaire completed

## Quality
- [ ] `flutter analyze` clean
- [ ] `flutter test` all green
- [ ] Play levels 1–20 on a low-end Android phone (smooth pours)
- [ ] Rewarded ads: Undo / +1 Jar / Skip only grant after reward
- [ ] Interstitials: none before level 10; only on win→next; respect remove-ads
- [ ] Daily challenge changes after midnight local time

## Closed testing
- [ ] Closed testing track with **12+ testers** for **14 days** (Play policy)
- [ ] Collect crash-free sessions before production rollout

## Firebase (optional but recommended)
- [ ] Follow `FIREBASE_SETUP.md`
- [ ] DebugView events visible
- [ ] Test Crashlytics crash appears
- [ ] Remote Config knobs change ad frequency without an app update
