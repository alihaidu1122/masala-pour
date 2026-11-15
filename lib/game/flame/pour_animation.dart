import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

/// Phases of the pour animation state machine.
enum PourPhase {
  /// Source jar lifts upward.
  lift,

  /// Source jar arcs over to sit beside the target mouth.
  move,

  /// Jar tilts and powder streams into the target.
  tilt,

  /// Jar untilts and returns home.
  ret,

  /// Sequence complete.
  done,
}

/// Lift → arc over to the target → tilt + pour → return home.
///
/// The hover point is computed from the jar size and tilt angle so the
/// tilted jar's mouth sits right above the target opening. If that would push
/// the jar off-screen, it pours from the other side instead.
class PourAnimation {
  /// Creates an animation.
  PourAnimation({
    required this.fromIndex,
    required this.toIndex,
    required this.fromHome,
    required this.toHome,
    required this.jarWidth,
    required this.jarHeight,
    required this.mouthHalfWidth,
    required this.layerCount,
    required this.speedFactor,
    required this.screenWidth,
    Vector2? startPos,
  }) : fromStart = startPos?.clone() ?? fromHome.clone(),
       isDirectDrop = startPos != null {
    final natural = toHome.x >= fromHome.x ? 1.0 : -1.0;
    var d = natural;
    final hover = _hoverFor(natural);
    final half = jarWidth * 0.6;
    if (hover.x - half < 0 || hover.x + half > screenWidth) {
      final flipped = _hoverFor(-natural);
      if (flipped.x - half >= 0 && flipped.x + half <= screenWidth) {
        d = -natural;
      }
    }
    dir = d;
    pourHover = _hoverFor(d);
  }

  final int fromIndex;
  final int toIndex;
  final Vector2 fromHome;
  final Vector2 toHome;
  final double jarWidth;
  final double jarHeight;
  final double mouthHalfWidth;
  final int layerCount;
  final double speedFactor;
  final double screenWidth;
  final Vector2 fromStart;
  final bool isDirectDrop;

  /// +1 = pours to the right (tilts clockwise), -1 = pours to the left.
  late final double dir;

  /// Where the jar's bottom-centre anchor sits while pouring.
  late final Vector2 pourHover;

  /// Maximum tilt while pouring (radians).
  static const double maxTilt = 68 * pi / 180;

  // Durations at speedFactor 1.0 (seconds).
  static const double _dLift = 0.10;
  static const double _dMoveTap = 0.26;
  static const double _dMoveDrop = 0.16;
  static const double _dTiltIn = 0.14;
  static const double _dPourBase = 0.16;
  static const double _dPourPerLayer = 0.11;
  static const double _dRet = 0.26;

  double get _dMove => isDirectDrop ? _dMoveDrop : _dMoveTap;
  double get _dTilt => _dTiltIn + _dPourBase + layerCount * _dPourPerLayer;

  double get _t1 => isDirectDrop ? 0 : (_dLift / speedFactor);
  double get _t2 => _t1 + _dMove / speedFactor;
  double get _t3 => _t2 + _dTilt / speedFactor;
  double get _tEnd => _t3 + _dRet / speedFactor;

  double _elapsed = 0;

  Vector2 get _liftedHome => Vector2(fromHome.x, fromHome.y - jarHeight * 0.13);

  Vector2 _hoverFor(double d) {
    // Mouth corner relative to the bottom-centre anchor after tilting by
    // d * maxTilt (Flame: positive angle = clockwise).
    final a = d * maxTilt;
    final lx = d * mouthHalfWidth;
    final ly = -jarHeight;
    final mx = lx * cos(a) - ly * sin(a);
    final my = lx * sin(a) + ly * cos(a);
    // Aim slightly inside the near edge of the target's opening.
    final aim = Vector2(
      toHome.x - d * jarWidth * 0.12,
      toHome.y - jarHeight * 1.10,
    );
    return Vector2(aim.x - mx, aim.y - my);
  }

