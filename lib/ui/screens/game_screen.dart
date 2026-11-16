import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/game_config.dart';
import '../../core/rewards/wallet_provider.dart';
import '../../core/rewards/reward_rules.dart';
import '../../config/asset_paths.dart';
import '../../core/ads/ad_service.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/audio/sound_service.dart';
import '../../core/haptics/haptics_service.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/settings/settings_model.dart';
import '../../core/storage/progress_provider.dart';
import '../../core/storage/save_service.dart';
import '../../game/controller/game_controller.dart';
import '../../game/flame/sort_game.dart';
import '../../game/levels/level.dart';
import '../widgets/dialogs.dart';
import '../widgets/hud.dart';
import '../widgets/level_banners.dart';
import '../widgets/tutorial_overlay.dart';
import 'daily_screen.dart';

/// Full-screen game view: Flame board + Flutter HUD overlay.
class GameScreen extends ConsumerStatefulWidget {
  /// Creates the game screen for [level] (campaign) or [dailyLevel].
  const GameScreen({super.key, this.level = 1, this.dailyKey, this.dailyLevel});

  final int level;
  final String? dailyKey;
  final Level? dailyLevel;

  bool get isDaily => dailyLevel != null;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final SortGame _game;
  bool _winShown = false;
  bool _stuckShown = false;
  bool _showTutorial = false;
  bool _introDismissed = false;

  /// One free helper per level when no ad video is available.
  bool _freeHelperUsed = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();

    if (!widget.isDaily && widget.level == 1) {
      _showTutorial = true;
    }

