import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/rng.dart';

void main() {
  test('same seed gives the same sequence', () {
    final a = Rng(12345);
    final b = Rng(12345);
    for (var i = 0; i < 1000; i++) {
      expect(a.nextUint32(), b.nextUint32());
    }
  });

  test('different seeds diverge', () {
    final a = Rng(1);
    final b = Rng(2);
    final sa = [for (var i = 0; i < 20; i++) a.nextUint32()];
    final sb = [for (var i = 0; i < 20; i++) b.nextUint32()];
    expect(sa, isNot(sb));
  });

  test('state round trips through fromState and JSON', () {
    final a = Rng(99);
    for (var i = 0; i < 37; i++) {
      a.nextUint32();
    }
    final b = Rng.fromState(a.state);
    final c = Rng.fromJson(a.toJson());
    for (var i = 0; i < 100; i++) {
      final x = a.nextUint32();
      expect(b.nextUint32(), x);
      expect(c.nextUint32(), x);
    }
  });

  test('nextInt stays in range and covers it', () {
    final rng = Rng(7);
    final seen = <int>{};
    for (var i = 0; i < 5000; i++) {
      final v = rng.nextInt(6);
      expect(v, inInclusiveRange(0, 5));
      seen.add(v);
    }
    expect(seen.length, 6);
    expect(() => rng.nextInt(0), throwsArgumentError);
  });

  test('nextDouble is in [0,1)', () {
    final rng = Rng(3);
    var min = 1.0;
    var max = 0.0;
    for (var i = 0; i < 20000; i++) {
      final v = rng.nextDouble();
      expect(v, greaterThanOrEqualTo(0.0));
      expect(v, lessThan(1.0));
      if (v < min) min = v;
      if (v > max) max = v;
    }
    expect(min, lessThan(0.01));
    expect(max, greaterThan(0.99));
  });

  test('sequence is pinned so saved games replay across releases', () {
    final rng = Rng(2026);
    expect([for (var i = 0; i < 5; i++) rng.nextUint32()],
        [1425719730, 915299857, 1028619527, 2578754178, 2172864081]);
  });
}
