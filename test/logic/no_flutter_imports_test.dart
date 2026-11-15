import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('game/logic sources do not import Flutter or Flame', () {
    final dir = Directory('lib/game/logic');
    expect(dir.existsSync(), isTrue);

    final dartFiles = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    );

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(
        source.contains("package:flutter"),
        isFalse,
        reason: '${file.path} must not import Flutter',
      );
      expect(
        source.contains("package:flame"),
        isFalse,
        reason: '${file.path} must not import Flame',
      );
    }
  });
}
