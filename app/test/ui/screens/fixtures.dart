import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/day_ordinal.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/services/storage.dart';
import 'package:settle/ui/app.dart';

import '../../app/harness.dart';

final DateTime fixtureNow = DateTime(2026, 9, 8, 12);
final int fixtureOrdinal = dayOrdinalOf(fixtureNow);

String envelope({required PlayerProfile profile}) =>
    jsonEncode(AppData(profile: profile).toJson());

Future<void> pumpScreen(
  WidgetTester tester,
  Harness harness,
  Widget child,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: settleTheme(harness.controller.palette),
      home: Scaffold(body: child),
    ),
  );
}
