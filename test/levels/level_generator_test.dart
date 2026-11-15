import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/levels/level_generator_core.dart';
import 'package:masala_sort/game/levels/level.dart';
import 'package:masala_sort/game/logic/rules.dart';

void main() {
  const rules = Rules();

  test('generateOne is deterministic for the same id', () {
    final a = LevelGeneratorCore(candidates: 3, playouts: 10).generateOne(12);
    final b = LevelGeneratorCore(candidates: 3, playouts: 10).generateOne(12);
    expect(a.toJson(), b.toJson());
  });

  test('tutorials are not already won and have par > 0', () {
    final tutorials = LevelGeneratorCore().tutorials();
    expect(tutorials, hasLength(5));
    for (final level in tutorials) {
      expect(level.par, greaterThan(0));
      expect(rules.isWon(level.toBoardState()), isFalse);
    }
  });

  test('generated mid level has a mixed jar', () {
    final level = LevelGeneratorCore(
      candidates: 2,
      playouts: 5,
    ).generateOne(40);
    final board = level.toBoardState();
    final hasMixed = board.jars.any((jar) {
      if (jar.layers.length < 2) return false;
      return jar.layers.any((c) => c != jar.layers.first);
    });
    expect(hasMixed, isTrue);
  });

  test('LevelGenSpec follows a sawtooth difficulty curve', () {
    expect(LevelGenSpec.forLevel(12).colorCount, 4);
    expect(LevelGenSpec.forLevel(200).colorCount, inInclusiveRange(9, 10));
    // Spikes every 5th / 25th level, breather right after.
    expect(LevelGenSpec.forLevel(15).difficulty, LevelDifficulty.hard);
    expect(LevelGenSpec.forLevel(50).difficulty, LevelDifficulty.superHard);
    expect(LevelGenSpec.forLevel(16).pick, BoardPick.easiest);
    expect(
      LevelGenSpec.forLevel(15).colorCount,
      greaterThan(LevelGenSpec.forLevel(16).colorCount),
    );
    // Mechanics introduced on fixed levels.
    expect(LevelGenSpec.forLevel(21).intro, LevelIntro.mystery);
    expect(LevelGenSpec.forLevel(46).intro, LevelIntro.tallJars);
    expect(LevelGenSpec.forLevel(46).capacity, 5);
    expect(LevelGenSpec.forLevel(19).hidden, HiddenMode.none);
    expect(LevelGenSpec.forLevel(33).intro, LevelIntro.lockedJars);
    expect(LevelGenSpec.forLevel(33).locks, 1);
    expect(LevelGenSpec.forLevel(30).locks, 0);
  });

  test('generated boards start with every colour jar full', () {
    final level = LevelGeneratorCore(
      candidates: 2,
      playouts: 5,
    ).generateOne(30);
    for (final jar in level.jars.where((j) => j.isNotEmpty)) {
      expect(jar.length, level.capacity);
    }
    expect(level.jars.where((j) => j.isEmpty).length, 2);
  });
}
