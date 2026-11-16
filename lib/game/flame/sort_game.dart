import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../core/audio/sound_service.dart';
import '../../core/haptics/haptics_service.dart';
import '../controller/game_controller.dart';
import '../logic/board_state.dart';
import '../logic/jar.dart';
import 'board_background.dart';
import 'effects.dart';
import 'jar_component.dart';
import 'pour_animation.dart';
import 'pour_stream.dart';

/// [FlameGame] that renders the jar board, processes taps & drags, and drives
/// the pour animation.
///
/// Game logic lives entirely in [GameController]. [SortGame] only draws and
/// animates.
class SortGame extends FlameGame {
  /// Creates the game.
  SortGame({
    required this.controller,
    required this.onLevelComplete,
    required this.onStuck,
    this.soundService,
    this.hapticsService,
    this.colorBlindMode = false,
    this.speedFactor = 1.0,
  });

  /// Pure-logic + state driver.
  final GameController controller;

  /// Called once after the win animation finishes.
  final VoidCallback onLevelComplete;

  /// Called once when the board becomes stuck.
  final VoidCallback onStuck;

  /// Audio playback service for SFX.
  SoundService? soundService;

  /// Haptic feedback provider.
  HapticsService? hapticsService;

  /// Mirrors the settings flag; update with [applySettings].
  bool colorBlindMode;

  /// Animation speed multiplier (1 = normal, 2 = fast).
  double speedFactor;

  // ── Jar components ────────────────────────────────────────────────────────
  final List<JarComponent> _jars = [];
  int? _builtForJarCount;

  // ── Pour animation ────────────────────────────────────────────────────────
  PourAnimation? _anim;
  int _animFrom = -1;
  int _animTo = -1;
  Color _pourColor = Colors.orange;
  int _pourColorId = 0;
  PourStreamComponent? _stream;
  bool _landed = false;

  // ── Last board snapshot ───────────────────────────────────────────────────
  BoardState? _lastBoard;

  final BoardBackground _background = BoardBackground();
  Vector2? _layoutSize;

  /// Chapter backdrop.
  set theme(ChapterTheme value) => _background.theme = value;

  /// Space reserved at the top for the HUD (logical px).
  double topInset = 120;

  /// Space reserved at the bottom for the action bar (logical px).
  double bottomInset = 130;

  // ── Flame lifecycle ───────────────────────────────────────────────────────

  @override
  Color backgroundColor() => GameConfig.gameBackground;

