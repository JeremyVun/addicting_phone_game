import 'economy.dart';

/// Design 10: never today's 19:00, always the next local date's.
class Reminders {
  const Reminders._();

  static DateTime nextReminderTime(DateTime localNow) => DateTime(
    localNow.year,
    localNow.month,
    localNow.day + 1,
    Economy.reminderHourLocal,
  );
}
