import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/buckets.dart';

void main() {
  test('score buckets (design 12)', () {
    expect(Buckets.score(0), '0-499');
    expect(Buckets.score(499), '0-499');
    expect(Buckets.score(500), '500-1999');
    expect(Buckets.score(1999), '500-1999');
    expect(Buckets.score(2000), '2000-4999');
    expect(Buckets.score(4999), '2000-4999');
    expect(Buckets.score(5000), '5000-9999');
    expect(Buckets.score(9999), '5000-9999');
    expect(Buckets.score(10000), '10000+');
  });

  test('placement buckets', () {
    expect(Buckets.placements(0), '<20');
    expect(Buckets.placements(19), '<20');
    expect(Buckets.placements(20), '20-59');
    expect(Buckets.placements(59), '20-59');
    expect(Buckets.placements(60), '60-119');
    expect(Buckets.placements(119), '60-119');
    expect(Buckets.placements(120), '120+');
  });

  test('streak buckets', () {
    expect(Buckets.streak(1), '1');
    expect(Buckets.streak(2), '2-6');
    expect(Buckets.streak(6), '2-6');
    expect(Buckets.streak(7), '7-29');
    expect(Buckets.streak(29), '7-29');
    expect(Buckets.streak(30), '30+');
  });

  test('level buckets', () {
    expect(Buckets.level(2), '2-4');
    expect(Buckets.level(4), '2-4');
    expect(Buckets.level(5), '5-9');
    expect(Buckets.level(9), '5-9');
    expect(Buckets.level(10), '10-19');
    expect(Buckets.level(19), '10-19');
    expect(Buckets.level(20), '20+');
  });

  test('sinceInstall keeps day 1 and day 7 alone for retention', () {
    expect(Buckets.sinceInstall(0), '0');
    expect(Buckets.sinceInstall(1), '1');
    expect(Buckets.sinceInstall(2), '2-6');
    expect(Buckets.sinceInstall(6), '2-6');
    expect(Buckets.sinceInstall(7), '7');
    expect(Buckets.sinceInstall(8), '8-29');
    expect(Buckets.sinceInstall(29), '8-29');
    expect(Buckets.sinceInstall(30), '30+');
    expect(Buckets.sinceInstall(-3), '0', reason: 'a clock moved back');
  });
}
