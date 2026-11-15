import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/asset_paths.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/storage/save_service.dart';
import '../../game/levels/daily_challenge.dart';
import '../widgets/asset_icon.dart';
import '../widgets/game_ui.dart';

/// Daily Challenge hub: today's level + recent completion calendar.
class DailyScreen extends ConsumerWidget {
  /// Creates the daily challenge screen.
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final key = DailyChallenge.dateKey(today);
    final completed = SaveService.instance.isDailyCompleted(key);
    final level = DailyChallenge.generate(date: today);

    return GameBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Daily Challenge'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: AssetIcon(AssetPaths.daily, size: 80)),
            const SizedBox(height: 12),
            Text(
              key,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              completed
                  ? 'Completed today — come back tomorrow!'
                  : 'A fresh puzzle seeded from today’s date. Par ${level.par}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CandyButton(
              label: completed ? 'Play again' : 'Play Daily',
              height: 62,
              fontSize: 24,
              icon: const AssetIcon(AssetPaths.play, size: 34),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.game,
                  arguments: {
                    'levelId': level.id,
                    'dailyKey': key,
                    'dailyLevel': level,
                  },
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Last 14 days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _DailyStrip(anchor: today),
          ],
        ),
      ),
    );
  }
}

class _DailyStrip extends StatelessWidget {
  const _DailyStrip({required this.anchor});
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(14, (i) {
      return DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
      ).subtract(Duration(days: 13 - i));
    });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final day in days)
          _DayChip(
            day: day,
            done: SaveService.instance.isDailyCompleted(
              DailyChallenge.dateKey(day),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.done});
  final DateTime day;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final label = '${day.month}/${day.day}';
    return Chip(
      avatar: Icon(
        done ? Icons.check_circle : Icons.circle_outlined,
        size: 16,
        color: done ? Colors.green : null,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Marks daily complete after a win when [dailyKey] is set.
Future<void> recordDailyWinIfNeeded(WidgetRef ref, String? dailyKey) async {
  if (dailyKey == null) return;
  await SaveService.instance.markDailyCompleted(dailyKey);
  ref.read(analyticsServiceProvider).dailyComplete(dailyKey);
}
