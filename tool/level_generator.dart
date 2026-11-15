// Generates assets/levels/levels_001_300.json (deterministic).
// Run: dart run tool/level_generator.dart
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:masala_sort/game/levels/level.dart';
import 'package:masala_sort/game/levels/level_generator_core.dart';

void main(List<String> args) {
  final stopwatch = Stopwatch()..start();
  final generator = LevelGeneratorCore();

  stdout.writeln('Generating 300 Masala Sort levels…');

  final rates = <int, double>{};
  final levels = generator.generateAll(
    onLevel: (id, level, winRate) {
      rates[id] = winRate;
      final tags = [
        if (level.difficulty.name != 'normal') level.difficulty.name,
        if (level.hasHidden) 'hidden',
        if (level.capacity == 5) 'tall',
        if (level.intro != null) 'INTRO:${level.intro!.name}',
      ].join(' ');
      stdout.writeln(
        '  level $id  colors=${_approxColors(level)}  cap=${level.capacity}  '
        'par=${level.par}  win=${(winRate * 100).round()}%  $tags',
      );
    },
  );

  if (levels.length != 300) {
    stderr.writeln('Expected 300 levels, got ${levels.length}');
    exitCode = 1;
    return;
  }

  final payload = <String, dynamic>{
    'version': 2,
    'count': levels.length,
    'baseSeed': generator.baseSeed,
    'levels': [for (final level in levels) level.toJson()],
  };

  final out = File('assets/levels/levels_001_300.json');
  out.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  out.writeAsStringSync('${encoder.convert(payload)}\n');

  stopwatch.stop();
  stdout.writeln(
    'Wrote ${out.path} (${levels.length} levels) in '
    '${stopwatch.elapsedMilliseconds}ms',
  );

  _printBandStats(levels);
}

int _approxColors(Level level) {
  final colors = <int>{};
  for (final jar in level.jars) {
    colors.addAll(jar);
  }
  return colors.length;
}

void _printBandStats(List<Level> levels) {
  stdout.writeln('\nPar stats by band:');
  for (final band in DifficultyBands.all) {
    final slice = [
      for (final level in levels)
        if (band.contains(level.id)) level.par,
    ];
    if (slice.isEmpty) continue;
    final sum = slice.reduce((a, b) => a + b);
    final min = slice.reduce((a, b) => a < b ? a : b);
    final max = slice.reduce((a, b) => a > b ? a : b);
    final avg = sum / slice.length;
    stdout.writeln(
      '  ${band.name}: min=$min  avg=${avg.toStringAsFixed(1)}  max=$max  '
      '(n=${slice.length})',
    );
  }
}
