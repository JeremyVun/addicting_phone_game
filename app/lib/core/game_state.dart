import 'board.dart';
import 'piece.dart';
import 'rng.dart';

enum GameMode { classic, daily }

enum GameStatus { playing, over }

/// Design 4. `bestScore` is deliberately absent: it is profile data.
class GameState {
  const GameState({
    required this.id,
    required this.board,
    required this.set,
    required this.score,
    required this.comboCount,
    required this.missCount,
    required this.setsGenerated,
    required this.continuesUsed,
    required this.rerollsUsed,
    required this.mode,
    required this.seed,
    required this.rng,
    required this.status,
    required this.skill,
    required this.firstGameEver,
    required this.startedAtMs,
    required this.elapsedMs,
    this.dayOrdinal,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    final version = json['v'] as int;
    if (version != schemaVersion) {
      throw ArgumentError.value(version, 'v', 'unsupported schema version');
    }
    return GameState(
      id: json['id'] as String,
      board: Board.fromJson(json['grid'] as String),
      set: List.unmodifiable([
        for (final id in json['set'] as List)
          id == null ? null : Piece.byId[id as String]!,
      ]),
      score: json['score'] as int,
      comboCount: json['comboCount'] as int,
      missCount: json['missCount'] as int,
      setsGenerated: json['setsGenerated'] as int,
      continuesUsed: json['continuesUsed'] as int,
      rerollsUsed: json['rerollsUsed'] as int,
      mode: GameMode.values.byName(json['mode'] as String),
      seed: json['seed'] as int,
      rng: Rng.fromJson((json['rng'] as Map).cast<String, dynamic>()),
      status: GameStatus.values.byName(json['status'] as String),
      skill: (json['skill'] as num).toDouble(),
      firstGameEver: json['firstGameEver'] as bool,
      startedAtMs: json['startedAtMs'] as int,
      elapsedMs: json['elapsedMs'] as int,
      dayOrdinal: json['dayOrdinal'] as int?,
    );
  }

  static const int schemaVersion = 1;
  static const int slotCount = 3;
  static const int maxRerolls = 3;
  static const int maxContinues = 1;

  final String id;
  final Board board;

  /// Three slots; a null slot has been played.
  final List<Piece?> set;
  final int score;
  final int comboCount;
  final int missCount;
  final int setsGenerated;
  final int continuesUsed;
  final int rerollsUsed;
  final GameMode mode;
  final int seed;
  final Rng rng;
  final GameStatus status;
  final double skill;
  final bool firstGameEver;
  final int startedAtMs;
  final int elapsedMs;
  final int? dayOrdinal;

  int get remainingSlots => set.where((p) => p != null).length;

  bool get isOver => status == GameStatus.over;

  GameState copyWith({
    Board? board,
    List<Piece?>? set,
    int? score,
    int? comboCount,
    int? missCount,
    int? setsGenerated,
    int? continuesUsed,
    int? rerollsUsed,
    Rng? rng,
    GameStatus? status,
    int? elapsedMs,
  }) =>
      GameState(
        id: id,
        board: board ?? this.board,
        set: set ?? this.set,
        score: score ?? this.score,
        comboCount: comboCount ?? this.comboCount,
        missCount: missCount ?? this.missCount,
        setsGenerated: setsGenerated ?? this.setsGenerated,
        continuesUsed: continuesUsed ?? this.continuesUsed,
        rerollsUsed: rerollsUsed ?? this.rerollsUsed,
        mode: mode,
        seed: seed,
        rng: rng ?? this.rng,
        status: status ?? this.status,
        skill: skill,
        firstGameEver: firstGameEver,
        startedAtMs: startedAtMs,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        dayOrdinal: dayOrdinal,
      );

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'id': id,
        'grid': board.toJson(),
        'set': [for (final p in set) p?.id],
        'score': score,
        'comboCount': comboCount,
        'missCount': missCount,
        'setsGenerated': setsGenerated,
        'continuesUsed': continuesUsed,
        'rerollsUsed': rerollsUsed,
        'mode': mode.name,
        'seed': seed,
        'rng': rng.toJson(),
        'status': status.name,
        'skill': skill,
        'firstGameEver': firstGameEver,
        'startedAtMs': startedAtMs,
        'elapsedMs': elapsedMs,
        'dayOrdinal': dayOrdinal,
      };

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.id == id &&
      other.board == board &&
      _sameSet(other.set, set) &&
      other.score == score &&
      other.comboCount == comboCount &&
      other.missCount == missCount &&
      other.setsGenerated == setsGenerated &&
      other.continuesUsed == continuesUsed &&
      other.rerollsUsed == rerollsUsed &&
      other.mode == mode &&
      other.seed == seed &&
      other.rng == rng &&
      other.status == status &&
      other.skill == skill &&
      other.firstGameEver == firstGameEver &&
      other.startedAtMs == startedAtMs &&
      other.elapsedMs == elapsedMs &&
      other.dayOrdinal == dayOrdinal;

  @override
  int get hashCode => Object.hash(
        id,
        board,
        Object.hashAll(set.map((p) => p?.id)),
        score,
        comboCount,
        missCount,
        setsGenerated,
        continuesUsed,
        rerollsUsed,
        mode,
        seed,
        rng,
        status,
        skill,
        firstGameEver,
        startedAtMs,
        elapsedMs,
        dayOrdinal,
      );

  static bool _sameSet(List<Piece?> a, List<Piece?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]?.id != b[i]?.id) return false;
    }
    return true;
  }
}