  @override
  Future<void> onLoad() async {
    _background.size = size.clone();
    add(_background);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    wake();
    _background.size = size.clone();
    final changed =
        _layoutSize == null ||
        (_layoutSize!.x - size.x).abs() > 0.5 ||
        (_layoutSize!.y - size.y).abs() > 0.5;
    if (_lastBoard != null && (changed || _jars.isEmpty)) {
      _rebuildLayout(_lastBoard!, animateIn: _jars.isEmpty);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called by the Flutter widget whenever [GameState.board] changes.
  void syncBoard(BoardState board) {
    wake();
    final jarCountChanged = board.jarCount != _builtForJarCount;
    _lastBoard = board;

    if (jarCountChanged || _jars.isEmpty) {
      _rebuildLayout(board, animateIn: _jars.isEmpty);
      return;
    }

    _syncJarData(board);
  }

  /// Applies updated settings without rebuilding the layout.
  void applySettings({
    bool? colorBlind,
    double? speed,
    SoundService? sound,
    HapticsService? haptics,
  }) {
    if (colorBlind != null) colorBlindMode = colorBlind;
    if (speed != null) speedFactor = speed;
    if (sound != null) soundService = sound;
    if (haptics != null) hapticsService = haptics;
    wake();
    for (final j in _jars) {
      j.colorBlindMode = colorBlindMode;
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  void _rebuildLayout(BoardState board, {bool animateIn = true}) {
    // ignore: parameter_assignments
    // The game may receive a board before Flutter has laid it out; the first
    // onGameResize will build the layout then.
    if (!hasLayout || size.x <= 0 || size.y <= 0) return;
    _layoutSize = size.clone();
    _clearStream();
    if (_anim != null) {
      // Finish an in-flight pour logically so the controller never stays
      // stuck in the animating phase.
      _anim = null;
      _landed = false;
      controller.applyAnimationComplete(_animFrom, _animTo);
      _animFrom = -1;
      _animTo = -1;
      board = controller.snapshot.board ?? board;
      _lastBoard = board;
    }
    for (final j in _jars) {
      j.removeFromParent();
    }
    _jars.clear();
    _builtForJarCount = board.jarCount;

    final layout = _BoardLayout.compute(
      size,
      board.jarCount,
      topInset: topInset,
      bottomInset: bottomInset,
    );

    for (var i = 0; i < board.jarCount; i++) {
      final comp = JarComponent(
        jarIndex: i,
        jar: board.jars[i],
        position: layout.positions[i],
        jarSize: layout.jarSize,
        onTap: _handleTap,
        onDragStarted: _handleDragStart,
        onDragMoved: _handleDragMove,
        onDragEnded: _handleDragEnd,
        colorBlindMode: colorBlindMode,
        introDelay: animateIn ? 0.05 + i * 0.045 : 0,
        hiddenCount: controller.snapshot.hiddenAt(i),
      );
      if (!animateIn) comp.skipIntro();
      add(comp);
      _jars.add(comp);
    }
    _background.setShelves(layout.shelves);
    _refreshSelection();
  }

  // ── Jar data sync ──────────────────────────────────────────────────────────

  void _syncJarData(BoardState board) {
    if (_jars.length != board.jarCount) return;
    for (var i = 0; i < _jars.length; i++) {
      _jars[i].clearPourPreview();
      _jars[i].updateJar(board.jars[i]);
      _jars[i].hiddenCount = controller.snapshot.hiddenAt(i);
      if (_jars[i].consumeRevealFlag()) _spawnRevealSparkle(i, board.jars[i]);
      if (_jars[i].consumeUnlockFlag()) _spawnUnlockSparkle(i);
      if (_jars[i].consumeCompletedFlag()) {
        _spawnCompleteSparkle(i, board.jars[i]);
      }
    }
  }

  // ── Tap input ─────────────────────────────────────────────────────────────

  void _handleTap(int index) {
    wake();
    if (_anim != null) return;

    hapticsService?.tap();
    final result = controller.handleTap(index);

    if (result.isPour) {
      soundService?.playPour();
      hapticsService?.pour();
      _startAnim(result.from!, result.to!, result.count!);
    } else if (result.isIllegal) {
      soundService?.playError();
      if (index >= 0 && index < _jars.length) {
        _jars[index].shake();
      }
    } else if (result.isSelect || result.isDeselect) {
      soundService?.playTap();
    }

    _refreshSelection();
  }

  // ── Drag & Drop input ─────────────────────────────────────────────────────

  void _handleDragStart(int index, Vector2 startPos) {
    wake();
    if (_anim != null) return;
    hapticsService?.tap();
    if (controller.snapshot.selectedJar != null &&
        controller.snapshot.selectedJar != index) {
      controller.handleTap(controller.snapshot.selectedJar!);
      _refreshSelection();
    }
  }

  void _handleDragMove(int fromIndex, Vector2 currentPos) {
    final target = _findTargetJar(fromIndex, currentPos);
    for (var i = 0; i < _jars.length; i++) {
      _jars[i].isHovered = (target != null && i == target);
    }
  }

  void _handleDragEnd(int fromIndex, Vector2 dropPos) {
    for (final j in _jars) {
      j.isHovered = false;
    }

    final target = _findTargetJar(fromIndex, dropPos);

    if (target != null) {
      final result = controller.attemptPour(fromIndex, target);
      if (result.isPour) {
        soundService?.playPour();
        hapticsService?.pour();
        _startAnim(result.from!, result.to!, result.count!, startPos: dropPos);
      } else {
        if (target >= 0 && target < _jars.length) {
          _jars[target].shake();
        }
        if (fromIndex >= 0 && fromIndex < _jars.length) {
          _jars[fromIndex].shake();
          _jars[fromIndex].returnHome();
        }
        hapticsService?.tap();
      }
    } else {
      if (fromIndex >= 0 && fromIndex < _jars.length) {
        final jar = _jars[fromIndex];
        final dist = (dropPos - jar.home).length;
        if (dist < 12.0) {
          _handleTap(fromIndex);
        } else {
          jar.returnHome();
        }
      }
    }

    _refreshSelection();
  }

  int? _findTargetJar(int fromIndex, Vector2 touchPos) {
    int? bestTarget;
    double bestDist = double.infinity;

    for (var i = 0; i < _jars.length; i++) {
      if (i == fromIndex) continue;
      final jar = _jars[i];
      final home = jar.home;
      final sz = jar.jarSize;

      final left = home.x - sz.x * 0.75;
      final right = home.x + sz.x * 0.75;
      final top = home.y - sz.y * 1.30;
      final bottom = home.y + sz.y * 0.20;

      if (touchPos.x >= left &&
          touchPos.x <= right &&
          touchPos.y >= top &&
          touchPos.y <= bottom) {
        final dist = (touchPos - home).length;
        if (dist < bestDist) {
          bestDist = dist;
          bestTarget = i;
        }
      }
    }
    return bestTarget;
  }

  void _refreshSelection() {
    final sel = controller.snapshot.selectedJar;
    for (final j in _jars) {
      j.isSelected = j.jarIndex == sel;
    }
  }

  // ── Pour animation ────────────────────────────────────────────────────────

  void _startAnim(int from, int to, int count, {Vector2? startPos}) {
    if (from >= _jars.length || to >= _jars.length) return;
    _animFrom = from;
    _animTo = to;

    final sourceJar = _jars[from].jar;
    if (!sourceJar.isEmpty) {
      _pourColorId = sourceJar.topColor!;
      _pourColor = GameConfig.spiceById(_pourColorId).color;
    }

    _clearStream();
    _stream = PourStreamComponent(color: _pourColor);
    add(_stream!);

    final src = _jars[from];
    _anim = PourAnimation(
      fromIndex: from,
      toIndex: to,
      fromHome: src.home.clone(),
      toHome: _jars[to].home.clone(),
      jarWidth: src.jarSize.x,
      jarHeight: src.jarSize.y,
      mouthHalfWidth: src.mouthHalfWidth,
      layerCount: count,
      speedFactor: speedFactor,
      screenWidth: size.x,
      startPos: startPos,
    );
  }

  void _clearStream() {
    _stream?.removeFromParent();
    _stream = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _tickAnim(dt);
    _checkIdle(dt);
  }

  // ── Battery: stop drawing when nothing moves ──────────────────────────────

  double _idleFor = 0;

  void _checkIdle(double dt) {
    final busy =
        _anim != null ||
        _jars.any((j) => j.isBusy) ||
        children.any(
          (c) =>
              c is ParticleSystemComponent ||
              c is TimerComponent ||
              c is PourStreamComponent,
        );
    if (busy) {
      _idleFor = 0;
      return;
    }
    _idleFor += dt;
    if (_idleFor > 1.2 && !paused) pauseEngine();
  }

  /// Resumes drawing (call on any input or board change).
  void wake() {
    _idleFor = 0;
    if (paused) resumeEngine();
  }

  void _tickAnim(double dt) {
    final anim = _anim;
    if (anim == null) return;

    final phase = anim.update(dt);
    final dir = anim.dir;
    final valid =
        _animFrom >= 0 &&
        _animTo >= 0 &&
        _animFrom < _jars.length &&
        _animTo < _jars.length;
    if (!valid) {
      _anim = null;
      _clearStream();
      return;
    }
    final source = _jars[_animFrom];
    final target = _jars[_animTo];

    source.setAnimatedPosition(anim.position);
    source.setTilt(anim.tiltAngle);

    // Smooth, continuous transfer of powder.
    final moved = anim.layersMoved;
    source.setPourPreview(hidden: moved);
    target.setPourPreview(pendingColor: _pourColorId, pending: moved);

    final stream = _stream;
    if (stream != null) {
      stream.intensity = anim.streamIntensity;
      stream.color = _pourColor;
      stream.mouth = _mouthWorld(source, pouringRight: dir > 0);
      stream.targetMouth = Vector2(target.home.x, target.surfaceWorldY);
    }

    if (!_landed && phase == PourPhase.ret) {
      _landed = true;
      target.bump();
    }

    if (phase == PourPhase.done) {
      _anim = null;
      _landed = false;
      _clearStream();

      source.resetAnimatedPosition();
      source.clearPourPreview();
      target.clearPourPreview();

      controller.applyAnimationComplete(_animFrom, _animTo);

      final snap = controller.snapshot;
      if (snap.board != null) {
        _syncJarData(snap.board!);
      }

      if (snap.phase == GamePhase.won) {
        _celebrateWin();
      } else if (snap.phase == GamePhase.stuck) {
        onStuck();
      }

      _animFrom = -1;
      _animTo = -1;
    }
  }

  /// World position of the jar mouth, accounting for tilt.
  Vector2 _mouthWorld(JarComponent jar, {required bool pouringRight}) {
    final h = jar.jarSize.y;
    // Local mouth (relative to bottom-center anchor).
    final half = jar.mouthHalfWidth;
    final local = Vector2(pouringRight ? half : -half, -h * 0.99);
    // Lift offset of the jar is zero during the pour animation.
    final cosA = math.cos(jar.angle);
    final sinA = math.sin(jar.angle);
    final rotated = Vector2(
      local.x * cosA - local.y * sinA,
      local.x * sinA + local.y * cosA,
    );
    return jar.position + rotated;
  }

  // ── Effects ───────────────────────────────────────────────────────────────

  void _spawnCompleteSparkle(int index, Jar jar) {
    if (jar.isEmpty) return;
    soundService?.playComplete();
    hapticsService?.jarComplete();
    final color = GameConfig.spiceById(jar.layers.first).color;
    final pos = _jars[index].home - Vector2(0, _jars[index].jarSize.y / 2);
    add(GameEffects.jarCompleteSparkle(center: pos, color: color));
  }

  void _spawnRevealSparkle(int index, Jar jar) {
    if (jar.isEmpty) return;
    soundService?.playTap();
    hapticsService?.tap();
    final j = _jars[index];
    final color = GameConfig.spiceById(jar.layers.last).color;
    add(
      GameEffects.jarCompleteSparkle(
        center: j.home - Vector2(0, j.jarSize.y * 0.6),
        color: color,
      ),
    );
  }

  void _spawnUnlockSparkle(int index) {
    soundService?.playComplete();
    hapticsService?.jarComplete();
    final j = _jars[index];
    add(
      GameEffects.jarCompleteSparkle(
        center: j.home - Vector2(0, j.jarSize.y * 0.55),
        color: const Color(0xFFFFD36B),
      ),
    );
  }

  void _celebrateWin() {
    soundService?.playWin();
    hapticsService?.win();
    for (var i = 0; i < _jars.length; i++) {
      _jars[i].hop(0.25 + i * 0.06);
    }
    final colors = GameConfig.spices.map((s) => s.color).toList();
    add(
      GameEffects.winConfetti(
        origin: Vector2(size.x / 2, size.y * 0.62),
        colors: colors,
      ),
    );
    add(GameEffects.confettiRain(width: size.x, colors: colors));
    // Let the celebration play before the dialog appears.
    add(
      TimerComponent(
        period: 1.1,
        removeOnFinish: true,
        onTick: onLevelComplete,
      ),
    );
  }
}

/// Computes jar size, jar positions and shelf rectangles for a board.
class _BoardLayout {
  _BoardLayout(this.jarSize, this.positions, this.shelves);

  final Vector2 jarSize;
  final List<Vector2> positions;
  final List<Rect> shelves;

  static _BoardLayout compute(
    Vector2 gs,
    int count, {
    required double topInset,
    required double bottomInset,
  }) {
    final rows = count <= 5 ? 1 : 2;
    final cols = (count / rows).ceil();

    const hPad = 18.0;
    const aspect = 0.46; // width / height
    final areaTop = topInset;
    final areaBottom = gs.y - bottomInset;
    final areaH = math.max(120.0, areaBottom - areaTop);
    final rowH = areaH / rows;

    final gap = cols >= 6 ? 10.0 : 16.0;
    final maxW = (gs.x - hPad * 2 - (cols - 1) * gap) / cols;
    var w = math.min(maxW, 78.0);
    var h = w / aspect;
    final maxH = rowH * 0.62;
    if (h > maxH) {
      h = maxH;
      w = h * aspect;
    }

    // Stack the rows as a compact block centred in the play area.
    final rowGap = rows > 1 ? h * 0.42 : 0.0;
    final blockH = rows * h + (rows - 1) * rowGap;
    final blockTop = areaTop + (areaH - blockH) / 2 + h * 0.04;

    final positions = <Vector2>[];
    final shelves = <Rect>[];
    for (var row = 0; row < rows; row++) {
      final inRow = row < rows - 1 ? cols : count - (rows - 1) * cols;
      final rowWidth = inRow * w + (inRow - 1) * gap;
      final startX = (gs.x - rowWidth) / 2 + w / 2;
      final bottomY = blockTop + h + row * (h + rowGap);
      for (var col = 0; col < inRow; col++) {
        positions.add(Vector2(startX + col * (w + gap), bottomY));
      }
      final shelfW = math.min(gs.x - 16, rowWidth + w * 0.7);
      shelves.add(
        Rect.fromCenter(
          center: Offset(gs.x / 2, bottomY + 7),
          width: shelfW,
          height: 14,
        ),
      );
    }
    return _BoardLayout(Vector2(w, h), positions, shelves);
  }
}
