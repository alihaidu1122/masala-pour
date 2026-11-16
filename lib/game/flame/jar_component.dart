import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../logic/jar.dart';

/// A glass spice jar drawn with Canvas.
///
/// Draws the glass body, gold rim, powder layers (with smooth partial fills
/// while pouring), a gold lid that drops on when the jar is completed, and
/// handles the selection lift, drop-in intro, bounce, shake and drag.
class JarComponent extends PositionComponent with TapCallbacks, DragCallbacks {
  /// Creates a jar. [position] is the bottom-centre anchor.
  JarComponent({
    required this.jarIndex,
    required Jar jar,
    required Vector2 position,
    required this.jarSize,
    required this.onTap,
    this.onDragStarted,
    this.onDragMoved,
    this.onDragEnded,
    this.isSelected = false,
    this.colorBlindMode = false,
    this._introDelay = 0,
    this._hiddenCount = 0,
  }) : _jar = jar,
       _home = position.clone(),
       _capT = jar.isComplete ? 1 : 0,
       super(
         position: position.clone(),
         size: jarSize.clone(),
         anchor: Anchor.bottomCenter,
       ) {
    _speckles = _makeSpeckles(jarIndex);
    _shownLock = jar.lockColor;
  }

  /// Index into the board's jars.
  final int jarIndex;

  /// Called with [jarIndex] when the player taps this jar.
  final void Function(int index) onTap;

  /// Called when dragging begins on this jar.
  final void Function(int index, Vector2 startPosition)? onDragStarted;

  /// Called as the dragged jar moves.
  final void Function(int index, Vector2 currentPosition)? onDragMoved;

  /// Called when the dragged jar is released.
  final void Function(int index, Vector2 dropPosition)? onDragEnded;

  /// Logical width × height of the jar.
  final Vector2 jarSize;

  /// Whether the jar is selected (lifted, glowing).
  bool isSelected;

  /// Whether a dragged jar is hovering over this one as a pour target.
  bool isHovered = false;

  /// When true, each layer shows a small accessibility symbol.
  bool colorBlindMode;

  Jar _jar;

  /// Current logical jar data.
  Jar get jar => _jar;

  final Vector2 _home;

  /// The resting home position for this jar.
  Vector2 get home => _home;

  bool _justCompleted = false;

  // ── Lock ─────────────────────────────────────────────────────────────────
  int? _shownLock; // lock colour drawn (kept during the unlock animation)
  double _unlockT = 1;
  bool _justUnlocked = false;

  /// Returns true once after this jar was unlocked (for sound / sparkle).
  bool consumeUnlockFlag() {
    if (!_justUnlocked) return false;
    _justUnlocked = false;
    return true;
  }

  // ── Hidden ("?") layers ──────────────────────────────────────────────────
  static const Color _hiddenColor = Color(0xFF3B2160);
  int _hiddenCount = 0;
  double _revealT = 1;
  int _revealFrom = 0; // layer index range being revealed [from, to)
  int _revealTo = 0;

  /// Number of bottom layers shown as "?". Lowering it plays a reveal.
  int get hiddenCount => _hiddenCount;
  set hiddenCount(int value) {
    if (value < _hiddenCount) {
      _revealFrom = value;
      _revealTo = _hiddenCount;
      _revealT = 0;
      _justRevealed = true;
    }
    _hiddenCount = value;
  }

  bool _justRevealed = false;

  /// Returns true once after layers were revealed (for sound / sparkle).
  bool consumeRevealFlag() {
    if (!_justRevealed) return false;
    _justRevealed = false;
    return true;
  }

  /// Whether the segment whose bottom edge is at [segBottomY] is being
  /// revealed right now.
  bool _isRevealingLayer(double segBottomY) {
    final index = ((_fillBottom - segBottomY) / _layerH).round();
    return index >= _revealFrom && index < _revealTo;
  }

  // ── Pour preview (fractional, in layer units) ─────────────────────────────
  double _hiddenTop = 0;
  int? _pendingColor;
  double _pendingAmount = 0;

