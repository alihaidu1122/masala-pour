import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// A falling stream of spice powder from the pouring jar's mouth down to the
/// powder surface in the target jar, with flowing grains and a puff of dust
/// where it lands.
class PourStreamComponent extends PositionComponent {
  /// Creates a stream renderer.
  PourStreamComponent({required this.color}) : super(priority: 200);

  /// Spice colour of the powder.
  Color color;

  /// Mouth of the tilted source jar (world).
  Vector2 mouth = Vector2.zero();

  /// Where the powder lands in the target jar (world).
  Vector2 targetMouth = Vector2.zero();

  /// 0 = hidden, 1 = full stream.
  double intensity = 0;

  double _time = 0;
  static const int _grains = 26;
  final List<double> _seeds = List.generate(
    _grains,
    (i) => Random(i * 31 + 7).nextDouble(),
  );

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (intensity <= 0.02) return;

    final a = Offset(mouth.x, mouth.y);
    final c = Offset(targetMouth.x, targetMouth.y);
    // Powder leaves the lip sideways, then falls: control point below the lip.
    final b = Offset(a.dx + (c.dx - a.dx) * 0.15, a.dy + (c.dy - a.dy) * 0.25);

    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(b.dx, b.dy, c.dx, c.dy);

    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!;

    // Soft glow.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.30 * intensity)
        ..strokeWidth = 12 * intensity + 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Core stream.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.95)
        ..strokeWidth = 3 + 4.5 * intensity
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Highlight down the centre.
    canvas.drawPath(
      path,
      Paint()
        ..color = light.withValues(alpha: 0.7)
        ..strokeWidth = 1.2 + intensity
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Flowing grains around the stream.
    final grain = Paint();
    for (var i = 0; i < _grains; i++) {
      final s = _seeds[i];
      final t = ((i / _grains) + _time * 1.6) % 1.0;
      final p = _pointOnQuad(a, b, c, t);
      final spread = (s - 0.5) * (4 + 7 * t) * intensity;
      grain.color = (i.isEven ? light : color).withValues(
        alpha: 0.9 * intensity,
      );
      canvas.drawCircle(Offset(p.dx + spread, p.dy), 1.1 + s * 1.4, grain);
    }

    // Dust puff where the powder lands.
    for (var i = 0; i < 6; i++) {
      final ang = pi + (i / 5) * pi + sin(_time * 9 + i) * 0.2;
      final r = 5 + 6 * ((_time * 2.5 + i * 0.17) % 1.0);
      canvas.drawCircle(
        Offset(c.dx + cos(ang) * r, c.dy + sin(ang) * r * 0.5),
        1.6,
        Paint()..color = light.withValues(alpha: 0.6 * intensity),
      );
    }
  }

  static Offset _pointOnQuad(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      a.dx * u * u + b.dx * 2 * u * t + c.dx * t * t,
      a.dy * u * u + b.dy * 2 * u * t + c.dy * t * t,
    );
  }
}
