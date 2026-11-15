import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core sources must never import from game/', () {
    final dir = Directory('lib/core');
    expect(dir.existsSync(), isTrue);

    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    expect(dartFiles, isNotEmpty);

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
          expect(
            trimmed.contains('/game/') ||
                trimmed.contains('package:masala_sort/game/'),
            isFalse,
            reason: '${file.path} has forbidden import: $trimmed',
          );
        }
      }
    }
  });
}