  // ── Animation state ───────────────────────────────────────────────────────
  double _lift = 0; // current lift in px (animated toward target)
  double _liftVel = 0;
  double _glow = 0; // 0..1 selection glow

  double _introDelay;
  double _introT = 0; // 0..1 drop-in progress

  double _capT; // 0..1 lid drop progress
  double _popT = 1; // 0..1 completion pop
  double _bumpT = 1; // 0..1 landing squash
  double _hopDelay = -1; // win wave
  double _hopT = 1;

  bool _shaking = false;
  double _shakeElapsed = 0;
  static const double _shakeDuration = 0.38;

  double _time = 0;

  late final List<_Speckle> _speckles;

  // ── Dragging / returning ──────────────────────────────────────────────────
  bool _isDragging = false;

  /// Whether the player is currently dragging this jar.
  bool get isDragging => _isDragging;

  bool _isReturning = false;
  double _returnElapsed = 0;
  static const double _returnDuration = 0.22;
  Vector2 _returnStart = Vector2.zero();
  double _returnStartAngle = 0;
  VoidCallback? _onReturnComplete;

  // ── Geometry helpers (local coordinates, origin top-left) ─────────────────
  double get _w => size.x;
  double get _h => size.y;
  double get _rimH => _h * 0.075;
  double get _neckHalf => _w * 0.36;
  double get _shoulderY => _h * 0.16;
  double get _bottomY => _h * 0.985;
  double get _fillTop => _h * 0.19;
  double get _fillBottom => _h * 0.955;
  double get _layerH => (_fillBottom - _fillTop) / _jar.capacity;

  /// Local x offset of the jar mouth edge (used for the pour stream).
  double get mouthHalfWidth => _neckHalf;

