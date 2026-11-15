import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masala_sort/game/controller/game_controller.dart';
import 'package:masala_sort/game/levels/level.dart';
import 'package:masala_sort/game/levels/level_repository.dart';
import 'package:masala_sort/game/logic/rules.dart';

class _FakeRepo extends LevelRepository {
  _FakeRepo(this.level);
  final Level level;

  @override
  Future<Level> getById(int id) async => level;
}

void main() {
  const rules = Rules();

  late ProviderContainer container;
  late GameController controller;

  final tutorial = Level(
    id: 1,
    capacity: 4,
    jars: [
      [0, 0],
      [0, 0],
      [],
      [],
    ],
    par: 1,
  );

  setUp(() {
    container = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(repository: _FakeRepo(tutorial)),
        ),
      ],
    );
    controller = container.read(gameControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('loadLevel sets playing board', () async {
    await controller.loadLevel(1);
    final state = container.read(gameControllerProvider);
    expect(state.phase, GamePhase.playing);
    expect(state.board, isNotNull);
    expect(state.moveCount, 0);
    expect(rules.isWon(state.board!), isFalse);
  });

  test('tap select then pour wins level 1', () async {
    await controller.loadLevel(1);
    expect(controller.handleTap(0).isSelect, isTrue);
    final pour = controller.handleTap(1);
    expect(pour.isPour, isTrue);
    controller.applyAnimationComplete(pour.from!, pour.to!);
    final state = container.read(gameControllerProvider);
    expect(state.phase, GamePhase.won);
    expect(state.stars, 3);
    expect(state.moveCount, 1);
  });

  test('attemptPour executes direct pour without prior selection', () async {
    await controller.loadLevel(1);
    // Direct attempt from jar 0 to jar 1 (e.g. via drag and drop)
    final pour = controller.attemptPour(0, 1);
    expect(pour.isPour, isTrue);
    expect(pour.from, 0);
    expect(pour.to, 1);
    expect(pour.count, 2);

    controller.applyAnimationComplete(pour.from!, pour.to!);
    final state = container.read(gameControllerProvider);
    expect(state.phase, GamePhase.won);
  });

  test('attemptPour rejects pouring into self', () async {
    await controller.loadLevel(1);
    final result = controller.attemptPour(0, 0);
    expect(result.isDeselect, isTrue);
  });

  test('illegal tap deselects with illegal result', () async {
    await controller.loadLevel(1);
    controller.handleTap(0);
    expect(controller.handleTap(0).isDeselect, isTrue);
  });

  test('undo restores previous board', () async {
    await controller.loadLevel(1);
    controller.handleTap(0);
    final pour = controller.handleTap(1);
    controller.applyAnimationComplete(pour.from!, pour.to!);
    controller.restart();
    controller.handleTap(0);
    final pour2 = controller.handleTap(1);
    controller.applyAnimationComplete(pour2.from!, pour2.to!);
    controller.restart();
    expect(container.read(gameControllerProvider).undosLeft, 3);
  });

  test('hidden layers reveal when they reach the top and stay revealed', () {
    final c = ProviderContainer(
      overrides: [gameControllerProvider.overrideWith(() => GameController())],
    );
    addTearDown(c.dispose);
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.loadLevelData(
      const Level(
        id: 21,
        capacity: 4,
        jars: [
          [1, 1, 0, 0],
          [0, 0, 1, 1],
          [],
        ],
        par: 3,
        hidden: [3, 3, 0],
      ),
    );
    var s = c.read(gameControllerProvider);
    expect(s.hidden, [3, 3, 0]);

    // Pour the two 0s off jar 0 into the empty jar: jar 0's top is now
    // layer index 1, so only one layer stays hidden.
    ctrl.applyAnimationComplete(0, 2);
    s = c.read(gameControllerProvider);
    expect(s.hiddenAt(0), 1);
    expect(s.hiddenAt(1), 3);

    // Undo puts the layers back but does not hide them again.
    ctrl.undo();
    s = c.read(gameControllerProvider);
    expect(s.board!.jars[0].layers, [1, 1, 0, 0]);
    expect(s.hiddenAt(0), 1);

    // Restart restores the level's hidden layers.
    ctrl.restart();
    expect(c.read(gameControllerProvider).hidden, [3, 3, 0]);
  });
}
