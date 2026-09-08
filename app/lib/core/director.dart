import 'dart:math' as math;

import 'board.dart';
import 'piece.dart';
import 'rng.dart';

/// Design 5. Piece generation is the retention lever, so every constant in
/// 5.2-5.5 is named here and nowhere else.
class Director {
  const Director._();

  static const double pressureFloor = 0.15;
  static const double pressureGain = 0.70;
  static const double pressureCeiling = 0.85;
  static const int pressureSetsToCeiling = 40;
  static const double skillAdjustment = 0.30;
  static const double skillMidpoint = 0.5;

  static const double mercyFillThreshold = 0.70;
  static const double mercyChanceBase = 0.70;
  static const double mercyChancePressureFactor = 0.40;
  static const int mercyMaxCells = 3;

  static const double assistChanceBase = 0.45;
  static const int assistCandidates = 12;

  static const int fitTriesAtPressure = 10;
  static const int fitTriesTotal = 30;

  static const List<String> restrictedFamilies = [
    'dot',
    'i2',
    'i3',
    'o2',
    'l3',
    'l4',
    't4',
  ];

  static final List<Piece> fullCatalogue = Piece.all;

  static final List<Piece> restrictedCatalogue = List.unmodifiable(
    Piece.all.where((p) => restrictedFamilies.contains(p.family)).toList(),
  );

  static final List<Piece> mercyCatalogue = List.unmodifiable(
    Piece.all.where((p) => p.size <= mercyMaxCells).toList(),
  );

  static double pressure(int setsGenerated, double skill) {
    final base = math.min(
      pressureCeiling,
      pressureFloor + pressureGain * setsGenerated / pressureSetsToCeiling,
    );
    return (base + skillAdjustment * (skill - skillMidpoint)).clamp(0.0, 1.0);
  }

  static double pieceWeight(Piece piece, double p) =>
      piece.familyWeight /
      piece.familyRotations *
      math.pow(piece.size / 4, 2 * p - 1);

  static List<double> weights(List<Piece> pool, double p) {
    final exponent = 2 * p - 1;
    final factors = <int, double>{};
    return [
      for (final piece in pool)
        piece.familyWeight /
            piece.familyRotations *
            factors.putIfAbsent(
                piece.size, () => math.pow(piece.size / 4, exponent) as double)
    ];
  }

  static Piece _sample(List<Piece> pool, List<double> weights, Rng rng) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var target = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      target -= weights[i];
      if (target < 0) return pool[i];
    }
    return pool.last;
  }

  /// Design 5.4. [pool] is a test seam; production callers use [restricted].
  static List<Piece> generateSet(
    Board board,
    Rng rng,
    double p,
    int count, {
    bool restricted = false,
    List<Piece>? pool,
  }) {
    if (count < 1 || count > 3) {
      throw ArgumentError.value(count, 'count', 'must be 1..3');
    }
    final catalogue =
        pool ?? (restricted ? restrictedCatalogue : fullCatalogue);
    final belowMercyFill = board.fill < mercyFillThreshold;
    var set = <Piece>[];
    for (var tries = 0; tries < fitTriesTotal; tries++) {
      final effectiveP = tries < fitTriesAtPressure ? p : 0.0;
      set = _drawSet(board, rng, effectiveP, count, catalogue);
      if (set.any(board.anyPlacement)) return set;
    }
    if (belowMercyFill) {
      return [Piece.dot, ...set.skip(1)];
    }
    return set;
  }

  static List<Piece> _drawSet(
    Board board,
    Rng rng,
    double p,
    int count,
    List<Piece> catalogue,
  ) {
    final w = weights(catalogue, p);
    final set = [for (var i = 0; i < count; i++) _sample(catalogue, w, rng)];
    _applyMercy(board, rng, p, set);
    _applyAssist(board, rng, p, set, catalogue, w);
    return set;
  }

  static void _applyMercy(Board board, Rng rng, double p, List<Piece> set) {
    if (board.fill < mercyFillThreshold) return;
    if (rng.nextDouble() >= mercyChanceBase - mercyChancePressureFactor * p) {
      return;
    }
    var largest = 0;
    for (var i = 1; i < set.length; i++) {
      if (set[i].size > set[largest].size) largest = i;
    }
    set[largest] = mercyCatalogue[rng.nextInt(mercyCatalogue.length)];
  }

  static void _applyAssist(
    Board board,
    Rng rng,
    double p,
    List<Piece> set,
    List<Piece> catalogue,
    List<double> w,
  ) {
    if (rng.nextDouble() >= assistChanceBase * (1 - p)) return;
    for (var i = 0; i < assistCandidates; i++) {
      final candidate = _sample(catalogue, w, rng);
      if (board.hasLineCompletingPlacement(candidate)) {
        set[rng.nextInt(set.length)] = candidate;
        return;
      }
    }
  }

  static bool setIsAssisted(Board board, Iterable<Piece> set) =>
      set.any(board.hasLineCompletingPlacement);
}