  /// World Y of the current powder surface (for the pour stream to land on).
  double get surfaceWorldY {
    final filled = (_jar.layers.length - _hiddenTop + _pendingAmount).clamp(
      0.0,
      _jar.capacity.toDouble(),
    );
    return _home.y - (_h - _fillBottom) - filled * _layerH;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns true once per completion event; resets the flag.
  bool consumeCompletedFlag() {
    if (!_justCompleted) return false;
    _justCompleted = false;
    return true;
  }

  /// Live pour preview in layer units: hide [hidden] layers from the top,
  /// show [pending] layers of [pendingColor] arriving on top.
  void setPourPreview({double? hidden, int? pendingColor, double? pending}) {
    if (hidden != null) _hiddenTop = hidden;
    if (pendingColor != null) _pendingColor = pendingColor;
    if (pending != null) _pendingAmount = pending;
  }

  /// Clears any in-flight pour preview.
  void clearPourPreview() {
    _hiddenTop = 0;
    _pendingColor = null;
    _pendingAmount = 0;
  }

  /// Illegal-move shake.
  void shake() {
    _shaking = true;
    _shakeElapsed = 0;
  }

  /// Shows the jar immediately (no drop-in animation).
  void skipIntro() {
    _introT = 1;
    _introDelay = 0;
  }

  /// Small squash when powder lands in this jar.
  void bump() => _bumpT = 0;

  /// Win celebration hop after [delay] seconds.
  void hop(double delay) {
    _hopDelay = delay;
    _hopT = 0;
  }

  /// Glides the jar back to its resting home position.
  void returnHome({VoidCallback? onComplete}) {
    if (position == _home && angle == 0) {
      priority = 0;
      onComplete?.call();
      return;
    }
    _isReturning = true;
    _returnElapsed = 0;
    _returnStart = position.clone();
    _returnStartAngle = angle;
    _onReturnComplete = onComplete;
  }

  /// Updates the jar data; marks completion if newly done.
  void updateJar(Jar newJar) {
    if (_jar.isLocked && !newJar.isLocked) {
      _shownLock = _jar.lockColor;
      _unlockT = 0;
      _justUnlocked = true;
    } else if (newJar.isLocked) {
      _shownLock = newJar.lockColor;
      _unlockT = 1;
    }
    if (!_jar.isComplete && newJar.isComplete) {
      _justCompleted = true;
      _capT = 0;
      _popT = 0;
    } else if (!newJar.isComplete) {
      _capT = 0;
    }
    _jar = newJar;
  }

  /// Moves the jar during a pour animation.
  void setAnimatedPosition(Vector2 pos) {
    _isReturning = false;
    priority = 100;
    position.setFrom(pos);
  }

  /// Snaps back to the layout home position.
  void resetAnimatedPosition() {
    _isReturning = false;
    position.setFrom(_home);
    angle = 0;
    priority = 0;
  }

  /// Applies pour tilt in radians.
  void setTilt(double radians) => angle = radians;

  /// Remembers a new layout home (after rebuild).
  void setHome(Vector2 home) {
    _home.setFrom(home);
    if (!_isDragging && !_isReturning) position.setFrom(home);
  }

  /// Whether this jar is mid-animation (used to pause drawing when idle).
  bool get isBusy {
    final targetLift = (isSelected || _isDragging) ? _h * 0.13 : 0.0;
    final glowTarget = (isSelected || _isDragging || isHovered) ? 1.0 : 0.0;
    return _introT < 1 ||
        (_lift - targetLift).abs() > 0.3 ||
        _liftVel.abs() > 1 ||
        (_glow - glowTarget).abs() > 0.02 ||
        (_jar.isComplete && _capT < 1) ||
        _popT < 1 ||
        _bumpT < 1 ||
        _hopT < 1 ||
        _shaking ||
        _isReturning ||
        _isDragging ||
        _revealT < 1 ||
        _unlockT < 1;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Intro drop-in.
    if (_introT < 1) {
      if (_introDelay > 0) {
        _introDelay -= dt;
      } else {
        _introT = (_introT + dt / 0.45).clamp(0.0, 1.0);
      }
    }

    // Spring the lift toward its target (slight overshoot = juicy).
    final targetLift = (isSelected || _isDragging) ? _h * 0.13 : 0.0;
    const stiffness = 520.0;
    const damping = 26.0;
    final accel = (targetLift - _lift) * stiffness - _liftVel * damping;
    _liftVel += accel * dt;
    _lift += _liftVel * dt;

    final glowTarget = (isSelected || _isDragging || isHovered) ? 1.0 : 0.0;
    _glow += (glowTarget - _glow) * min(1.0, dt * 14);

    if (_capT < 1 && _jar.isComplete) _capT = min(1, _capT + dt / 0.42);
    if (_popT < 1) _popT = min(1, _popT + dt / 0.45);
    if (_bumpT < 1) _bumpT = min(1, _bumpT + dt / 0.28);
    if (_revealT < 1) _revealT = min(1, _revealT + dt / 0.45);
    if (_unlockT < 1) {
      _unlockT = min(1, _unlockT + dt / 0.7);
      if (_unlockT >= 1) _shownLock = null;
    }

    if (_hopT < 1) {
      if (_hopDelay > 0) {
        _hopDelay -= dt;
      } else {
        _hopT = min(1, _hopT + dt / 0.5);
      }
    }

    if (_shaking) {
      _shakeElapsed += dt;
      if (_shakeElapsed >= _shakeDuration) {
        _shaking = false;
        _shakeElapsed = 0;
      }
    }

    if (_isReturning) {
      _returnElapsed += dt;
      final t = (_returnElapsed / _returnDuration).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(t);
      position.setFrom(_returnStart + (_home - _returnStart) * e);
      angle = _returnStartAngle * (1 - e);
      if (t >= 1.0) {
        _isReturning = false;
        position.setFrom(_home);
        angle = 0;
        priority = 0;
        final cb = _onReturnComplete;
        _onReturnComplete = null;
        cb?.call();
      }
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final w = _w;
    final h = _h;

    final shakeX = _shaking
        ? 8.0 *
              sin((_shakeElapsed / _shakeDuration) * pi * 6) *
              (1 - _shakeElapsed / _shakeDuration)
        : 0.0;

    // Intro: drop from above with a soft bounce, fading in.
    final introE = Curves.easeOutBack.transform(_introT);
    final introY = -(1 - introE) * h * 0.6;
    final introAlpha = _introT.clamp(0.0, 1.0);

    // Hop for the win wave.
    final hopY = _hopT < 1 && _hopDelay <= 0
        ? -sin(_hopT * pi) * h * 0.18
        : 0.0;

    // Squash & stretch.
    var sx = 1.0;
    var sy = 1.0;
    if (_bumpT < 1) {
      final s = sin(_bumpT * pi) * (1 - _bumpT);
      sx += 0.06 * s;
      sy -= 0.06 * s;
    }
    if (_popT < 1) {
      final s = sin(_popT * pi);
      sx += 0.07 * s;
      sy += 0.07 * s;
    }

    // Shadow stays on the shelf (does not lift).
    if (angle == 0 && position == _home) {
      _drawShadow(canvas, w, h, liftAmount: _lift + (-hopY));
    }

    canvas.save();
    canvas.translate(shakeX, -_lift + introY + hopY);
    canvas.translate(w / 2, h);
    canvas.scale(sx, sy);
    canvas.translate(-w / 2, -h);

    if (introAlpha < 1) {
      canvas.saveLayer(
        Rect.fromLTWH(-w, -h, w * 3, h * 3),
        Paint()..color = Color.fromRGBO(255, 255, 255, introAlpha),
      );
    }

    final body = _bodyPath(w, h);
    _drawGlow(canvas, body);
    _drawGlassBack(canvas, body, w, h);
    _drawPowder(canvas, body, w, h);
    _drawGlassFront(canvas, body, w, h);
    _drawRim(canvas, w, h);
    _drawLid(canvas, w, h);
    _drawLock(canvas, body, w, h);

    if (introAlpha < 1) canvas.restore();
    canvas.restore();
  }

  Path _bodyPath(double w, double h) {
    final cx = w / 2;
    final nl = cx - _neckHalf;
    final nr = cx + _neckHalf;
    final nb = _rimH;
    const bl = 1.5;
    final br = w - 1.5;
    final r = w * 0.26;
    final bottom = _bottomY;
    final sh = _shoulderY;
    return Path()
      ..moveTo(nl, nb)
      ..cubicTo(nl, nb + (sh - nb) * 0.55, bl, nb + (sh - nb) * 0.35, bl, sh)
      ..lineTo(bl, bottom - r)
      ..quadraticBezierTo(bl, bottom, bl + r, bottom)
      ..lineTo(br - r, bottom)
      ..quadraticBezierTo(br, bottom, br, bottom - r)
      ..lineTo(br, sh)
      ..cubicTo(br, nb + (sh - nb) * 0.35, nr, nb + (sh - nb) * 0.55, nr, nb)
      ..close();
  }

  void _drawShadow(
    Canvas canvas,
    double w,
    double h, {
    required double liftAmount,
  }) {
    final fade = (1 - liftAmount / (h * 0.3)).clamp(0.35, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h + 2),
        width: w * 0.95 * fade,
        height: w * 0.22 * fade,
      ),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.45 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawGlow(Canvas canvas, Path body) {
    if (_glow < 0.02) return;
    final c = isHovered ? const Color(0xFF69F0AE) : GameConfig.brandAccent;
    canvas.drawPath(
      body,
      Paint()
        ..color = c.withValues(alpha: 0.75 * _glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  void _drawGlassBack(Canvas canvas, Path body, double w, double h) {
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x33FFFFFF),
            Color(0x10FFFFFF),
            Color(0x08FFFFFF),
            Color(0x26FFFFFF),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  /// Layer segments (color id, height in layer units, hidden), merged when
  /// adjacent visible layers share a colour. Hidden layers stay separate.
  List<(int, double, bool)> _segments() {
    final segs = <(int, double, bool)>[];
    for (var i = 0; i < _jar.layers.length; i++) {
      segs.add((_jar.layers[i], 1.0, i < _hiddenCount));
    }
    var hide = _hiddenTop.clamp(0.0, segs.length.toDouble());
    while (hide > 0 && segs.isNotEmpty) {
      final last = segs.removeLast();
      if (last.$2 > hide) {
        segs.add((last.$1, last.$2 - hide, last.$3));
        hide = 0;
      } else {
        hide -= last.$2;
      }
    }
    if (_pendingColor != null && _pendingAmount > 0) {
      final used = segs.fold<double>(0, (a, s) => a + s.$2);
      final room = _jar.capacity - used;
      final add = min(room, _pendingAmount);
      if (add > 0) segs.add((_pendingColor!, add, false));
    }
    final merged = <(int, double, bool)>[];
    for (final s in segs) {
      if (merged.isNotEmpty &&
          !s.$3 &&
          !merged.last.$3 &&
          merged.last.$1 == s.$1) {
        merged[merged.length - 1] = (s.$1, merged.last.$2 + s.$2, false);
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  void _drawPowder(Canvas canvas, Path body, double w, double h) {
    final segs = _segments();
    if (segs.isEmpty) return;

    canvas.save();
    canvas.clipPath(body);

    final layerH = _layerH;
    // Keep the powder surface level while the jar tilts: counter-rotate the
    // layer stack around the middle of the filled region.
    final filled = segs.fold<double>(0, (a, s) => a + s.$2) * layerH;
    if (angle.abs() > 0.01) {
      final pivot = Offset(w / 2, _fillBottom - filled / 2);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(-angle);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    final wide = angle.abs() > 0.01;
    final left = wide ? -h : 0.0;
    final right = wide ? w + h : w;
    var y = _fillBottom;
    for (var i = 0; i < segs.length; i++) {
      final (colorId, amount, isHidden) = segs[i];
      final spice = GameConfig.spiceById(colorId);
      final segH = amount * layerH;
      final top = y - segH;
      final isTop = i == segs.length - 1;
      // Extend the bottom segment to the jar floor.
      final rectBottom = i == 0 ? (wide ? h * 2 : h) : y + 0.5;
      final rect = Rect.fromLTRB(left, top, right, rectBottom);

      // Hidden layers draw as a dark "?" layer; a just-revealed layer fades
      // from that to its real colour.
      final revealing = !isHidden && _revealT < 1 && _isRevealingLayer(y);
      var base = spice.color;
      if (isHidden) {
        base = _hiddenColor;
      } else if (revealing) {
        base = Color.lerp(
          _hiddenColor,
          spice.color,
          Curves.easeOut.transform(_revealT),
        )!;
      }
      final light = Color.lerp(base, Colors.white, 0.28)!;
      final dark = Color.lerp(base, Colors.black, 0.22)!;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [light, base, base, dark],
            stops: const [0, 0.3, 0.7, 1],
          ).createShader(rect),
      );

      // Powder grain speckles.
      final grainLight = Color.lerp(
        base,
        Colors.white,
        0.5,
      )!.withValues(alpha: 0.55);
      final grainDark = Color.lerp(
        base,
        Colors.black,
        0.35,
      )!.withValues(alpha: 0.45);
      final lp = Paint()..color = grainLight;
      final dp = Paint()..color = grainDark;
      for (final s in _speckles) {
        final sy = _fillTop + s.y * (_fillBottom - _fillTop);
        if (sy < top + 1.5 || sy > rectBottom - 0.5) continue;
        canvas.drawCircle(Offset(s.x * w, sy), s.r * w / 60, s.light ? lp : dp);
      }

      // Surface highlight on each segment's top edge.
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, top + max(1.5, layerH * 0.09)),
        Paint()..color = Colors.white.withValues(alpha: isTop ? 0.35 : 0.14),
      );
      final segRect = Rect.fromLTRB(
        0,
        top,
        w,
        min(rectBottom, top + max(segH, 1)),
      );
      if (isHidden) {
        _paintSymbol(
          canvas,
          '?',
          base,
          segRect,
          color: const Color(0xCCFFE082),
        );
        // Thin divider so stacked hidden layers read as separate.
        canvas.drawRect(
          Rect.fromLTRB(left, top, right, top + 1),
          Paint()..color = const Color(0x55000000),
        );
      } else if (colorBlindMode) {
        _paintSymbol(canvas, spice.symbol, base, segRect);
      }
      if (revealing) {
        final glow = (1 - _revealT).clamp(0.0, 1.0);
        canvas.drawRect(
          segRect,
          Paint()..color = Colors.white.withValues(alpha: 0.45 * glow),
        );
      }
      y = top;
    }
    canvas.restore();
  }

  void _drawGlassFront(Canvas canvas, Path body, double w, double h) {
    // Outline.
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // Glossy left highlight.
    final gloss = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, _shoulderY + h * 0.03, w * 0.11, h * 0.62),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      gloss,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
        ).createShader(gloss.outerRect),
    );
    // Small right rim reflection.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.80, _shoulderY + h * 0.08, w * 0.05, h * 0.22),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = const Color(0x40FFFFFF),
    );
  }

  /// Padlock in the jar's key colour; glass dimmed and chained while locked.
  /// After unlocking, the padlock pops open and flies off.
  void _drawLock(Canvas canvas, Path body, double w, double h) {
    final key = _shownLock;
    if (key == null) return;
    final keyColor = GameConfig.spiceById(key).color;
    final opening = _jar.isLocked ? 0.0 : Curves.easeIn.transform(_unlockT);

    if (_jar.isLocked) {
      // Dim the jar and draw two crossing chains.
      canvas.drawPath(body, Paint()..color = const Color(0x8C120424));
      final chain = Paint()
        ..color = const Color(0xFFCFC6DE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      for (final dir in [1.0, -1.0]) {
        final y0 = h * 0.30;
        final y1 = h * 0.80;
        for (var k = 0; k < 7; k++) {
          final t = k / 6;
          final cx = dir > 0 ? w * (0.04 + 0.92 * t) : w * (0.96 - 0.92 * t);
          final cy = y0 + (y1 - y0) * t;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: w * 0.16,
              height: w * 0.10,
            ),
            chain,
          );
        }
      }
    }

    // Padlock (shackle + body) centred on the jar.
    final r = w * 0.26;
    final c = Offset(w / 2, h * 0.55 - opening * h * 0.6);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(opening * 0.6);
    final s = 1 + 0.35 * sin(opening * pi);
    canvas.scale(s, s);
    final alpha = (1 - opening).clamp(0.0, 1.0);
    final shackle = Paint()
      ..color = Color.fromRGBO(230, 230, 240, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    final lift = opening * r * 0.5;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -r * 0.55 - lift),
        width: r * 1.2,
        height: r * 1.3,
      ),
      pi,
      pi,
      false,
      shackle,
    );
    canvas.drawLine(
      Offset(-r * 0.6, -r * 0.55 - lift),
      Offset(-r * 0.6, -r * 0.15 - lift),
      shackle,
    );
    if (opening < 0.2) {
      canvas.drawLine(
        Offset(r * 0.6, -r * 0.55),
        Offset(r * 0.6, -r * 0.15),
        shackle,
      );
    }
    final lockBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 1.45),
      Radius.circular(r * 0.35),
    );
    canvas.drawRRect(
      lockBody,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(keyColor, Colors.white, 0.35)!.withValues(alpha: alpha),
            keyColor.withValues(alpha: alpha),
            Color.lerp(keyColor, Colors.black, 0.3)!.withValues(alpha: alpha),
          ],
        ).createShader(lockBody.outerRect),
    );
    canvas.drawRRect(
      lockBody,
      Paint()
        ..color = Color.fromRGBO(255, 211, 107, alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Keyhole.
    final hole = Paint()..color = Color.fromRGBO(30, 10, 50, 0.8 * alpha);
    canvas.drawCircle(Offset(0, -r * 0.12), r * 0.18, hole);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, r * 0.18),
        width: r * 0.14,
        height: r * 0.4,
      ),
      hole,
    );
    canvas.restore();
  }

  /// Clear glass lip with an open mouth (the gold lid only appears when the
  /// jar is completed).
  void _drawRim(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(
      w / 2 - _neckHalf - 1.5,
      0,
      (_neckHalf + 1.5) * 2,
      _rimH + 1,
    );
    final rim = RRect.fromRectAndRadius(rect, Radius.circular(_rimH * 0.5));
    // Glass body of the lip.
    canvas.drawRRect(rim, Paint()..color = const Color(0x22FFFFFF));
    // Open mouth: a darker ellipse seen from slightly above.
    final mouth = Rect.fromCenter(
      center: Offset(w / 2, _rimH * 0.42),
      width: _neckHalf * 1.75,
      height: _rimH * 0.62,
    );
    canvas.drawOval(mouth, Paint()..color = const Color(0x40120424));
    canvas.drawOval(
      mouth,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Lip outline and a small highlight.
    canvas.drawRRect(
      rim,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.18, rect.bottom - 1.5),
      Offset(rect.left + rect.width * 0.38, rect.bottom - 1.5),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLid(Canvas canvas, double w, double h) {
    if (!_jar.isComplete || _capT <= 0) return;
    final t = Curves.easeOutBack.transform(_capT.clamp(0.0, 1.0));
    final dropY = -(1 - t) * h * 0.35;
    final alpha = (_capT * 2.5).clamp(0.0, 1.0);
    final lidH = _rimH * 2.1;
    final lid = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        w / 2 - _neckHalf - 4,
        -lidH + _rimH * 0.9 + dropY,
        (_neckHalf + 4) * 2,
        lidH,
      ),
      topLeft: Radius.circular(lidH * 0.45),
      topRight: Radius.circular(lidH * 0.45),
      bottomLeft: Radius.circular(lidH * 0.2),
      bottomRight: Radius.circular(lidH * 0.2),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF6C8).withValues(alpha: alpha),
            const Color(0xFFFFC93C).withValues(alpha: alpha),
            const Color(0xFFB8860B).withValues(alpha: alpha),
          ],
        ).createShader(lid.outerRect),
    );
    // Lid ridges.
    final ridge = Paint()
      ..color = Color.fromRGBO(120, 80, 0, 0.35 * alpha)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = lid.left + lid.width * i / 6;
      canvas.drawLine(
        Offset(x, lid.top + lidH * 0.35),
        Offset(x, lid.bottom - 2),
        ridge,
      );
    }
    // Sparkle glint.
    final glint = (sin(_time * 3 + jarIndex) * 0.5 + 0.5) * alpha;
    _drawStar(canvas, Offset(lid.right - 5, lid.top + 3), 4.5, glint);
  }

  static void _drawStar(Canvas canvas, Offset c, double r, double a) {
    if (a <= 0.05) return;
    final p = Paint()..color = Color.fromRGBO(255, 255, 255, a);
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, p);
  }

  static List<_Speckle> _makeSpeckles(int seed) {
    final rnd = Random(seed * 7919 + 13);
    return List.generate(
      46,
      (_) => _Speckle(
        rnd.nextDouble() * 0.9 + 0.05,
        rnd.nextDouble(),
        0.5 + rnd.nextDouble() * 1.1,
        rnd.nextBool(),
      ),
    );
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!_isDragging && !_isReturning) onTap(jarIndex);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_jar.isEmpty || _jar.isLocked || _isReturning) return;
    _isDragging = true;
    priority = 100;
    onDragStarted?.call(jarIndex, position);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_isDragging) return;
    position.add(event.canvasDelta);
    onDragMoved?.call(jarIndex, position);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_isDragging) return;
    _isDragging = false;
    onDragEnded?.call(jarIndex, position);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (!_isDragging) return;
    _isDragging = false;
    returnHome();
  }

  static void _paintSymbol(
    Canvas canvas,
    String symbol,
    Color base,
    Rect r, {
    Color? color,
  }) {
    final fs = min(r.height * 0.55, r.width * 0.42);
    if (fs < 6) return;
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color:
              color ??
              (base.computeLuminance() > 0.4 ? Colors.black87 : Colors.white),
          fontSize: fs,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        r.left + (r.width - tp.width) / 2,
        r.top + (r.height - tp.height) / 2,
      ),
    );
  }
}

class _Speckle {
  const _Speckle(this.x, this.y, this.r, this.light);
  final double x;
  final double y;
  final double r;
  final bool light;
}
