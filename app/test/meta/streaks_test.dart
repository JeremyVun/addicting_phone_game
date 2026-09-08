import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/calendar.dart';
import 'package:settle/meta/player_profile.dart';
import 'package:settle/meta/streaks.dart';

PlayerProfile onDay(int ordinal, {int streak = 1, int freezes = 0, int coins = 0}) =>
    PlayerProfile(
      streak: streak,
      freezesHeld: freezes,
      coins: coins,
      lastCompletedOrdinal: ordinal,
    );

DateTime dayAt(int ordinal) => DateTime(2026, 1, 1).add(Duration(days: ordinal));

void main() {
  group('onDailyCompleted', () {
    test('first ever completion starts the streak at 1', () {
      final p = Streaks.onDailyCompleted(PlayerProfile(), 100);
      expect(p.streak, 1);
      expect(p.lastCompletedOrdinal, 100);
    });

    test('consecutive days increment', () {
      var p = PlayerProfile();
      for (var d = 100; d < 105; d++) {
        p = Streaks.onDailyCompleted(p, d);
      }
      expect(p.streak, 5);
    });

    test('a second attempt on the same day does not increment', () {
      final first = Streaks.onDailyCompleted(onDay(99, streak: 3), 100);
      expect(first.streak, 4);
      expect(Streaks.onDailyCompleted(first, 100), first);
    });

    test('a gap restarts at 1', () {
      expect(Streaks.onDailyCompleted(onDay(100, streak: 9), 103).streak, 1);
    });
  });

  group('reconcile', () {
    test('no daily ever completed is untouched', () {
      final p = PlayerProfile();
      expect(p.lastCompletedOrdinal, isNull);
      expect(Streaks.reconcile(p, dayAt(50)), p);
    });

    test('completed today or yesterday is untouched', () {
      final p = onDay(50, streak: 4, freezes: 2);
      expect(Streaks.reconcile(p, dayAt(50)), p);
      expect(Streaks.reconcile(p, dayAt(51)), p);
    });

    test('the kept streak still increments when today is played', () {
      var p = Streaks.reconcile(onDay(50, streak: 4, freezes: 1), dayAt(52));
      expect(p.streak, 4);
      p = Streaks.onDailyCompleted(p, 52);
      expect(p.streak, 5);
      expect(p.lastCompletedOrdinal, 52);
    });

    test('lastCompletedOrdinal stays factual; the gap is charged once', () {
      final p = Streaks.reconcile(onDay(50, streak: 4, freezes: 1), dayAt(52));
      expect(p.lastCompletedOrdinal, 50);
      expect(p.streakReconciledOrdinal, 51);
      expect(p.freezesHeld, 0);
    });

    test('a reset streak never spends a freeze on later days', () {
      var p = Streaks.reconcile(onDay(50, streak: 4), dayAt(53));
      expect(p.streak, 0);
      p = p.copyWith(freezesHeld: 2);
      for (var d = 54; d < 60; d++) {
        p = Streaks.reconcile(p, dayAt(d));
      }
      expect(p.freezesHeld, 2);
      expect(p.streak, 0);
    });

    test('reads the ordinal from the local date, not elapsed hours', () {
      final p = onDay(Calendar.dayOrdinal(DateTime(2026, 3, 7)), streak: 3);
      expect(Streaks.reconcile(p, DateTime(2026, 3, 8, 23, 59)).streak, 3);
    });
  });

  group('the gap x freeze matrix', () {
    // (days since the last completed daily, freezes held)
    // -> (streak after, freezes after).
    const expected = <(int, int), (int, int)>{
      (0, 0): (5, 0), (0, 1): (5, 1), (0, 2): (5, 2),
      (1, 0): (5, 0), (1, 1): (5, 1), (1, 2): (5, 2),
      (2, 0): (0, 0), (2, 1): (5, 0), (2, 2): (5, 1),
      (3, 0): (0, 0), (3, 1): (0, 1), (3, 2): (5, 0),
      (4, 0): (0, 0), (4, 1): (0, 1), (4, 2): (0, 2),
    };

    expected.forEach((input, want) {
      final (gap, freezes) = input;
      test('gap $gap with $freezes freezes', () {
        final before = onDay(50, streak: 5, freezes: freezes);
        final after = Streaks.reconcile(before, dayAt(50 + gap));
        expect((after.streak, after.freezesHeld), want);
        expect(
          Streaks.reconcile(after, dayAt(50 + gap)),
          after,
          reason: 'reconcile twice on the same day changes nothing more',
        );
      });
    });
  });

  group('buyFreeze', () {
    test('costs 200 coins and grants one freeze', () {
      final p = Streaks.buyFreeze(PlayerProfile(coins: 500));
      expect(p.coins, 300);
      expect(p.freezesHeld, 1);
    });

    test('refuses without the coins', () {
      final p = PlayerProfile(coins: 199);
      expect(Streaks.canBuyFreeze(p), isFalse);
      expect(Streaks.buyFreeze(p), p);
    });

    test('refuses at the cap of 2', () {
      final p = PlayerProfile(coins: 5000, freezesHeld: 2);
      expect(Streaks.canBuyFreeze(p), isFalse);
      expect(Streaks.buyFreeze(p), p);
    });
  });
}
