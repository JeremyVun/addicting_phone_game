import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/services/analytics.dart';

class RecordingTransport implements AnalyticsTransport {
  RecordingTransport({this.fails = false});

  bool fails;
  final List<(Uri, Map<String, String>, List<dynamic>)> sent = [];

  @override
  Future<void> send(Uri url, Map<String, String> headers, String body) async {
    if (fails) throw const FormatException('network down');
    sent.add((url, headers, jsonDecode(body) as List<dynamic>));
  }
}

void main() {
  late RecordingTransport transport;

  HttpAnalytics build({
    int flushThreshold = 20,
    int batchSize = 50,
    Future<String> Function()? unitId,
  }) => HttpAnalytics(
    baseUrl: 'https://analytics.example',
    apiKey: 'k',
    unitId: unitId ?? () async => 'unit-7',
    transport: transport,
    flushThreshold: flushThreshold,
    batchSize: batchSize,
    interval: const Duration(milliseconds: 10),
    observeLifecycle: false,
  );

  setUp(() => transport = RecordingTransport());

  test('posts to /e with the key, project, unit and session', () async {
    final analytics = build();
    analytics.count('game_started', {'mode': 'classic'});
    await analytics.flush();
    final (url, headers, body) = transport.sent.single;
    expect(url.toString(), 'https://analytics.example/e');
    expect(headers['X-Analytics-Key'], 'k');
    final event = body.single as Map<String, dynamic>;
    expect(event['p'], 'settle');
    expect(event['t'], 'game_started');
    expect(event['u'], 'unit-7');
    expect(event['d'], {'mode': 'classic'});
    expect(event['sid'], isA<String>());
    analytics.dispose();
  });

  test('a session id is stable within a launch', () async {
    final analytics = build();
    analytics
      ..count('a')
      ..count('b');
    await analytics.flush();
    final body = transport.sent.single.$3.cast<Map<String, dynamic>>();
    expect(body.first['sid'], body.last['sid']);
    analytics.dispose();
  });

  test('flushes on the queued-event threshold', () async {
    final analytics = build(flushThreshold: 3);
    analytics
      ..count('a')
      ..count('b');
    await pumpEventQueue();
    expect(transport.sent, isEmpty);
    analytics.count('c');
    await pumpEventQueue();
    expect(transport.sent.single.$3, hasLength(3));
    analytics.dispose();
  });

  test('flushes on the interval', () async {
    final analytics = build();
    analytics.count('a');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(transport.sent.single.$3, hasLength(1));
    analytics.dispose();
  });

  test('splits into batches of at most batchSize', () async {
    final analytics = build(flushThreshold: 1000, batchSize: 2);
    for (var i = 0; i < 5; i++) {
      analytics.count('e$i');
    }
    await analytics.flush();
    expect(transport.sent.map((s) => s.$3.length), [2, 2, 1]);
    analytics.dispose();
  });

  test('a failing transport drops instead of throwing', () async {
    transport.fails = true;
    final analytics = build();
    analytics.count('a');
    await analytics.flush();
    expect(transport.sent, isEmpty);
    transport.fails = false;
    await analytics.flush();
    expect(transport.sent, isEmpty);
    analytics.dispose();
  });

  test('a throwing unit id resolver does not break the flush', () async {
    final analytics = build(unitId: () async => throw StateError('no profile'));
    analytics.count('a');
    await analytics.flush();
    expect(transport.sent, isEmpty);
    analytics.dispose();
  });

  test('an unresolved unit id is retried at the next flush', () async {
    var calls = 0;
    final analytics = build(
      unitId: () async => calls++ == 0 ? '' : 'unit-late',
    );
    analytics.count('a');
    await analytics.flush();
    expect(transport.sent.single.$3.single, isNot(contains('u')));
    analytics.count('b');
    await analytics.flush();
    expect(
      (transport.sent.last.$3.single as Map<String, dynamic>)['u'],
      'unit-late',
    );
    analytics.dispose();
  });

  test('n rides the wire only when it is not 1', () async {
    final analytics = build();
    analytics
      ..count('a')
      ..countN('b', 1)
      ..countN('c', 12000, {'source': 'rewarded'});
    await analytics.flush();
    final body = transport.sent.single.$3.cast<Map<String, dynamic>>();
    expect(body[0], isNot(contains('n')));
    expect(body[1], isNot(contains('n')));
    expect(body[2]['n'], 12000);
    expect(body[2]['d'], {'source': 'rewarded'});
    analytics.dispose();
  });

  test('RecordingAnalytics records n, defaulting to 1', () {
    final analytics = RecordingAnalytics()
      ..count('a')
      ..countN('b', 990000, {'source': 'iap'});
    expect(analytics.named('a').single.n, 1);
    final revenue = analytics.named('b').single;
    expect(revenue.n, 990000);
    expect(revenue.dims, {'source': 'iap'});
  });

  test('count never blocks the caller', () {
    final analytics = build(flushThreshold: 1);
    expect(() => analytics.count('a'), returnsNormally);
    analytics.dispose();
  });
}
