import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/levels/daily_challenge.dart';
import 'package:masala_sort/game/logic/rules.dart';
import 'package:masala_sort/game/solver/solver.dart';

void main() {
  test('same date yields same level', () {
    final day = DateTime(2026, 11, 14);
    final a = DailyChallenge.generate(date: day);
    final b = DailyChallenge.generate(date: day);
    expect(a.toJson(), b.toJson());
  });

  test('different dates differ', () {
    final a = DailyChallenge.generate(date: DateTime(2026, 1, 1));
    final b = DailyChallenge.generate(date: DateTime(2026, 1, 2));
    expect(a.jars, isNot(equals(b.jars)));
  });

  test('daily level is solvable with par > 0', () {
    const rules = Rules();
    const solver = Solver(nodeLimit: 200000);
    final level = DailyChallenge.generate(date: DateTime(2026, 6, 1));
    expect(level.par, greaterThan(0));
    expect(rules.isWon(level.toBoardState()), isFalse);
    final result = solver.solveFast(level.toBoardState());
    expect(result.solved, isTrue);
  });
}
