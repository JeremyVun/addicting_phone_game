import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/levels.dart';

void main() {
  test('xpForLevel matches the design 7.2 table', () {
    expect(Levels.xpForLevel(1), 0);
    expect(Levels.xpForLevel(2), 150);
    expect(Levels.xpForLevel(3), 487);
    expect(Levels.xpForLevel(5), 1583);
    expect(Levels.xpForLevel(10), 6285);
    expect(Levels.xpForLevel(20), 22386);
    expect(Levels.xpForLevel(30), 45938);
  });

  test('levelFor is the inverse at and around each threshold', () {
    expect(Levels.levelFor(0), 1);
    expect(Levels.levelFor(149), 1);
    expect(Levels.levelFor(150), 2);
    expect(Levels.levelFor(486), 2);
    expect(Levels.levelFor(487), 3);
    expect(Levels.levelFor(6284), 9);
    expect(Levels.levelFor(6285), 10);
    expect(Levels.levelFor(45938), 30);
  });

  test('no level cap', () {
    expect(Levels.levelFor(10000000), greaterThan(60));
  });

  test('progressWithinLevel spans 0 to 1 inside a level', () {
    expect(Levels.progressWithinLevel(0), 0);
    expect(Levels.progressWithinLevel(150), 0);
    expect(Levels.progressWithinLevel(486), closeTo(336 / 337, 1e-9));
    expect(Levels.progressWithinLevel(318), closeTo(168 / 337, 1e-9));
  });

  test('level-up reward is 50 coins x new level', () {
    expect(Levels.levelUpReward(2), 100);
    expect(Levels.levelUpReward(10), 500);
  });
}
