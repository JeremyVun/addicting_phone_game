import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/scoring.dart';

void main() {
  test('clear table from design 2.4', () {
    expect([for (var n = 0; n <= 6; n++) Scoring.clearPoints(n)],
        [0, 10, 30, 60, 100, 150, 210]);
  });

  test('multiplier is the combo count capped at 8', () {
    expect([for (var c = 0; c <= 12; c++) Scoring.multiplier(c)],
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 8, 8, 8]);
    expect(Scoring.multiplierCap, 8);
  });

  test('board clear bonus', () {
    expect(Scoring.boardClearPoints(true), 300);
    expect(Scoring.boardClearPoints(false), 0);
  });

  test('placement points are the cell count', () {
    expect(Scoring.placementPoints(5), 5);
  });

  test('one miss between clears keeps the combo', () {
    var combo = const ComboState(0, 0);
    combo = combo.afterPlacement(cleared: true);
    expect(combo, const ComboState(1, 0));
    combo = combo.afterPlacement(cleared: false);
    expect(combo, const ComboState(1, 1));
    combo = combo.afterPlacement(cleared: true);
    expect(combo, const ComboState(2, 0));
  });

  test('two misses reset the combo', () {
    var combo = const ComboState(0, 0).afterPlacement(cleared: true);
    combo = combo.afterPlacement(cleared: false);
    combo = combo.afterPlacement(cleared: false);
    expect(combo, const ComboState(0, 0));
  });

  test('the miss counter cycles while the combo stays at zero', () {
    var combo = const ComboState(0, 0);
    final seen = <ComboState>[];
    for (var i = 0; i < 5; i++) {
      combo = combo.afterPlacement(cleared: false);
      seen.add(combo);
    }
    expect(seen, const [
      ComboState(0, 1),
      ComboState(0, 0),
      ComboState(0, 1),
      ComboState(0, 0),
      ComboState(0, 1),
    ]);
  });
}
