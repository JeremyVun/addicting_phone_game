/// Mirrors `core`'s mode; `meta` never imports `core`.
enum GameMode { classic, daily }

/// What the app hands to `meta` when a game reaches its final state (6.1).
class GameSummary {
  const GameSummary({
    required this.mode,
    required this.gameId,
    required this.score,
    required this.placements,
    required this.durationMs,
    required this.maxCombo,
    required this.boardClearedCount,
    this.continued = false,
    this.dayOrdinal,
  });

  final GameMode mode;
  final String gameId;
  final int score;
  final int placements;
  final int durationMs;
  final int maxCombo;
  final int boardClearedCount;
  final bool continued;
  final int? dayOrdinal;

  bool get isDaily => mode == GameMode.daily;

  /// Combo increments on every clearing placement (2.4), so a combo of at
  /// least 1 is exactly "cleared at least one line".
  bool get clearedALine => maxCombo >= 1;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'gameId': gameId,
    'score': score,
    'placements': placements,
    'durationMs': durationMs,
    'maxCombo': maxCombo,
    'boardClearedCount': boardClearedCount,
    'continued': continued,
    'dayOrdinal': dayOrdinal,
  };

  static GameSummary fromJson(Map<String, dynamic> json) => GameSummary(
    mode: GameMode.values.byName(json['mode'] as String),
    gameId: json['gameId'] as String,
    score: json['score'] as int,
    placements: json['placements'] as int,
    durationMs: json['durationMs'] as int,
    maxCombo: json['maxCombo'] as int,
    boardClearedCount: json['boardClearedCount'] as int,
    continued: json['continued'] as bool? ?? false,
    dayOrdinal: json['dayOrdinal'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is GameSummary &&
      other.mode == mode &&
      other.gameId == gameId &&
      other.score == score &&
      other.placements == placements &&
      other.durationMs == durationMs &&
      other.maxCombo == maxCombo &&
      other.boardClearedCount == boardClearedCount &&
      other.continued == continued &&
      other.dayOrdinal == dayOrdinal;

  @override
  int get hashCode => Object.hash(
    mode,
    gameId,
    score,
    placements,
    durationMs,
    maxCombo,
    boardClearedCount,
    continued,
    dayOrdinal,
  );

  @override
  String toString() => 'GameSummary(${mode.name}, $gameId, score $score)';
}
