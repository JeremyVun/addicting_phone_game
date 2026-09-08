import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/daily_rewards.dart';
import 'package:settle/meta/player_profile.dart';

final created = DateTime(2026, 5, 1, 9);
DateTime day(int offset) => DateTime(2026, 5, 1 + offset, 9);

PlayerProfile fresh() => PlayerProfile(createdAtMs: created.millisecondsSinceEpoch);

void main() {
  test('the cycle starts at day 1', () {
    expect(fresh().rewardCycleDay, 1);
    expect(fresh().lastRewardClaimOrdinal, isNull);
    expect(fresh().rewardDismissedOrdinal, isNull);
  });

  test('not offered on the profile\'s first day (design 10)', () {
    expect(DailyRewards.claimable(fresh(), created), isFalse);
    expect(DailyRewards.claimable(fresh(), DateTime(2026, 5, 1, 23, 59)), isFalse);
    expect(DailyRewards.claim(fresh(), created), fresh());
  });

  test('offered from day 2 and the first claim always pays day 1', () {
    expect(DailyRewards.claimable(fresh(), day(1)), isTrue);
    final p = DailyRewards.claim(fresh(), day(1));
    expect(p.coins, 25);
    expect(p.rewardCycleDay, 2);
    expect(p.lastRewardClaimOrdinal, isNotNull);

    final late = DailyRewards.claim(fresh(), day(40));
    expect(late.coins, 25, reason: 'a first claim weeks later still pays day 1');
  });

  test('one claim per local day', () {
    final once = DailyRewards.claim(fresh(), day(1));
    expect(DailyRewards.claimable(once, day(1)), isFalse);
    expect(DailyRewards.claim(once, DateTime(2026, 5, 2, 23, 0)), once);
  });

  test('dismissing hides it for that day only', () {
    final p = DailyRewards.dismiss(fresh(), day(1));
    expect(DailyRewards.claimable(p, day(1)), isFalse);
    expect(DailyRewards.claim(p, day(1)), p);
    expect(DailyRewards.claimable(p, day(2)), isTrue);
  });

  test('the cycle advances on consecutive days then wraps to day 1', () {
    var p = fresh();
    final coins = <int>[];
    for (var d = 1; d <= 8; d++) {
      p = DailyRewards.claim(p, day(d));
      coins.add(p.coins);
    }
    expect(coins, [25, 75, 150, 250, 400, 600, 1000, 1025]);
    expect(p.rewardCycleDay, 2);
  });

  test('a missed day restarts the cycle at day 1', () {
    var p = fresh();
    p = DailyRewards.claim(p, day(1));
    p = DailyRewards.claim(p, day(2));
    expect(p.rewardCycleDay, 3);
    p = DailyRewards.claim(p, day(4));
    expect(p.coins, 25 + 50 + 25);
    expect(p.rewardCycleDay, 2);
  });

  test('a dismissed day breaks the run like a missed one', () {
    var p = DailyRewards.claim(fresh(), day(1));
    p = DailyRewards.dismiss(p, day(2));
    expect(DailyRewards.nextReward(p, day(3)), 25);
  });

  test('nextReward previews without mutating', () {
    final p = DailyRewards.claim(fresh(), day(1));
    expect(DailyRewards.nextReward(p, day(2)), 50);
    expect(DailyRewards.nextReward(p, day(5)), 25);
    expect(DailyRewards.nextCycleDay(p, day(2)), 2);
  });
}
