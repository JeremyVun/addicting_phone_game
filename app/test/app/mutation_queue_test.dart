import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('concurrent mutations serialise and each write sees the last', () async {
    final harness = Harness();
    await harness.start();
    harness.storage.writes.clear();

    await Future.wait([
      for (var i = 0; i < 50; i++)
        harness.controller.mutate(
          (d) => d.copyWith(profile: d.profile.copyWith(coins: d.profile.coins + 1)),
        ),
    ]);

    expect(harness.controller.profile.coins, 50);
    expect(harness.storage.writes.length, 50);
    final coinsPerWrite = [
      for (final raw in harness.storage.writes)
        ((jsonDecode(raw) as Map<String, dynamic>)['profile']
            as Map<String, dynamic>)['coins'],
    ];
    expect(coinsPerWrite, [for (var i = 1; i <= 50; i++) i]);
  });

  test('mutateWith returns the result of the same committed mutation', () async {
    final harness = Harness();
    await harness.start();
    final coins = await harness.controller.mutateWith<int>((d) {
      final profile = d.profile.copyWith(coins: 7);
      return (data: d.copyWith(profile: profile), result: profile.coins);
    });
    expect(coins, 7);
    expect(harness.controller.profile.coins, 7);
  });
}
