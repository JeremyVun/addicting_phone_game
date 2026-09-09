/// Design 12: the dimension strings, verbatim.
class Buckets {
  const Buckets._();

  static String score(int score) {
    if (score < 500) return '0-499';
    if (score < 2000) return '500-1999';
    if (score < 5000) return '2000-4999';
    if (score < 10000) return '5000-9999';
    return '10000+';
  }

  static String placements(int placements) {
    if (placements < 20) return '<20';
    if (placements < 60) return '20-59';
    if (placements < 120) return '60-119';
    return '120+';
  }

  static String streak(int streak) {
    if (streak <= 1) return '1';
    if (streak < 7) return '2-6';
    if (streak < 30) return '7-29';
    return '30+';
  }

  /// 7 is its own bucket because D7 retention keys on it.
  static String sinceInstall(int days) {
    if (days <= 0) return '0';
    if (days == 1) return '1';
    if (days < 7) return '2-6';
    if (days == 7) return '7';
    if (days < 30) return '8-29';
    return '30+';
  }

  static String level(int level) {
    if (level <= 4) return '2-4';
    if (level < 10) return '5-9';
    if (level < 20) return '10-19';
    return '20+';
  }
}
