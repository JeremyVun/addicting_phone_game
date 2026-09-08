import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/meta/meta.dart';
import 'package:settle/services/storage.dart';

import '../app/harness.dart';
import 'support.dart';

LastGameResult resultFor(String gameId) => LastGameResult(
  gameId: gameId,
  mode: GameMode.classic,
  score: 2000,
  baseCoins: 40,
  bonusCoins: 25,
  xp: 200,
  streakAfter: 0,
  elapsedMs: 60000,
);

(int, int, int) firstLegal(AppController controller) {
  final state = controller.state;
  for (var slot = 0; slot < 3; slot++) {
    final piece = state.set[slot];
    if (piece == null) continue;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        if (state.board.canPlace(piece, row, col)) return (slot, row, col);
      }
    }
  }
  throw StateError('no legal move');
}

void main() {
  final now = DateTime(2026, 9, 8, 12);

  test('interleaved mutations commit exactly what sequential ones do', () async {
    final seedApp = ProbeApp(now: now);
    await seedApp.start();
    await seedApp.controller.startClassic();
    await seedApp.controller.mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(coins: 1000, createdAtMs: 0),
        lastResult: resultFor(d.savedGame!.id),
      ),
    );
    final envelope = (seedApp.storage as MemoryStorage).writes.last;

    Future<String> run({required bool awaited}) async {
      final app = ProbeApp(
        storage: MemoryStorage(envelope),
        ads: OneShotAds(reloads: true),
        now: now,
      );
      await app.start();
      final move = firstLegal(app.controller);
      final actions = <Future<void>>[];
      app.controller.place(move.$1, move.$2, move.$3);
      if (awaited) await app.controller.idle;
      actions.add(app.controller.applyPurchase(Products.coinsSmall, 'tok-1'));
      if (awaited) await actions.last;
      actions.add(app.controller.doubleCoins());
      if (awaited) await actions.last;
      actions.add(app.controller.claimDailyReward());
      if (awaited) await actions.last;
      actions.add(app.controller.buyStreakFreeze());
      await Future.wait(actions);
      await app.controller.idle;
      return jsonEncode(app.controller.data.toJson());
    }

    final interleaved = await run(awaited: false);
    final sequential = await run(awaited: true);
    expect(interleaved, sequential);
  });

  test('finishGame stays idempotent across a relaunch', () async {
    final storage = MemoryStorage();
    final first = ProbeApp(storage: storage, now: now);
    await first.start();
    await first.controller.startClassic();
    await playToGameOver(first.controller);
    final result = await first.controller.finishGame();
    final profile = first.controller.profile;

    final second = ProbeApp(storage: MemoryStorage(storage.writes.last), now: now);
    await second.start();
    expect(second.controller.lastResult, result);
    final again = await second.controller.finishGame();

    expect(again, result);
    expect(second.controller.profile.coins, profile.coins);
    expect(second.controller.profile.gamesCompleted, profile.gamesCompleted);
    expect(second.controller.profile.lastFinishedGameId, profile.lastFinishedGameId);
  });

  test('a pending result reopens once and is cleared exactly once', () async {
    final storage = MemoryStorage();
    final app = ProbeApp(storage: storage, now: now);
    await app.start();
    await app.controller.startClassic();
    await playToGameOver(app.controller);
    await app.controller.endGame();

    final relaunch = ProbeApp(storage: MemoryStorage(storage.writes.last), now: now);
    await relaunch.start();
    relaunch.controller.resumeFromLaunch();
    expect(relaunch.navigator.calls, ['showGameOver']);

    await relaunch.controller.goHome();
    expect(relaunch.controller.lastResult, isNull);

    final third = ProbeApp(
      storage: MemoryStorage((relaunch.storage as MemoryStorage).writes.last),
      now: now,
    );
    await third.start();
    third.controller.resumeFromLaunch();
    expect(third.navigator.calls, isEmpty,
        reason: 'the result was consumed by goHome');
  });

  test('a write that fails leaves the envelope and the controller agreeing',
      () async {
    final inner = MemoryStorage();
    final storage = ThrowingStorage(inner);
    final app = ProbeApp(storage: storage, now: now);
    await app.start();
    await app.controller.startClassic();
    await playToGameOver(app.controller);
    await app.controller.endGame();
    await app.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 500)),
    );

    storage.failWhen = (d) => d.profile.coins == 9999;
    await expectLater(
      app.controller.mutate(
        (d) => d.copyWith(profile: d.profile.copyWith(coins: 9999)),
      ),
      throwsA(isA<StateError>()),
    );

    final onDisk = await inner.load();
    expect(app.controller.profile.coins, onDisk!.profile.coins,
        reason: 'an unwritten mutation must not be live in memory');
  });

  test('a crash during the second daily attempt leaves one consistent envelope',
      () async {
    final inner = MemoryStorage();
    final storage = ThrowingStorage(inner);
    final app = ProbeApp(storage: storage, ads: OneShotAds(reloads: true), now: now);
    await app.start();
    await app.controller.startDaily();
    await playToGameOver(app.controller);
    await app.controller.endGame();
    expect(app.controller.secondDailyAttemptOffered, isTrue);

    storage.failWhen = (d) => d.profile.dailySecondAttemptUsed != null;
    await expectLater(app.controller.startSecondDailyAttempt(),
        throwsA(isA<StateError>()));
    storage.failWhen = null;

    final onDisk = (await inner.load())!;
    final flagged = onDisk.profile.dailySecondAttemptUsed != null;
    final started = onDisk.savedGame != null;
    expect(flagged, started,
        reason: 'the flag and the new board are one write');

    final relaunch = ProbeApp(
      storage: MemoryStorage(inner.writes.last),
      ads: OneShotAds(reloads: true),
      now: now,
    );
    await relaunch.start();
    expect(relaunch.controller.secondDailyAttemptOffered, isTrue,
        reason: 'the attempt was never granted, so it is still offered');
    await relaunch.controller.startSecondDailyAttempt();
    expect(relaunch.controller.profile.dailySecondAttemptUsed,
        relaunch.controller.today);
    expect(relaunch.controller.currentGame!.mode, core.GameMode.daily);
  });

  test('a second daily attempt writes the flag and the board together', () async {
    final storage = MemoryStorage();
    final app = ProbeApp(storage: storage, ads: OneShotAds(reloads: true), now: now);
    await app.start();
    await app.controller.startDaily();
    await playToGameOver(app.controller);
    await app.controller.endGame();
    final before = storage.writes.length;

    await app.controller.startSecondDailyAttempt();

    final added = storage.writes.sublist(before);
    for (final raw in added) {
      final data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final flagged = data.profile.dailySecondAttemptUsed != null;
      final started =
          data.savedGame != null && data.savedGame!.mode == core.GameMode.daily;
      expect(flagged, started, reason: 'no write shows one without the other');
    }
  });

  test('a failed write behind a fire-and-forget mutation is handled', () async {
    final inner = MemoryStorage();
    final storage = ThrowingStorage(inner);
    final app = ProbeApp(storage: storage, now: now);
    await app.start();
    storage.failWhen = (d) => d.profile.lastRewardedClosedAt != 0;

    app.controller.onRewardedShown();
    await app.controller.idle;
    await pumpEventQueue();

    expect(inner.writes, isNotEmpty);
  });
}
