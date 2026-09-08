import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/calendar.dart';

void main() {
  group('dayOrdinal', () {
    test('epoch is 0 and counts calendar days', () {
      expect(Calendar.dayOrdinal(DateTime(2026, 1, 1)), 0);
      expect(Calendar.dayOrdinal(DateTime(2026, 1, 2)), 1);
      expect(Calendar.dayOrdinal(DateTime(2026, 3, 1)), 59);
      expect(Calendar.dayOrdinal(DateTime(2027, 1, 1)), 365);
      expect(Calendar.dayOrdinal(DateTime(2025, 12, 31)), -1);
    });

    test('ignores the time of day', () {
      expect(
        Calendar.dayOrdinal(DateTime(2026, 5, 4, 0, 0, 0)),
        Calendar.dayOrdinal(DateTime(2026, 5, 4, 23, 59, 59, 999)),
      );
    });

    test('advances by exactly 1 across a 23-hour spring-forward day', () {
      // US: 2026-03-08 loses an hour; AU: 2026-10-04 loses an hour.
      for (final (before, after) in [
        (DateTime(2026, 3, 8, 23, 30), DateTime(2026, 3, 9, 0, 30)),
        (DateTime(2026, 10, 4, 23, 30), DateTime(2026, 10, 5, 0, 30)),
      ]) {
        expect(
          Calendar.dayOrdinal(after) - Calendar.dayOrdinal(before),
          1,
          reason: '$before -> $after',
        );
      }
      expect(
        Calendar.dayOrdinal(DateTime(2026, 3, 8, 1, 30)),
        Calendar.dayOrdinal(DateTime(2026, 3, 8, 3, 30)),
      );
    });

    test('advances by exactly 1 across a 25-hour fall-back day', () {
      // US: 2026-11-01 repeats an hour; AU: 2026-04-05 repeats an hour.
      expect(
        Calendar.dayOrdinal(DateTime(2026, 11, 2)) -
            Calendar.dayOrdinal(DateTime(2026, 11, 1)),
        1,
      );
      expect(
        Calendar.dayOrdinal(DateTime(2026, 4, 6)) -
            Calendar.dayOrdinal(DateTime(2026, 4, 5)),
        1,
      );
      expect(
        Calendar.dayOrdinal(DateTime(2026, 11, 1, 1, 30)),
        Calendar.dayOrdinal(DateTime(2026, 11, 1, 22, 30)),
      );
    });
  });

  test('isSameLocalDay', () {
    expect(
      Calendar.isSameLocalDay(DateTime(2026, 7, 1, 0), DateTime(2026, 7, 1, 23)),
      isTrue,
    );
    expect(
      Calendar.isSameLocalDay(DateTime(2026, 7, 1, 23), DateTime(2026, 7, 2, 0)),
      isFalse,
    );
  });
}