    final settings = ref.read(settingsControllerProvider);
    _game = SortGame(
      controller: ref.read(gameControllerProvider.notifier),
      onLevelComplete: _onWin,
      onStuck: _onStuck,
      soundService: ref.read(soundServiceProvider),
      hapticsService: ref.read(hapticsServiceProvider),
      colorBlindMode: settings.colorBlindMode,
      speedFactor: settings.fastAnimations ? 2.0 : 1.0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(gameControllerProvider.notifier);
      if (widget.dailyLevel != null) {
        ctrl.loadLevelData(widget.dailyLevel!);
      } else {
        ctrl.loadLevel(widget.level);
      }
      _startedAt = DateTime.now();
      ref.read(analyticsServiceProvider).levelStart(widget.level);
    });
  }

  Future<bool> _watchRewarded(String placement) async {
    final ads = ref.read(adServiceProvider);
    final analytics = ref.read(analyticsServiceProvider);
    analytics.rewardedOffer(placement);
    final ok = await ads.showRewarded(placement);
    if (ok) {
      analytics.rewardedWatched(placement);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not available, try again later')),
      );
    }
    return ok;
  }

  /// Offers a helper for a rewarded ad or [price] coins. Returns true when
  /// the player earned it.
  Future<bool> _getHelper({
    required String placement,
    required String title,
    required String description,
    required String asset,
    required int price,
  }) async {
    final choice = await GameDialogs.showHelperOffer(
      context,
      title: title,
      description: description,
      asset: asset,
      price: price,
      coins: ref.read(walletProvider).coins,
    );
    if (!mounted || choice == null) return false;
    if (choice == HelperChoice.coins) {
      final ok = await ref.read(walletProvider.notifier).trySpend(price);
      if (ok) ref.read(soundServiceProvider).playComplete();
      return ok;
    }
    if (!ref.read(adServiceProvider).isRewardedReady) {
      // No video to show: never leave the player stuck. The first time per
      // level the helper is free; after that we suggest coins.
      unawaited(ref.read(adServiceProvider).preloadRewarded());
      final messenger = ScaffoldMessenger.of(context);
      if (!_freeHelperUsed) {
        _freeHelperUsed = true;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No video available right now, this one is free!'),
          ),
        );
        return true;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No video right now. Try again soon or use coins.'),
        ),
      );
      return false;
    }
    return _watchRewarded(placement);
  }

  void _onWin() {
    if (_winShown || !mounted) return;
    _winShown = true;

    final state = ref.read(gameControllerProvider);
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    ref
        .read(analyticsServiceProvider)
        .levelComplete(
          level: widget.level,
          moves: state.moveCount,
          stars: state.stars ?? 1,
          seconds: seconds,
        );

    // Coins: full reward on the first clear, a little on replays; a chest
    // for finishing a chapter; a bonus for today's Daily Challenge.
    final wallet = ref.read(walletProvider.notifier);
    final save = SaveService.instance;
    var coins = 0;
    var chestCoins = 0;
    String? chestLabel;
    if (widget.isDaily) {
      final key = widget.dailyKey;
      if (key != null && !save.dailyCoinsPaid(key)) {
        coins = RewardRules.dailyChallengeCoins;
        wallet.claimDailyChallenge(key);
      }
    } else {
      final firstClear = save.starsForLevel(widget.level) == 0;
      final tier = (state.level?.difficulty ?? LevelDifficulty.normal).index;
      coins = firstClear
          ? RewardRules.levelCoins(
              stars: state.stars ?? 1,
              difficultyTier: tier,
            )
          : RewardRules.replayCoins;
      wallet.add(coins);
      final chapter = GameConfig.chapterIndex(widget.level);
      if (widget.level % GameConfig.levelsPerChapter == 0 &&
          !save.chestsClaimed.contains(chapter)) {
        chestCoins = RewardRules.chapterChestCoins(chapter);
        chestLabel = '${GameConfig.chapterFor(widget.level).name} chest!';
        wallet.claimChest(chapter);
      }
    }

    if (widget.isDaily) {
      recordDailyWinIfNeeded(ref, widget.dailyKey);
    } else {
      ref
          .read(progressProvider.notifier)
          .onLevelComplete(
            levelId: widget.level,
            stars: state.stars ?? 1,
            moves: state.moveCount,
          );
      ref.read(adServiceProvider).onLevelCompleted();
    }

    GameDialogs.showWin(
      context,
      level: widget.isDaily ? 0 : widget.level,
      stars: state.stars ?? 1,
      moves: state.moveCount,
      par: state.par,
      coins: coins,
      chestCoins: chestCoins,
      chestLabel: chestLabel,
      onNext: () async {
        Navigator.of(context).pop();
        if (widget.isDaily) {
          Navigator.of(context).pop();
          return;
        }
        final shown = await ref
            .read(adServiceProvider)
            .maybeShowInterstitialAfterWin(completedLevelId: widget.level);
        if (shown) {
          ref.read(analyticsServiceProvider).interstitialShown();
        }
        _goToLevel(widget.level + 1);
      },
      onReplay: () {
        Navigator.of(context).pop();
        _resetLevel();
      },
    );
  }

  void _onStuck() {
    if (_stuckShown || !mounted) return;
    _stuckShown = true;
    ref.read(analyticsServiceProvider).levelStuck(widget.level);

    final s = ref.read(gameControllerProvider);
    final canSkip =
        !widget.isDaily &&
        ref.read(progressProvider.notifier).canSkip(widget.level);

    GameDialogs.showStuck(
      context,
      canUndo: s.undosLeft > 0,
      canAddJar: !s.extraJarAdded,
      canSkip: canSkip,
      onUndo: () {
        Navigator.of(context).pop();
        _doUndo();
      },
      onRestart: () {
        Navigator.of(context).pop();
        _resetLevel();
      },
      onAddJar: () async {
        Navigator.of(context).pop();
        _stuckShown = false;
        await _requestExtraJar();
      },
      onSkip: () async {
        Navigator.of(context).pop();
        final ok = await _getHelper(
          placement: RewardedPlacement.skip,
          title: 'Skip Level',
          description: 'Move straight on to the next level.',
          asset: AssetPaths.skip,
          price: RewardRules.skipPrice,
        );
        if (ok && mounted) {
          ref
              .read(progressProvider.notifier)
              .onLevelComplete(levelId: widget.level, stars: 1, moves: 0);
          _goToLevel(widget.level + 1);
        } else {
          _stuckShown = false;
        }
      },
    );
  }

  void _resetLevel() {
    ref.read(soundServiceProvider).playTap();
    ref.read(hapticsServiceProvider).tap();
    _winShown = false;
    _stuckShown = false;
    ref.read(gameControllerProvider.notifier).restart();
    if (!widget.isDaily) {
      ref.read(progressProvider.notifier).onRestart(widget.level);
      ref.read(analyticsServiceProvider).levelRestart(widget.level);
    }
    _startedAt = DateTime.now();
  }

  void _goToLevel(int id) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.game, arguments: id);
  }

  Future<void> _doUndo() async {
    final s = ref.read(gameControllerProvider);
    _stuckShown = false;

    if (s.undosLeft <= 0) {
      final ok = await _getHelper(
        placement: RewardedPlacement.undo,
        title: 'Out of Undos',
        description: 'Get 3 more undos for this level.',
        asset: AssetPaths.undo,
        price: RewardRules.undoPackPrice,
      );
      if (ok && mounted) {
        ref.read(gameControllerProvider.notifier).grantUndos(3);
        await _doUndo();
      }
      return;
    }

    ref.read(soundServiceProvider).playTap();
    ref.read(hapticsServiceProvider).tap();
    SaveService.instance.recordUndoUsed();
    ref.read(analyticsServiceProvider).undoUsed();
    ref.read(gameControllerProvider.notifier).undo();
  }

  void _openSettings() {
    ref.read(soundServiceProvider).playTap();
    ref.read(hapticsServiceProvider).tap();
    Navigator.of(context).pushNamed(AppRoutes.settings);
  }

  Future<void> _requestExtraJar() async {
    ref.read(soundServiceProvider).playTap();
    final ok = await _getHelper(
      placement: RewardedPlacement.extraJar,
      title: '+1 Jar',
      description: 'Add an empty jar to this level.',
      asset: AssetPaths.addJar,
      price: RewardRules.extraJarPrice,
    );
    if (ok && mounted) {
      ref.read(gameControllerProvider.notifier).addExtraJar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    // Board area between the HUD bars (set before the board is synced).
    final pad = MediaQuery.paddingOf(context);
    final spike =
        (state.level?.difficulty ?? LevelDifficulty.normal) !=
        LevelDifficulty.normal;
    _game.topInset = pad.top + (spike ? 122 : 96);
    _game.bottomInset = pad.bottom + 112;
    _game.theme = widget.isDaily
        ? GameConfig.chapters.first
        : GameConfig.chapterFor(widget.level);

    ref.listen<GameState>(gameControllerProvider, (_, next) {
      if (next.board != null) _game.syncBoard(next.board!);
    });
    if (state.board != null) {
      _game.syncBoard(state.board!);
    }

    ref.listen<SettingsModel>(settingsControllerProvider, (_, next) {
      _game.applySettings(
        colorBlind: next.colorBlindMode,
        speed: next.fastAnimations ? 2.0 : 1.0,
        sound: ref.read(soundServiceProvider),
        haptics: ref.read(hapticsServiceProvider),
      );
    });

    final displayLevel = widget.isDaily ? 'Daily' : '${widget.level}';

    return Scaffold(
      backgroundColor: GameConfig.gameBackground,
      body: Stack(
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: GameHud(
              levelLabel: displayLevel,
              moveCount: state.moveCount,
              undosLeft: state.undosLeft,
              par: state.par,
              canUndo:
                  state.phase == GamePhase.playing ||
                  state.phase == GamePhase.stuck,
              canAddJar: !state.extraJarAdded,
              onUndo: _doUndo,
              onRestart: _resetLevel,
              onAddJar: _requestExtraJar,
              onSettings: _openSettings,
              difficulty: state.level?.difficulty ?? LevelDifficulty.normal,
              onHome: () => Navigator.of(
                context,
              ).popUntil((r) => r.settings.name == AppRoutes.home || r.isFirst),
            ),
          ),
          if (state.phase == GamePhase.loading)
            const Center(
              child: CircularProgressIndicator(color: GameConfig.brandAccent),
            ),
          if (state.level != null &&
              state.level!.difficulty != LevelDifficulty.normal &&
              state.phase != GamePhase.loading)
            LevelStartBanner(
              key: ValueKey('banner-${state.level!.id}'),
              difficulty: state.level!.difficulty,
            ),
          if (!widget.isDaily &&
              widget.level > 1 &&
              widget.level % GameConfig.levelsPerChapter == 1 &&
              state.phase != GamePhase.loading &&
              state.level?.intro == null)
            LevelStartBanner(
              key: ValueKey('chapter-${widget.level}'),
              difficulty: LevelDifficulty.normal,
              label:
                  'Chapter ${GameConfig.chapterIndex(widget.level) + 1}: '
                  '${GameConfig.chapterFor(widget.level).name}',
              colors: [
                GameConfig.chapterFor(widget.level).glow,
                GameConfig.chapterFor(widget.level).top,
              ],
            ),
          if (state.level?.intro != null && !_introDismissed)
            MechanicIntroOverlay(
              intro: state.level!.intro!,
              onDismiss: () => setState(() => _introDismissed = true),
            ),
          if (_showTutorial)
            TutorialOverlay(
              onDismiss: () {
                setState(() => _showTutorial = false);
                ref.read(analyticsServiceProvider).tutorialComplete();
              },
            ),
        ],
      ),
    );
  }
}
