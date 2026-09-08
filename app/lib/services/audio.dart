import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// One sound per WAV in `app/assets/audio/`. The clear sound rises a semitone
/// per combo step (design 9.4), so each step is its own file and its own pool.
enum Sfx {
  place('place.wav', voices: 3, warm: 1),
  clear1('clear_1.wav', voices: 2, warm: 1),
  clear2('clear_2.wav', voices: 2, warm: 1),
  clear3('clear_3.wav', voices: 2),
  clear4('clear_4.wav', voices: 2),
  clear5('clear_5.wav', voices: 2),
  clear6('clear_6.wav', voices: 2),
  clear7('clear_7.wav', voices: 2),
  clear8('clear_8.wav', voices: 2),
  combo3('combo_3.wav'),
  combo5('combo_5.wav'),
  combo8('combo_8.wav'),
  boardClear('board_clear.wav'),
  gameOver('game_over.wav'),
  button('button.wav', voices: 2),
  coin('coin.wav', voices: 2),
  levelUp('level_up.wav');

  const Sfx(this.file, {this.voices = 1, this.warm = 0});

  final String file;

  /// Pool cap: how many copies may overlap.
  final int voices;

  /// Players created up front, to spend the first-play latency at preload.
  final int warm;

  /// `comboStep` is the score multiplier, 1..8.
  static Sfx clearFor(int comboStep) =>
      Sfx.values[Sfx.clear1.index + comboStep.clamp(1, 8) - 1];

  /// Null except on the combo steps design 9.4 gives a stinger.
  static Sfx? stingerFor(int comboCount) => switch (comboCount) {
        3 => Sfx.combo3,
        5 => Sfx.combo5,
        8 => Sfx.combo8,
        _ => null,
      };
}

abstract class AudioService {
  Future<void> preload();
  void play(Sfx sfx);
  void setEnabled(bool enabled);
}

class NoopAudioService implements AudioService {
  const NoopAudioService();

  @override
  Future<void> preload() async {}

  @override
  void play(Sfx sfx) {}

  @override
  void setEnabled(bool enabled) {}
}

class FlameAudioService implements AudioService {
  FlameAudioService({bool enabled = true}) : _enabled = enabled;

  static final _context =
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  final Map<Sfx, AudioPool> _pools = {};
  bool _enabled;
  Future<void>? _preloading;

  @override
  Future<void> preload() => _preloading ??= _preload();

  Future<void> _preload() async {
    for (final sfx in Sfx.values) {
      try {
        _pools[sfx] = await AudioPool.createFromAsset(
          path: sfx.file,
          audioCache: FlameAudio.audioCache,
          minPlayers: sfx.warm,
          maxPlayers: sfx.voices,
        );
      } catch (e) {
        debugPrint('sfx ${sfx.file} unavailable, silent: $e');
      }
    }
    try {
      await AudioPlayer.global.setAudioContext(_context);
    } catch (_) {
      // A missing audio backend must not take the play screen down.
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_enabled) return;
    _pools[sfx]?.start();
  }

  @override
  void setEnabled(bool enabled) => _enabled = enabled;

  Future<void> dispose() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    _pools.clear();
    _preloading = null;
  }
}
