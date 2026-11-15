import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/app.dart';
import 'package:masala_sort/config/game_config.dart';
import 'package:masala_sort/core/storage/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _initSave() async {
  SharedPreferences.setMockInitialValues({});
  await SaveService.init();
}

void main() {
  testWidgets('Splash shows brand then navigates to Home', (tester) async {
    await _initSave();
    await tester.pumpWidget(const ProviderScope(child: MasalaSortApp()));

    expect(find.bySemanticsLabel(GameConfig.appName), findsOneWidget);

    await tester.pump(GameConfig.splashDuration);
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Level Select'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Home can open Level Select and Settings', (tester) async {
    await _initSave();
    await tester.pumpWidget(const ProviderScope(child: MasalaSortApp()));
    await tester.pump(GameConfig.splashDuration);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Level Select'));
    await tester.pumpAndSettle();
    expect(find.text('Select Level'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Color-blind mode'), findsOneWidget);
    expect(find.text('Fast animations'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
  });

  testWidgets('Settings screen toggles persist to SaveService', (tester) async {
    await _initSave();
    await tester.pumpWidget(const ProviderScope(child: MasalaSortApp()));
    await tester.pump(GameConfig.splashDuration);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Toggle color-blind mode
    final colorBlindSwitch = find.widgetWithText(
      SwitchListTile,
      'Color-blind mode',
    );
    expect(colorBlindSwitch, findsOneWidget);
    await tester.tap(colorBlindSwitch);
    await tester.pumpAndSettle();

    expect(SaveService.instance.loadSettings().colorBlindMode, isTrue);

    // Scroll down to reveal Privacy policy and options
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Tap Privacy policy dialog
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Privacy options opens UMP form when required (no local OK dialog).
    expect(find.text('Privacy options'), findsOneWidget);
  });

  test('GameConfig exposes 10 distinct spices', () {
    expect(GameConfig.spices, hasLength(10));
    final ids = GameConfig.spices.map((s) => s.id).toSet();
    final symbols = GameConfig.spices.map((s) => s.symbol).toSet();
    final colors = GameConfig.spices.map((s) => s.color.toARGB32()).toSet();
    expect(ids, hasLength(10));
    expect(symbols, hasLength(10));
    expect(colors, hasLength(10));
  });
}
