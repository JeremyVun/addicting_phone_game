/// Design 3. The only calendar arithmetic in the app: DST-proof because both
/// ends are UTC midnights.
const int dayOrdinalEpochYear = 2026;
const int dayOrdinalEpochMonth = 1;
const int dayOrdinalEpochDay = 1;

int dayOrdinalOf(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day)
        .difference(DateTime.utc(
            dayOrdinalEpochYear, dayOrdinalEpochMonth, dayOrdinalEpochDay))
        .inDays;

int dailySeedFor(int dayOrdinal) => dayOrdinal;
