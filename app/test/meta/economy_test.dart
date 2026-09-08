import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/economy.dart';

void main() {
  test('coins per game are clamped to [5, 200] (7.1)', () {
    expect(Economy.coinsForScore(0), 5);
    expect(Economy.coinsForScore(249), 5);
    expect(Economy.coinsForScore(250), 5);
    expect(Economy.coinsForScore(300), 6);
    expect(Economy.coinsForScore(9999), 199);
    expect(Economy.coinsForScore(10000), 200);
    expect(Economy.coinsForScore(50000), 200);
  });

  test('spend and cap constants match design 6, 7.5 and 8.1', () {
    expect(Economy.continueCost, 150);
    expect(Economy.rerollCost, 50);
    expect(Economy.freezeCost, 200);
    expect(Economy.maxFreezesHeld, 2);
    expect(Economy.maxRerollsPerGame, 3);
    expect(Economy.maxContinuesPerGame, 1);
    expect(Economy.firstGameOfDayBonus, 25);
    expect(Economy.initialSkill, 0.35);
  });

  test('daily reward calendar is 25/50/75/100/150/200/400 (7.4)', () {
    expect(Economy.dailyRewardCycle, [25, 50, 75, 100, 150, 200, 400]);
  });

  test('product table matches design 8.3', () {
    expect(Products.all.map((p) => p.id), [
      'remove_ads',
      'coins_small',
      'coins_medium',
      'coins_large',
      'theme_pack_all',
    ]);
    expect(Products.byId('coins_small')!.coins, 500);
    expect(Products.byId('coins_medium')!.coins, 3000);
    expect(Products.byId('coins_large')!.coins, 8000);
    expect(Products.byId('remove_ads')!.grantsAdFree, isTrue);
    expect(Products.byId('theme_pack_all')!.grantsThemePack, isTrue);
    expect(Products.byId('nope'), isNull);
  });
}
