import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/economy.dart';
import 'package:settle/meta/player_profile.dart';
import 'package:settle/meta/purchases.dart';
import 'package:settle/meta/themes.dart';

void main() {
  test('each product grants what design 8.3 says', () {
    expect(Purchases.grant(PlayerProfile(), Products.coinsSmall, 't1').coins, 500);
    expect(Purchases.grant(PlayerProfile(), Products.coinsMedium, 't1').coins, 3000);
    expect(Purchases.grant(PlayerProfile(), Products.coinsLarge, 't1').coins, 8000);
    expect(Purchases.grant(PlayerProfile(), Products.removeAds, 't1').adFree, isTrue);
    final pack = Purchases.grant(PlayerProfile(), Products.themePackAll, 't1');
    expect(pack.themePackOwned, isTrue);
    expect(Themes.unlockedBy(pack).length, 12);
  });

  test('a grant lands in pending until it is confirmed', () {
    final granted = Purchases.grant(PlayerProfile(), Products.coinsSmall, 'tok');
    expect(granted.pendingPurchaseTokens, {'tok'});
    expect(granted.completedPurchaseTokens, isEmpty);

    final done = Purchases.markPurchaseCompleted(granted, 'tok');
    expect(done.pendingPurchaseTokens, isEmpty);
    expect(done.completedPurchaseTokens, ['tok']);
    expect(done.coins, 500);
  });

  test('a repeated token grants nothing again, pending or completed', () {
    final pending = Purchases.grant(PlayerProfile(), Products.coinsSmall, 'tok');
    expect(Purchases.grant(pending, Products.coinsSmall, 'tok'), pending);

    final completed = Purchases.markPurchaseCompleted(pending, 'tok');
    expect(Purchases.grant(completed, Products.coinsSmall, 'tok'), completed);
    expect(completed.coins, 500);
  });

  test('markPurchaseCompleted is idempotent and ignores unknown tokens', () {
    final done = Purchases.markPurchaseCompleted(
      Purchases.grant(PlayerProfile(), Products.coinsSmall, 'tok'),
      'tok',
    );
    expect(Purchases.markPurchaseCompleted(done, 'tok'), done);
    expect(
      Purchases.markPurchaseCompleted(done, 'never-granted').completedPurchaseTokens,
      ['tok', 'never-granted'],
    );
    expect(Purchases.markPurchaseCompleted(done, ''), done);
  });

  test('a different token for the same product grants again', () {
    var p = Purchases.grant(PlayerProfile(), Products.coinsSmall, 'token-a');
    p = Purchases.grant(p, Products.coinsSmall, 'token-b');
    expect(p.coins, 1000);
    expect(p.pendingPurchaseTokens, {'token-a', 'token-b'});
  });

  test('an empty token grants nothing', () {
    expect(Purchases.grant(PlayerProfile(), Products.coinsLarge, ''), PlayerProfile());
  });

  test('an unknown product grants nothing and records nothing', () {
    expect(Purchases.grant(PlayerProfile(), 'coins_enormous', 'tok'), PlayerProfile());
  });

  test('pending is unbounded; completed keeps the last 200', () {
    var p = PlayerProfile();
    for (var i = 0; i < 205; i++) {
      p = Purchases.grant(p, Products.coinsSmall, 'token-$i');
    }
    expect(p.pendingPurchaseTokens.length, 205);
    expect(p.coins, 205 * 500);

    for (var i = 0; i < 205; i++) {
      p = Purchases.markPurchaseCompleted(p, 'token-$i');
    }
    expect(p.pendingPurchaseTokens, isEmpty);
    expect(p.completedPurchaseTokens.length, Economy.completedTokensCap);
    expect(p.completedPurchaseTokens.first, 'token-5');
    expect(p.completedPurchaseTokens.last, 'token-204');
    expect(Purchases.alreadyGranted(p, 'token-0'), isFalse);
    expect(Purchases.alreadyGranted(p, 'token-204'), isTrue);
  });
}
