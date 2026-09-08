import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/screens/shop_screen.dart';
import 'package:settle/ui/strings.dart';

import '../../app/harness.dart';

Widget wrap(AppController controller) =>
    MaterialApp(home: ShopScreen(controller: controller));

void main() {
  testWidgets('renders every product with its store price', (tester) async {
    final harness = Harness();
    await harness.start();
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(S.shopRemoveAds), findsOneWidget);
    expect(find.text(S.shopRemoveAdsSub), findsOneWidget);
    expect(find.text(S.shopCoinsSmall), findsOneWidget);
    expect(find.text(S.shopCoinsMedium), findsOneWidget);
    expect(find.text(S.shopCoinsLarge), findsOneWidget);
    expect(find.text(S.shopAllThemes), findsOneWidget);
    expect(find.text(S.shopAllThemesSub), findsOneWidget);
    expect(find.text(r'$3.99'), findsOneWidget);
    expect(find.text(S.shopRestore), findsOneWidget);
  });

  testWidgets('an empty catalogue shows the unavailable state', (tester) async {
    final harness = Harness();
    await harness.start();
    harness.purchases.catalogueIsEmpty = true;
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(S.shopUnavailable), findsOneWidget);
    expect(find.text(S.shopRemoveAds), findsNothing);
  });

  testWidgets('a purchase in flight shows the pending state', (tester) async {
    final harness = Harness();
    await harness.start();
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.shopCoinsSmall));
    await tester.pump();
    expect(find.text(S.shopPending), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text(S.shopPending), findsNothing);
  });

  testWidgets('an owned non-consumable shows as purchased', (tester) async {
    final harness = Harness();
    await harness.start();
    await harness.controller.applyPurchase(Products.removeAds, 'tok');
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(S.shopPurchased), findsOneWidget);
  });

  testWidgets('restore reports back on the message line', (tester) async {
    final harness = Harness();
    await harness.start();
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.shopRestore));
    await tester.pumpAndSettle();
    expect(find.text(S.shopRestored), findsOneWidget);
  });
}
