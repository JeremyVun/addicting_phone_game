import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../config.dart';

abstract class AnalyticsService {
  void count(String event, [Map<String, String> dims]);
}

class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  void count(String event, [Map<String, String> dims = const {}]) {}
}

class AnalyticsEvent {
  const AnalyticsEvent(this.name, this.dims);

  final String name;
  final Map<String, String> dims;

  @override
  String toString() => dims.isEmpty ? name : '$name $dims';
}

class RecordingAnalytics implements AnalyticsService {
  final List<AnalyticsEvent> events = [];

  Iterable<AnalyticsEvent> named(String name) =>
      events.where((e) => e.name == name);

  @override
  void count(String event, [Map<String, String> dims = const {}]) =>
      events.add(AnalyticsEvent(event, dims));
}

abstract class AnalyticsTransport {
  Future<void> send(Uri url, Map<String, String> headers, String body);
}

class HttpAnalyticsTransport implements AnalyticsTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  @override
  Future<void> send(Uri url, Map<String, String> headers, String body) async {
    final request = await _client.postUrl(url);
    headers.forEach(request.headers.set);
    request.add(utf8.encode(body));
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode >= 300) {
      throw HttpException('${response.statusCode} from $url');
    }
  }
}

/// Batched fire-and-forget POSTs to the shared analytics service. Never throws,
/// never blocks a caller, and drops rather than retries.
class HttpAnalytics implements AnalyticsService {
  HttpAnalytics({
    required this.baseUrl,
    required this.apiKey,
    required Future<String> Function() unitId,
    AnalyticsTransport? transport,
    this.batchSize = 50,
    this.flushThreshold = 20,
    this.interval = const Duration(seconds: 10),
    this.queueCap = 500,
    bool observeLifecycle = true,
  }) : _unitId = unitId,
       _transport = transport ?? HttpAnalyticsTransport() {
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onPause: () => unawaited(flush()));
    }
  }

  static AnalyticsService fromEnvironment({
    required Future<String> Function() unitId,
  }) => kAnalyticsUrl.isEmpty
      ? const NoopAnalytics()
      : HttpAnalytics(
          baseUrl: kAnalyticsUrl,
          apiKey: kAnalyticsKey,
          unitId: unitId,
        );

  final String baseUrl;
  final String apiKey;
  final int batchSize;
  final int flushThreshold;
  final int queueCap;
  final Duration interval;

  final Future<String> Function() _unitId;
  final AnalyticsTransport _transport;
  final List<Map<String, Object>> _queue = [];
  final String _sessionId = _randomId();

  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  String _unit = '';
  bool _sending = false;

  @override
  void count(String event, [Map<String, String> dims = const {}]) {
    if (_queue.length >= queueCap) _queue.removeAt(0);
    _queue.add({
      'p': kAnalyticsProject,
      't': event,
      'sid': _sessionId,
      if (dims.isNotEmpty) 'd': dims,
    });
    if (_queue.length >= flushThreshold) {
      unawaited(flush());
      return;
    }
    _timer ??= Timer(interval, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    try {
      // The profile does not exist yet at bootstrap, so the id is resolved late.
      if (_unit.isEmpty) _unit = await _unitId();
      while (_queue.isNotEmpty) {
        final batch = _queue.take(batchSize).toList();
        _queue.removeRange(0, batch.length);
        await _transport.send(
          Uri.parse('$baseUrl/e'),
          {
            'content-type': 'application/json',
            if (apiKey.isNotEmpty) 'X-Analytics-Key': apiKey,
          },
          jsonEncode([
            for (final event in batch)
              if (_unit.isEmpty) event else {...event, 'u': _unit},
          ]),
        );
      }
    } catch (error) {
      debugPrint('analytics: dropped ${_queue.length} queued events: $error');
      _queue.clear();
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
  }

  static String _randomId() {
    final random = Random();
    return List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
