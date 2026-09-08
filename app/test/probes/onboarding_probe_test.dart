import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/core/director.dart';

import '../app/harness.dart';
import 'support.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  test('the first classic game is restricted and hints are on', () async {
    final app = ProbeApp(now: now);
    await app.start();
    expect(app.controller.showFirstGameHints, isTrue);
    await app.controller.startClassic();
    final game = app.controller.currentGame!;
    expect(game.restricted, isTrue);
    expect(game.set.map((p) => p!.family),
        everyElement(isIn(Director.restrictedFamilies)));
  });

  test('the restriction is spent by a finished game, not by any finished game',
      () async {
    final app = ProbeApp(now: now);
    await app.start();
    await app.controller.startDaily();
    await playToGameOver(app.controller);
    await app.controller.finishGame();
    await app.controller.goHome();

    await app.controller.startClassic();
    expect(app.controller.currentGame!.restricted, isTrue,
        reason: 'the player has never played a classic game');
  });

  test('a second classic game is not restricted', () async {
    final app = ProbeApp(now: now);
    await app.start();
    await app.controller.startClassic();
    await playToGameOver(app.controller);
    await app.controller.finishGame();
    await app.controller.playAgain();
    expect(app.controller.currentGame!.restricted, isFalse);
    expect(app.controller.showFirstGameHints, isFalse);
  });
}
