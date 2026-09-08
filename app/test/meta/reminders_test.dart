import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/reminders.dart';

void main() {
  test('always 19:00 on the next local date, never today', () {
    expect(
      Reminders.nextReminderTime(DateTime(2026, 5, 4, 5, 0)),
      DateTime(2026, 5, 5, 19),
    );
    expect(
      Reminders.nextReminderTime(DateTime(2026, 5, 4, 19, 30)),
      DateTime(2026, 5, 5, 19),
    );
    expect(
      Reminders.nextReminderTime(DateTime(2026, 5, 4, 23, 59, 59)),
      DateTime(2026, 5, 5, 19),
    );
  });

  test('rolls over month and year boundaries', () {
    expect(
      Reminders.nextReminderTime(DateTime(2026, 1, 31, 23, 59)),
      DateTime(2026, 2, 1, 19),
    );
    expect(
      Reminders.nextReminderTime(DateTime(2026, 12, 31, 20, 0)),
      DateTime(2027, 1, 1, 19),
    );
    expect(
      Reminders.nextReminderTime(DateTime(2028, 2, 28, 12)),
      DateTime(2028, 2, 29, 19),
    );
  });
}
