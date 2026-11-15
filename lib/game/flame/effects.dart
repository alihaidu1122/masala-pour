import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Particle effects: jar-completion burst, win confetti burst and rain.
abstract final class GameEffects {
  static final _rand = Random();

  /// A ring of glowing sparks and stars around [center] in [color].
  static ParticleSystemComponent jarCompleteSparkle({
    required Vector2 center,
    required Color color,
  }) {
    const count = 18;
    const lifespan = 0.7;
    final light = Color.lerp(color, Colors.white, 0.45)!;

    final particle = Particle.generate(
      count: count,
      lifespan: lifespan,
      generator: (i) {
        final angle = (i / count) * pi * 2 + _rand.nextDouble() * 0.3;
        final speed = 70 + _rand.nextDouble() * 70;
        final vel = Vector2(cos(angle), sin(angle)) * speed;
        final isStar = i.isEven;
        final c = isStar ? const Color(0xFFFFE082) : light;
        final r = isStar
            ? 4.0 + _rand.nextDouble() * 2
            : 2.5 + _rand.nextDouble() * 2.5;
        return AcceleratedParticle(
          acceleration: Vector2(0, 90) - vel * 0.6,
          speed: vel,
          lifespan: lifespan,
          child: ScalingParticle(
            lifespan: lifespan,
            to: 0,
            child: ComputedParticle(
              lifespan: lifespan,
              renderer: (canvas, _) => isStar
                  ? _star(canvas, r, c)
                  : canvas.drawCircle(Offset.zero, r, Paint()..color = c),
            ),
          ),
        );
      },
    );

    return ParticleSystemComponent(
      particle: particle,
      position: center.clone(),
      priority: 300,
    );
  }

  /// A confetti explosion centred on [origin] using [colors].
  static ParticleSystemComponent winConfetti({
    required Vector2 origin,
    required List<Color> colors,
  }) {
    const count = 90;
    const lifespan = 1.8;
    return ParticleSystemComponent(
      priority: 300,
      position: origin.clone(),
      particle: Particle.generate(
        count: count,
        lifespan: lifespan,
        generator: (i) {
          final angle = -pi / 2 + (_rand.nextDouble() - 0.5) * pi * 1.4;
          final speed = 220 + _rand.nextDouble() * 320;
          return _confettiPiece(
            Vector2(cos(angle), sin(angle)) * speed,
            colors[i % colors.length],
            lifespan,
            gravity: 520,
          );
        },
      ),
    );
  }

  /// Confetti falling from the top edge across [width].
  static ParticleSystemComponent confettiRain({
    required double width,
    required List<Color> colors,
  }) {
    const count = 70;
    const lifespan = 2.6;
    return ParticleSystemComponent(
      priority: 300,
      position: Vector2(0, -20),
      particle: Particle.generate(
        count: count,
        lifespan: lifespan,
        generator: (i) {
          final start = Vector2(
            _rand.nextDouble() * width,
            -_rand.nextDouble() * 120,
          );
          return MovingParticle(
            from: start,
            to:
                start +
                Vector2(
                  (_rand.nextDouble() - 0.5) * 140,
                  900 + _rand.nextDouble() * 200,
                ),
            lifespan: lifespan,
            child: _confettiPiece(
              Vector2.zero(),
              colors[i % colors.length],
              lifespan,
            ),
          );
        },
      ),
    );
  }

  static Particle _confettiPiece(
    Vector2 speed,
    Color color,
    double lifespan, {
    double gravity = 0,
  }) {
    final w = 6.0 + _rand.nextDouble() * 6;
    final h = w * (0.4 + _rand.nextDouble() * 0.3);
    final spin = (_rand.nextDouble() - 0.5) * 16;
    final flip = 6 + _rand.nextDouble() * 8;
    final paint = Paint()..color = color;
    final shade = Paint()..color = Color.lerp(color, Colors.black, 0.25)!;
    return AcceleratedParticle(
      acceleration: Vector2(0, gravity),
      speed: speed,
      lifespan: lifespan,
      child: ComputedParticle(
        lifespan: lifespan,
        renderer: (canvas, particle) {
          final t = particle.progress * lifespan;
          final fade = particle.progress > 0.8
              ? (1 - particle.progress) / 0.2
              : 1.0;
          canvas.save();
          canvas.rotate(t * spin);
          final sy = cos(t * flip);
          canvas.scale(1, sy.abs() < 0.1 ? 0.1 : sy.abs());
          final p = sy > 0 ? paint : shade;
          p.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: w, height: h),
              const Radius.circular(1.5),
            ),
            p,
          );
          canvas.restore();
        },
      ),
    );
  }

  static void _star(Canvas canvas, double r, Color c) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final p = Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = c);
  }
}
