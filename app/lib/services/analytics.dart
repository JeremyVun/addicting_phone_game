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
