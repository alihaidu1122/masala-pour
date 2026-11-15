import 'level.dart';
import 'level_generator_core.dart';

/// Builds the special daily level from a calendar date seed.
class DailyChallenge {
  DailyChallenge._();

  /// YYYY-MM-DD key for [date] in local time.
  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Deterministic seed from [date].
  static int seedFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.year * 10000 + d.month * 100 + d.day;
  }

  /// Generates today's (or [date]'s) challenge level.
  ///
  /// Uses the same generator core as campaign levels for reproducibility.
  static Level generate({DateTime? date}) {
    final day = date ?? DateTime.now();
    final seed = seedFor(day);
    // Map day-of-year onto normal (non-spike) mid-game level ids 31–89.
    final dayOfYear = day.difference(DateTime(day.year)).inDays + 1;
    var pseudoId = 31 + (dayOfYear % 59);
    if (pseudoId % 5 == 0) pseudoId += 2;

    // Few candidates and no play-throughs: runs on the UI thread at launch.
    final generator = LevelGeneratorCore(
      baseSeed: seed,
      candidates: 2,
      playouts: 0,
    );
    final level = generator.generateOne(pseudoId);
    return level.copyWith(id: 900000 + seed); // synthetic id space for daily
  }
}
