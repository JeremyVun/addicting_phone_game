/// Local wall-clock time. `meta` takes a `DateTime` argument everywhere, so this
/// is the only place the app reads the real clock.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this.value);

  DateTime value;

  void advance(Duration by) => value = value.add(by);

  @override
  DateTime now() => value;
}
