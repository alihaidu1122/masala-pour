import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../config/game_config.dart';

/// Purple-magenta backdrop with a soft centre glow, slow floating sparkles,
/// and glass shelves under each row of jars.
class BoardBackground extends PositionComponent {
  /// Creates the background; call [setShelves] after layout.
  BoardBackground() : super(priority: -100);

  final List<Rect> _shelves = [];

  /// Chapter backdrop colours.
  ChapterTheme theme = GameConfig.chapters.first;
  double _time = 0;

  static final List<_Mote> _motes = List.generate(18, (i) {
    final r = Random(i * 101 + 3);
    return _Mote(
      r.nextDouble(),
      r.nextDouble(),
      1.2 + r.nextDouble() * 2.6,
      0.15 + r.nextDouble() * 0.35,
      r.nextDouble() * pi * 2,
    );
  });

  /// Replaces the shelf rectangles (world coordinates).
  void setShelves(List<Rect> shelves) {
    _shelves
      ..clear()
      ..addAll(shelves);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;
    final full = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.top, theme.bottom],
        ).createShader(full),
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 0.75,
          colors: [
            theme.glow.withValues(alpha: 0.5),
            theme.glow.withValues(alpha: 0.0),
          ],
        ).createShader(full),
    );

    // Floating sparkles.
    for (final m in _motes) {
      final y = (m.y - _time * m.speed * 0.04) % 1.0;
      final x = m.x + sin(_time * 0.6 + m.phase) * 0.015;
      final tw = 0.35 + 0.65 * (sin(_time * 1.8 + m.phase) * 0.5 + 0.5);
      canvas.drawCircle(
        Offset(x * w, y * h),
        m.r,
        Paint()
          ..color = Color.fromRGBO(255, 225, 160, 0.22 * tw)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    for (final s in _shelves) {
      _drawShelf(canvas, s);
    }
  }

  void _drawShelf(Canvas canvas, Rect s) {
    // Drop shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        s.shift(const Offset(0, 6)),
        const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final rr = RRect.fromRectAndRadius(s, const Radius.circular(10));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8E4FD6), Color(0xFF5A1E9C), Color(0xFF3A0F6E)],
        ).createShader(s),
    );
    // Gold top edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.left + 2, s.top, s.width - 4, 3),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xCCFFD36B),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

class _Mote {
  const _Mote(this.x, this.y, this.r, this.speed, this.phase);
  final double x;
  final double y;
  final double r;
  final double speed;
  final double phase;
}
