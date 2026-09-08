import 'package:flutter_test/flutter_test.dart';
import 'package:settle/ui/theme/palettes.dart';

import 'palette_metrics.dart';

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
    expect(hex(p.ground), '#0D1016');
    expect(hex(p.well), '#090C12');
    expect(hex(p.empty), '#1C2230');
    expect(hex(p.ink), '#F2F4F8');
    expect(hex(p.muted), '#8A93A6');
    expect(hex(p.faint), '#5B6478');
    expect(hex(p.accent), '#F0A03A');
    expect(p.blocks.map(hex).toList(), [
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
            reason: '${p.name} block $i ${hex(p.blocks[i])} on '
                '${hex(p.empty)} is ${c.toStringAsFixed(2)}:1');
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
            pair = '${hex(p.blocks[i])}/${hex(p.blocks[j])}';
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
      expect(luminance(p.ground), lessThan(0.80), reason: '${p.name} ground');
      expect(contrast(p.empty, p.ground), lessThan(2.2),
          reason: '${p.name} empty cell must stay quiet on the ground');
      expect(p.lightGround, luminance(p.ground) > 0.3, reason: p.name);
    }
  });
}
