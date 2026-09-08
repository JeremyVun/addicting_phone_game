import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/core/day_ordinal.dart';
import 'package:settle/core/director.dart';
import 'package:settle/core/game.dart' as core;
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/meta/meta.dart';
import 'package:settle/services/storage.dart';

import 'harness.dart';

final DateTime _today = DateTime(2026, 9, 8, 12);
final int _ordinal = dayOrdinalOf(_today);

String _envelope({PlayerProfile? profile, core.GameState? game}) => jsonEncode(
  AppData(
    profile: profile ?? PlayerProfile.initial(analyticsUnitId: 'u', now: _today),
    savedGame: game,
  ).toJson(),
);

core.GameState _dailyGame(int ordinal, {int startedAtMs = 1}) =>
    core.Game.newGame(
      mode: core.GameMode.daily,
      seed: dailySeedFor(ordinal),
      startedAtMs: startedAtMs,
      dayOrdinal: ordinal,
    );

void main() {
  test('startDaily uses today ordinal as the seed, at skill 0.5 unrestricted', () async {
    final harness = Harness(now: _today);
    await harness.start();
    await harness.controller.startDaily();

    final game = harness.controller.currentGame!;
    expect(game.mode, core.GameMode.daily);
    expect(game.seed, _ordinal);
    expect(game.dayOrdinal, _ordinal);
    expect(game.skill, Director.skillMidpoint);
    expect(game.restricted, isFalse);
    expect(harness.navigator.calls, contains('goPlay'));
    expect(
      harness.analytics.named('game_started').single.dims['mode'],
      'daily',
    );
  });

  test("resumeDaily returns to today's saved board without regenerating it", () async {
    final saved = _dailyGame(_ordinal);
    final harness = Harness(saved: _envelope(game: saved), now: _today);
    await harness.start();

    expect(harness.controller.dailyCardState, DailyCardState.inProgress);
    await harness.controller.resumeDaily();
    expect(harness.controller.currentGame!.id, saved.id);
    expect(harness.navigator.calls, ['goPlay']);
  });

  test("a saved daily from another date is discarded on launch", () async {
    final harness = Harness(
      saved: _envelope(game: _dailyGame(_ordinal - 1)),
      now: _today,
    );
    await harness.start();

    expect(harness.controller.currentGame, isNull);
    expect(harness.controller.dailyCardState, DailyCardState.notPlayed);
  });

  test('a second daily start is refused after one attempt', () async {
    final profile = PlayerProfile.initial(analyticsUnitId: 'u', now: _today)
        .copyWith(dailyAttempts: {_ordinal: 1});
    final harness = Harness(saved: _envelope(profile: profile), now: _today);
    await harness.start();

    expect(harness.controller.canStartDaily, isFalse);
    await harness.controller.startDaily();
    expect(harness.controller.currentGame, isNull);
    expect(harness.controller.dailyCardState, DailyCardState.done);
  });

  test('the second attempt needs the reward and lands in one write', () async {
    final profile = PlayerProfile.initial(analyticsUnitId: 'u', now: _today)
        .copyWith(dailyAttempts: {_ordinal: 1}, dailyBest: {_ordinal: 900});
    final harness = Harness(saved: _envelope(profile: profile), now: _today);
    await harness.start();

    harness.ads.rewardedReady = false;
    await harness.controller.startSecondDailyAttempt();
    expect(harness.controller.currentGame, isNull);
    expect(harness.controller.profile.dailySecondAttemptUsed, isNull);

    harness.ads.rewardedReady = true;
    await harness.controller.startSecondDailyAttempt();
    await harness.controller.idle;

    expect(harness.ads.rewardedShows, [RewardedPlacement.dailySecondAttempt]);
    final envelopes = [
      for (final write in harness.storage.writes)
        jsonDecode(write) as Map<String, dynamic>,
    ];
    final granting = envelopes.where((e) => e['savedGame'] != null).toList();
    expect(granting, hasLength(1));
    expect(
      (granting.single['profile'] as Map<String, dynamic>)['dailySecondAttemptUsed'],
      _ordinal,
    );
    expect(harness.controller.dailyCardState, DailyCardState.inProgress);
    expect(harness.controller.secondDailyAttemptOffered, isFalse);
  });

  test('finishing a daily records best, attempts, streak and daily_completed', () async {
    final harness = Harness(now: _today);
    await harness.start();
    await harness.controller.startDaily();
    await playToGameOver(harness.controller);
    final result = await harness.controller.finishGame();

    final profile = harness.controller.profile;
    expect(result!.mode, GameMode.daily);
    expect(result.dayOrdinal, _ordinal);
    expect(profile.dailyBest[_ordinal], result.score);
    expect(profile.dailyAttempts[_ordinal], 1);
    expect(profile.streak, 1);
    expect(profile.lastCompletedOrdinal, _ordinal);
    expect(
      harness.analytics.named('daily_completed').single.dims['streak'],
      '1',
    );
    expect(harness.controller.secondDailyAttemptOffered, isTrue);
  });

  test('a streak freeze costs 200 and is refused at the cap or when poor', () async {
    final harness = Harness(now: _today);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 199)),
    );

    expect(harness.controller.canBuyStreakFreeze, isFalse);
    await harness.controller.buyStreakFreeze();
    expect(harness.controller.profile.freezesHeld, 0);
    expect(harness.controller.profile.coins, 199);

    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 500)),
    );
    await harness.controller.buyStreakFreeze();
    await harness.controller.buyStreakFreeze();
    expect(harness.controller.profile.freezesHeld, Economy.maxFreezesHeld);
    expect(harness.controller.profile.coins, 500 - 2 * Economy.freezeCost);

    expect(harness.controller.canBuyStreakFreeze, isFalse);
    await harness.controller.buyStreakFreeze();
    expect(harness.controller.profile.freezesHeld, Economy.maxFreezesHeld);
    expect(harness.controller.profile.coins, 100);
  });

  test('the reward pays the cycle day it advertises, and dismiss holds for the day', () async {
    final created = PlayerProfile.initial(
      analyticsUnitId: 'u',
      now: _today.subtract(const Duration(days: 3)),
    );
    final harness = Harness(saved: _envelope(profile: created), now: _today);
    await harness.start();

    expect(harness.controller.dailyRewardClaimable, isTrue);
    expect(harness.controller.dailyRewardCycleDay, 1);
    expect(harness.controller.dailyRewardAmount, Economy.dailyRewardCycle[0]);
    await harness.controller.claimDailyReward();
    expect(harness.controller.profile.coins, Economy.dailyRewardCycle[0]);
    expect(harness.controller.dailyRewardClaimable, isFalse);

    harness.clock.advance(const Duration(days: 1));
    expect(harness.controller.dailyRewardCycleDay, 2);
    expect(harness.controller.dailyRewardAmount, Economy.dailyRewardCycle[1]);
    await harness.controller.dismissDailyReward();
    expect(harness.controller.dailyRewardClaimable, isFalse);
    expect(harness.controller.profile.coins, Economy.dailyRewardCycle[0]);

    harness.clock.advance(const Duration(days: 1));
    expect(harness.controller.dailyRewardClaimable, isTrue);
    expect(harness.controller.dailyRewardCycleDay, 1);
  });

  test('buying a coin theme deducts the price and selects it', () async {
    final harness = Harness(now: _today);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 2000)),
    );
    await harness.controller.buyTheme(11);

    expect(harness.controller.profile.coins, 500);
    expect(harness.controller.profile.selectedTheme, 11);
    expect(
      harness.analytics.named('theme_selected').single.dims['theme'],
      'Pearl',
    );
  });
}
