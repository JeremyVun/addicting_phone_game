/// PCG32 with a fixed stream. `dart:math`'s Random is not specified to give the
/// same sequence across platforms, and saved games must replay identically.
class Rng {
  Rng(int seed) : _state = 0 {
    _step();
    _state += seed;
    _step();
  }

  Rng.fromState(this._state);

  factory Rng.fromJson(Map<String, dynamic> json) =>
      Rng.fromState(json['state'] as int);

  static const int _multiplier = 6364136223846793005;
  static const int _increment = 1442695040888963407;
  static const int _mask32 = 0xFFFFFFFF;
  static const double _twoPow32 = 4294967296.0;

  int _state;

  int get state => _state;

  void _step() {
    _state = _state * _multiplier + _increment;
  }

  int nextUint32() {
    final old = _state;
    _step();
    final xorshifted = (((old >>> 18) ^ old) >>> 27) & _mask32;
    final rot = (old >>> 59) & 31;
    return ((xorshifted >>> rot) | (xorshifted << (32 - rot))) & _mask32;
  }

  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    final threshold = (0x100000000 - max) % max;
    while (true) {
      final r = nextUint32();
      if (r >= threshold) return r % max;
    }
  }

  double nextDouble() => nextUint32() / _twoPow32;

  Map<String, dynamic> toJson() => {'state': _state};

  Rng clone() => Rng.fromState(_state);

  @override
  bool operator ==(Object other) => other is Rng && other._state == _state;

  @override
  int get hashCode => _state.hashCode;
}
