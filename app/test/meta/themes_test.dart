import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/levels.dart';
import 'package:settle/meta/player_profile.dart';
import 'package:settle/meta/themes.dart';

PlayerProfile atLevel(int level, {int coins = 0}) =>
    PlayerProfile(xp: Levels.xpForLevel(level), coins: coins);

void main() {
  test('twelve slots with the design 7.3 names in slot order', () {
    expect(Themes.all.map((t) => t.name), [
      'Obsidian',
      'Dawn',
      'Meadow',
      'Coral',
      'Glacier',
      'Desert',
      'Storm',
      'Lavender',
      'Ember',
      'Plum',
      'Pearl',
      'Lagoon',
    ]);
    expect(Themes.all.map((t) => t.slot), List.generate(12, (i) => i + 1));
  });

  test('the unlock table', () {
    expect(
      Themes.all.map((t) => '${t.unlockKind.name}:${t.requirement}'),
      [
        'defaultUnlocked:0',
        'level:2',
        'level:4',
        'level:6',
        'level:9',
        'level:12',
        'level:16',
        'level:20',
        'level:25',
        'level:30',
        'coins:1500',
        'coins:3000',
      ],
    );
  });

  test('slot 1 is always unlocked and levels unlock in order', () {
    expect(Themes.unlockedBy(PlayerProfile()), {1});
    expect(Themes.unlockedBy(atLevel(2)), {1, 2});
    expect(Themes.unlockedBy(atLevel(8)), {1, 2, 3, 4});
    expect(Themes.unlockedBy(atLevel(30)), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});
  });

  test('coin themes are never unlocked by level', () {
    expect(Themes.unlockedBy(atLevel(99)).contains(11), isFalse);
    expect(Themes.unlockedBy(atLevel(99)).contains(12), isFalse);
  });

  test('canBuy needs a coin theme, the coins, and no prior unlock', () {
    expect(Themes.canBuy(atLevel(1, coins: 1499), 11), isFalse);
    expect(Themes.canBuy(atLevel(1, coins: 1500), 11), isTrue);
    expect(Themes.canBuy(atLevel(1, coins: 5000), 2), isFalse);
    final bought = Themes.buy(atLevel(1, coins: 5000), 11);
    expect(bought.coins, 3500);
    expect(Themes.unlockedBy(bought).contains(11), isTrue);
    expect(Themes.canBuy(bought, 11), isFalse);
    expect(Themes.buy(bought, 11), bought);
  });

  test('the theme pack unlocks all twelve', () {
    expect(
      Themes.unlockedBy(PlayerProfile(themePackOwned: true)).length,
      12,
    );
  });

  test('select refuses a locked slot', () {
    final p = PlayerProfile();
    expect(Themes.select(p, 5), p);
    expect(Themes.select(atLevel(9), 5).selectedTheme, 5);
  });
}
