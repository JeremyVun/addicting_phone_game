/// Design 3: the only calendar arithmetic in the app.
class Calendar {
  const Calendar._();

  static final DateTime epoch = DateTime.utc(2026, 1, 1);

  static int dayOrdinal(DateTime localNow) =>
      DateTime.utc(localNow.year, localNow.month, localNow.day)
          .difference(epoch)
          .inDays;

  static bool isSameLocalDay(DateTime a, DateTime b) =>
      dayOrdinal(a) == dayOrdinal(b);
}
