import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'save_service.dart';

/// Provides the initialised [SaveService] singleton.
///
/// Used by screens that need to read or write progress. Must not be called
/// before [SaveService.init] has completed (guaranteed by [main]).
final saveServiceProvider = Provider<SaveService>((_) => SaveService.instance);

/// Notifier that owns the per-session progress state and writes through to
/// [SaveService].
class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    final svc = ref.read(saveServiceProvider);
    return ProgressState(currentLevel: svc.currentLevel);
  }

  /// Called when a level completes. Updates stars, advances current level, and
  /// persists everything.
  Future<void> onLevelComplete({
    required int levelId,
    required int stars,
    required int moves,
  }) async {
    final svc = ref.read(saveServiceProvider);
    await svc.saveStars(levelId, stars);
    await svc.advanceLevel(levelId + 1);
    await svc.clearRestarts(levelId);
    await svc.recordLevelComplete(moves: moves);
    state = ProgressState(currentLevel: svc.currentLevel);
  }

  /// Called when the player restarts a level.
  Future<void> onRestart(int levelId) async {
    await ref.read(saveServiceProvider).incrementRestarts(levelId);
  }

  /// Stars for a specific level (read-only helper).
  int starsFor(int levelId) =>
      ref.read(saveServiceProvider).starsForLevel(levelId);

  /// Whether the player may skip [levelId] (3+ restarts).
  bool canSkip(int levelId) =>
      ref.read(saveServiceProvider).restartCount(levelId) >= 3;
}

/// Provides [ProgressNotifier].
final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);

/// Immutable snapshot of player progress.
class ProgressState {
  const ProgressState({required this.currentLevel});

  /// Highest level reached; always ≥ 1.
  final int currentLevel;
}
