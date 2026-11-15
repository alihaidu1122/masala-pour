import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../../core/ads/ad_service.dart';
import '../../core/settings/settings_controller.dart';
import '../widgets/game_ui.dart';

/// User settings: audio, haptics, accessibility, animation speed, and privacy.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final theme = Theme.of(context);
    final consent = ref.read(adServiceProvider).consent;

    return GameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Settings'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionHeader(title: 'Audio & Haptics', theme: theme),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Sound effects'),
              value: settings.soundOn,
              onChanged: notifier.setSound,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.music_note_rounded),
              title: const Text('Music'),
              value: settings.musicOn,
              onChanged: notifier.setMusic,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Vibration'),
              value: settings.vibrationOn,
              onChanged: notifier.setVibration,
            ),
            const Divider(height: 24),
            _SectionHeader(title: 'Gameplay & Accessibility', theme: theme),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_rounded),
              title: const Text('Color-blind mode'),
              value: settings.colorBlindMode,
              onChanged: notifier.setColorBlind,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.speed_rounded),
              title: const Text('Fast animations'),
              value: settings.fastAnimations,
              onChanged: notifier.setFastAnimations,
            ),
            const Divider(height: 24),
            _SectionHeader(title: 'About & Privacy', theme: theme),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy policy'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _showPrivacyPolicy(context),
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('Privacy options'),
              subtitle: Text(
                consent.isPrivacyOptionsRequired
                    ? 'Manage ad consent'
                    : 'Available when required by your region',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await consent.showPrivacyOptions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('App version'),
              subtitle: Text('1.0.0+1 · ${GameConfig.appName}'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '${GameConfig.appName} values your privacy.\n\n'
            '• Progress and settings stay on device (SharedPreferences).\n'
            '• AdMob may show interstitials / rewarded ads with UMP consent.\n'
            '• Analytics / Crashlytics activate after Firebase setup '
            '(see FIREBASE_SETUP.md).\n\n'
            'Replace this text with your published privacy policy URL before release.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
