import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/ui/theme/palettes.dart';

double _lin(int c) {
  final s = c / 255.0;
  return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _lin((c.r * 255).round()) +
    0.7152 * _lin((c.g * 255).round()) +
    0.0722 * _lin((c.b * 255).round());

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

List<double> _lab(Color c) {
  final r = _lin((c.r * 255).round()),
      g = _lin((c.g * 255).round()),
      b = _lin((c.b * 255).round());
  final x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
  final y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b);
  final z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// CIEDE2000, the metric `measure.js` printed for the comps.
double deltaE2000(Color c1, Color c2) {
  final l1 = _lab(c1), l2 = _lab(c2);
  const kL = 1.0, kC = 1.0, kH = 1.0;
  final cA = math.sqrt(l1[1] * l1[1] + l1[2] * l1[2]);
  final cB = math.sqrt(l2[1] * l2[1] + l2[2] * l2[2]);
  final cBar = (cA + cB) / 2;
  final g = 0.5 *
      (1 - math.sqrt(math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25, 7))));
  final a1p = (1 + g) * l1[1], a2p = (1 + g) * l2[1];
  final c1p = math.sqrt(a1p * a1p + l1[2] * l1[2]);
  final c2p = math.sqrt(a2p * a2p + l2[2] * l2[2]);
  double hp(double a, double b) {
    if (a == 0 && b == 0) return 0;
    final h = math.atan2(b, a) * 180 / math.pi;
    return h < 0 ? h + 360 : h;
  }

  final h1p = hp(a1p, l1[2]), h2p = hp(a2p, l2[2]);
  final dLp = l2[0] - l1[0];
  final dCp = c2p - c1p;
  double dhp;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else if ((h2p - h1p).abs() <= 180) {
    dhp = h2p - h1p;
  } else if (h2p - h1p > 180) {
    dhp = h2p - h1p - 360;
  } else {
    dhp = h2p - h1p + 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(dhp * math.pi / 360);
  final lBar = (l1[0] + l2[0]) / 2;
  final cBarP = (c1p + c2p) / 2;
  double hBarP;
  if (c1p * c2p == 0) {
    hBarP = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarP = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarP = (h1p + h2p + 360) / 2;
  } else {
    hBarP = (h1p + h2p - 360) / 2;
  }
  final t = 1 -
      0.17 * math.cos((hBarP - 30) * math.pi / 180) +
      0.24 * math.cos(2 * hBarP * math.pi / 180) +
      0.32 * math.cos((3 * hBarP + 6) * math.pi / 180) -
      0.20 * math.cos((4 * hBarP - 63) * math.pi / 180);
  final dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2).toDouble());
  final rC = 2 *
      math.sqrt(math.pow(cBarP, 7) / (math.pow(cBarP, 7) + math.pow(25, 7)));
  final sL = 1 +
      (0.015 * math.pow(lBar - 50, 2)) /
          math.sqrt(20 + math.pow(lBar - 50, 2));
  final sC = 1 + 0.045 * cBarP;
  final sH = 1 + 0.015 * cBarP * t;
  final rT = -math.sin(2 * dTheta * math.pi / 180) * rC;
  return math.sqrt(math.pow(dLp / (kL * sL), 2) +
      math.pow(dCp / (kC * sC), 2) +
      math.pow(dHp / (kH * sH), 2) +
      rT * (dCp / (kC * sC)) * (dHp / (kH * sH)));
}

String _hex(Color c) =>
    '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  test('twelve themes in design 7.3 slot order', () {
    expect(ThemePalette.all.map((p) => p.name).toList(), [
      'Obsidian',
      'Dawn',
      'Meadow',
      'Coral',
      'Glacier',
      'Desert',
      'Storm',
      'Lavender',
      'Ember',
      'Plum',
      'Pearl',
      'Lagoon',
    ]);
    expect(ThemePalette.all.map((p) => p.id).toSet().length, 12);
    for (final p in ThemePalette.all) {
      expect(p.blocks.length, 8, reason: p.name);
    }
  });

  test('Obsidian is exactly the styles.md table', () {
    const p = ThemePalette.obsidian;
    expect(_hex(p.ground), '#0D1016');
    expect(_hex(p.well), '#090C12');
    expect(_hex(p.empty), '#1C2230');
    expect(_hex(p.ink), '#F2F4F8');
    expect(_hex(p.muted), '#8A93A6');
    expect(_hex(p.faint), '#5B6478');
    expect(_hex(p.accent), '#F0A03A');
    expect(p.blocks.map(_hex).toList(), [
      '#E8543F',
      '#F0A03A',
      '#A9C94E',
      '#3EB98C',
      '#3AA6DE',
      '#7C7CEA',
      '#C167D6',
      '#EE7CA8',
    ]);
  });

  test('every block colour is 4.0:1 or better on its own empty cell', () {
    for (final p in ThemePalette.all) {
      for (var i = 0; i < 8; i++) {
        final c = contrast(p.blocks[i], p.empty);
        expect(c, greaterThanOrEqualTo(4.0),
            reason: '${p.name} block $i ${_hex(p.blocks[i])} on '
                '${_hex(p.empty)} is ${c.toStringAsFixed(2)}:1');
      }
    }
  });

  test('closest block pair is CIEDE2000 12 or more', () {
    for (final p in ThemePalette.all) {
      var worst = 1e9;
      var pair = '';
      for (var i = 0; i < 8; i++) {
        for (var j = i + 1; j < 8; j++) {
          final d = deltaE2000(p.blocks[i], p.blocks[j]);
          if (d < worst) {
            worst = d;
            pair = '${_hex(p.blocks[i])}/${_hex(p.blocks[j])}';
          }
        }
      }
      expect(worst, greaterThanOrEqualTo(12.0),
          reason: '${p.name} closest pair $pair is ${worst.toStringAsFixed(1)}');
    }
  });

  test('text and ground carry their own contrast, and no ground is white', () {
    for (final p in ThemePalette.all) {
      expect(contrast(p.ink, p.ground), greaterThanOrEqualTo(10.0),
          reason: '${p.name} ink');
      expect(contrast(p.muted, p.ground), greaterThanOrEqualTo(4.5),
          reason: '${p.name} muted');
      expect(contrast(p.faint, p.ground), greaterThanOrEqualTo(2.8),
          reason: '${p.name} faint');
      expect(contrast(p.accent, p.ground), greaterThanOrEqualTo(3.0),
          reason: '${p.name} accent');
      expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5),
          reason: '${p.name} onAccent');
      expect(_luminance(p.ground), lessThan(0.80), reason: '${p.name} ground');
      expect(contrast(p.empty, p.ground), lessThan(2.2),
          reason: '${p.name} empty cell must stay quiet on the ground');
      expect(p.lightGround, _luminance(p.ground) > 0.3, reason: p.name);
    }
  });
}
