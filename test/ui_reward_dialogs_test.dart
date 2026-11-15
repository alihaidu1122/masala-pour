import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/ui/widgets/dialogs.dart';

void main() {
  testWidgets('win popup shows earned coins and a chapter chest', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => GameDialogs.showWin(
                  context,
                  level: 25,
                  stars: 3,
                  moves: 25,
                  par: 25,
                  coins: 60,
                  chestCoins: 200,
                  chestLabel: 'Saffron Street chest!',
                  onNext: () {},
                  onReplay: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('+60'), findsOneWidget);
    expect(find.text('+200'), findsOneWidget);
    expect(find.text('Saffron Street chest!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('helper offer disables coins when the player cannot afford it', (
    tester,
  ) async {
    HelperChoice? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                picked = await GameDialogs.showHelperOffer(
                  context,
                  title: '+1 Jar',
                  description: 'Add an empty jar.',
                  asset: 'assets/images/btn_add_jar.png',
                  price: 120,
                  coins: 50,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Need 70 more'), findsOneWidget);
    await tester.tap(find.text('Use 120'));
    await tester.pumpAndSettle();
    expect(picked, isNull); // disabled
    await tester.tap(find.text('Watch ad'));
    await tester.pumpAndSettle();
    expect(picked, HelperChoice.ad);
  });
}
