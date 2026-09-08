import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/day_ordinal.dart';

void main() {
  test('day ordinal counts local days from 2026-01-01', () {
    expect(dayOrdinalOf(DateTime(2026, 1, 1)), 0);
    expect(dayOrdinalOf(DateTime(2026, 1, 2)), 1);
    expect(dayOrdinalOf(DateTime(2026, 12, 31)), 364);
    expect(dayOrdinalOf(DateTime(2027, 1, 1)), 365);
    expect(dayOrdinalOf(DateTime(2025, 12, 31)), -1);
  });

  test('the time of day never matters', () {
    for (var hour = 0; hour < 24; hour++) {
      expect(dayOrdinalOf(DateTime(2026, 6, 15, hour, 30, 15)),
          dayOrdinalOf(DateTime(2026, 6, 15)));
    }
  });

  test('consecutive local dates differ by one across a DST boundary', () {
    var previous = dayOrdinalOf(DateTime(2026, 3, 1));
    for (var day = 2; day <= 31; day++) {
      final ordinal = dayOrdinalOf(DateTime(2026, 3, day));
      expect(ordinal - previous, 1);
      previous = ordinal;
    }
  });

  test('the daily seed is the day ordinal', () {
    expect(dailySeedFor(123), 123);
  });
}
