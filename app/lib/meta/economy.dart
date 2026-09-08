/// Every tunable number from design 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 8.1, 8.2
/// and 8.3. Nothing outside `meta/` may restate one of these.
class Economy {
  const Economy._();

  // 7.1 coins
  static const int coinsScoreDivisor = 50;
  static const int coinsMinPerGame = 5;
  static const int coinsMaxPerGame = 200;
  static const int firstGameOfDayBonus = 25;

  static int coinsForScore(int score) {
    final raw = score ~/ coinsScoreDivisor;
    return raw < coinsMinPerGame
        ? coinsMinPerGame
        : (raw > coinsMaxPerGame ? coinsMaxPerGame : raw);
  }

  // 7.2 xp and level
  static const int xpScoreDivisor = 10;
  static const double levelXpFactor = 150;
  static const double levelXpExponent = 1.7;
  static const int levelUpCoinsPerLevel = 50;

  // 7.4 daily reward calendar
  static const List<int> dailyRewardCycle = [25, 50, 75, 100, 150, 200, 400];
  static const int dailyRewardCycleLength = 7;

  static int dailyRewardForCycleDay(int cycleDay) =>
      dailyRewardCycle[cycleDay - 1];

  // 7.5 streak
  static const int freezeCost = 200;
  static const int maxFreezesHeld = 2;

  // 7.6 skill
  static const double initialSkill = 0.35;
  static const double skillRetain = 0.8;
  static const double skillLearn = 0.2;
  static const double skillScoreCap = 6000;

  // 6 / 8.1 spends and caps
  static const int continueCost = 150;
  static const int rerollCost = 50;
  static const int maxContinuesPerGame = 1;
  static const int maxRerollsPerGame = 3;

  // 8.2 interstitial policy
  static const int interstitialMinLifetimeGames = 3;
  static const int interstitialMinGamesSince = 2;
  static const int interstitialCooldownMs = 90 * 1000;
  static const int rewardedCooldownMs = 45 * 1000;
  static const int interstitialMinGameDurationMs = 30 * 1000;
  static const int clockRollbackResetMs = 24 * 60 * 60 * 1000;

  // 8.3 purchases
  static const int grantedPurchaseTokensCap = 200;

  // 10 reminder
  static const int reminderHourLocal = 19;
}

enum ProductKind { consumable, nonConsumable }

/// Design 8.3.
class Product {
  const Product({
    required this.id,
    required this.kind,
    this.coins = 0,
    this.grantsAdFree = false,
    this.grantsThemePack = false,
  });

  final String id;
  final ProductKind kind;
  final int coins;
  final bool grantsAdFree;
  final bool grantsThemePack;
}

class Products {
  const Products._();

  static const String removeAds = 'remove_ads';
  static const String coinsSmall = 'coins_small';
  static const String coinsMedium = 'coins_medium';
  static const String coinsLarge = 'coins_large';
  static const String themePackAll = 'theme_pack_all';

  static const List<Product> all = [
    Product(
      id: removeAds,
      kind: ProductKind.nonConsumable,
      grantsAdFree: true,
    ),
    Product(id: coinsSmall, kind: ProductKind.consumable, coins: 500),
    Product(id: coinsMedium, kind: ProductKind.consumable, coins: 3000),
    Product(id: coinsLarge, kind: ProductKind.consumable, coins: 8000),
    Product(
      id: themePackAll,
      kind: ProductKind.nonConsumable,
      grantsThemePack: true,
    ),
  ];

  static Product? byId(String id) {
    for (final product in all) {
      if (product.id == id) return product;
    }
    return null;
  }
}

/// Design 8.1.
enum RewardedPlacement { continueGame, reroll, doubleCoins, dailySecondAttempt }