  /// Current phase.
  PourPhase get phase {
    if (_elapsed >= _tEnd) return PourPhase.done;
    if (_elapsed < _t1) return PourPhase.lift;
    if (_elapsed < _t2) return PourPhase.move;
    if (_elapsed < _t3) return PourPhase.tilt;
    return PourPhase.ret;
  }

  double get _tiltLocal =>
      ((_elapsed - _t2) / (_dTilt / speedFactor)).clamp(0.0, 1.0);

  /// 0–1 share of the poured layers that have left the source.
  double get pourProgress {
    final p = phase;
    if (p == PourPhase.done || p == PourPhase.ret) return 1;
    if (p != PourPhase.tilt) return 0;
    final startFrac = _dTiltIn / _dTilt;
    final x = ((_tiltLocal - startFrac) / (1 - startFrac)).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(x);
  }

  /// Fractional number of layers that have visually moved.
  double get layersMoved => pourProgress * layerCount;

  /// Stream strength 0–1.
  double get streamIntensity {
    if (phase != PourPhase.tilt) return 0;
    final startFrac = _dTiltIn / _dTilt;
    final x = ((_tiltLocal - startFrac) / (1 - startFrac));
    if (x <= 0 || x >= 1) return 0;
    return sin(x * pi).clamp(0.0, 1.0) * 0.6 + 0.4;
  }

  /// Anchor position of the source jar.
  Vector2 get position {
    final hover = pourHover;
    switch (phase) {
      case PourPhase.lift:
        final t = Curves.easeOut.transform(_norm(_elapsed, 0, _t1));
        return fromHome + (_liftedHome - fromHome) * t;
      case PourPhase.move:
        final t = Curves.easeInOutCubic.transform(_norm(_elapsed, _t1, _t2));
        final start = isDirectDrop ? fromStart : _liftedHome;
        final mid = Vector2(
          (start.x + hover.x) / 2,
          min(start.y, hover.y) - jarHeight * 0.35,
        );
        return _quadBezier(start, mid, hover, t);
      case PourPhase.tilt:
        // Tiny bob while pouring.
        return hover + Vector2(0, sin(_tiltLocal * pi * 2) * 1.5);
      case PourPhase.ret:
        final t = Curves.easeInOutCubic.transform(_norm(_elapsed, _t3, _tEnd));
        final mid = Vector2(
          (hover.x + fromHome.x) / 2,
          min(hover.y, fromHome.y) - jarHeight * 0.25,
        );
        return _quadBezier(hover, mid, fromHome, t);
      case PourPhase.done:
        return fromHome.clone();
    }
  }

  /// Signed tilt angle (already multiplied by [dir]).
  double get tiltAngle {
    switch (phase) {
      case PourPhase.move:
        final t = _norm(_elapsed, _t1, _t2);
        return dir * maxTilt * 0.25 * Curves.easeIn.transform(t);
      case PourPhase.tilt:
        final startFrac = _dTiltIn / _dTilt;
        final x = _tiltLocal;
        if (x < startFrac) {
          final k = Curves.easeOutBack.transform(x / startFrac);
          return dir * maxTilt * (0.25 + 0.75 * k);
        }
        // Tip a little further as it empties.
        return dir * maxTilt * (1 + 0.06 * pourProgress);
      case PourPhase.ret:
        final t = Curves.easeOutCubic.transform(_norm(_elapsed, _t3, _tEnd));
        return dir * maxTilt * 1.06 * (1 - t);
      default:
        return 0;
    }
  }

  /// Advances time; returns the new phase.
  PourPhase update(double dt) {
    _elapsed += dt;
    return phase;
  }

  static double _norm(double t, double from, double to) {
    if (to <= from) return 1.0;
    return ((t - from) / (to - from)).clamp(0.0, 1.0);
  }

  static Vector2 _quadBezier(Vector2 a, Vector2 b, Vector2 c, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + c * (t * t);
  }
}
