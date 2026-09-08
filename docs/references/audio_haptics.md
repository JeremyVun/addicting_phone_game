<!-- Retrieved 2026-09-08 | flame_audio 2.12.2 / audioplayers 6.8.1 / flutter_soloud 5.0.2 / vibration 3.2.1 -->

## Sources
- https://pub.dev/packages/flame_audio (2.12.2, published ~50 days before 2026-09-08)
- https://pub.dev/documentation/flame_audio/latest/flame_audio/FlameAudio-class.html
- https://pub.dev/documentation/flame_audio/latest/flame_audio/FlameAudio/play.html
- https://pub.dev/documentation/flame_audio/latest/flame_audio/FlameAudio/audioCache.html
- https://pub.dev/documentation/flame_audio/latest/flame_audio/FlameAudio/updatePrefix.html
- https://pub.dev/documentation/flame_audio/latest/flame_audio/AudioPool-class.html
- https://docs.flame-engine.org/latest/bridge_packages/flame_audio/audio.html
- https://docs.flame-engine.org/latest/bridge_packages/flame_audio/audio_pool.html
- https://docs.flame-engine.org/latest/bridge_packages/flame_audio/bgm.html
- https://raw.githubusercontent.com/flame-engine/flame/main/packages/flame_audio/lib/flame_audio.dart
- https://raw.githubusercontent.com/flame-engine/flame/main/packages/flame_audio/lib/bgm.dart
- https://pub.dev/packages/audioplayers (6.8.1, published ~2 months before 2026-09-08)
- https://pub.dev/packages/audioplayers/changelog
- https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPlayer-class.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioCache-class.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/PlayerMode.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextConfig-class.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextConfigFocus.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextAndroid-class.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/AndroidAudioFocus.html
- https://pub.dev/documentation/audioplayers/latest/audioplayers/GlobalAudioScope-class.html
- https://pub.dev/packages/flutter_soloud (5.0.2, published 2026-09-04)
- https://pub.dev/packages/flutter_soloud/changelog
- https://github.com/alnitak/flutter_soloud
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud-class.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/init.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/loadAsset.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/play.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/loadWaveform.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/WaveForm.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/setProtectVoice.html
- https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud/setMaxActiveVoiceCount.html
- https://api.flutter.dev/flutter/services/HapticFeedback-class.html
- https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/src/services/haptic_feedback.dart
- https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/PlatformPlugin.java
- https://pub.dev/packages/vibration (3.2.1, published ~6 days before 2026-09-08)
- https://pub.dev/documentation/vibration/latest/vibration/Vibration-class.html
- https://pub.dev/documentation/vibration/latest/vibration/Vibration/vibrate.html

## flame_audio 2.12.2

Thin wrapper over audioplayers. Deps: `audioplayers: ^6.2.0`, `flame: ^1.38.0`, `synchronized: ^3.1.0`. MIT.

### Assets
- Files live in `assets/audio/`; declare in pubspec:
```yaml
flutter:
  assets:
    - assets/audio/
```
- Global cache is created with the audio prefix (released source):
```dart
static AudioCache audioCache = audioCacheFactory(prefix: 'assets/audio/');
```
  So `FlameAudio.play('jump.mp3')` resolves `assets/audio/jump.mp3`. Bare audioplayers `AudioCache` defaults to `'assets/'` instead — the two differ.
- `static void updatePrefix(String prefix)` sets `audioCache.prefix` **and** `bgm.audioPlayer.audioCache.prefix`.
- Docs recommend MP3, OGG, WAV as broadly safe formats.

### Playback
```dart
static Future<AudioPlayer> play(String file, {double volume = 1.0, AudioContext? audioContext, String? package});
static Future<AudioPlayer> loop(String file, {double volume = 1.0, AudioContext? audioContext, String? package});
static Future<AudioPlayer> playLongAudio(String file, {double volume = 1.0, AudioContext? audioContext, String? package});
static Future<AudioPlayer> loopLongAudio(String file, {double volume = 1.0, AudioContext? audioContext, String? package});
static Future<AudioPool> createPool(String sound, {required int maxPlayers, int minPlayers = 1, AudioContext? audioContext, String? package});
```
- Internally (main-branch source): `play` = `ReleaseMode.release` + `PlayerMode.lowLatency`; `loop` = `ReleaseMode.loop` + `lowLatency`; `playLongAudio`/`loopLongAudio` = `PlayerMode.mediaPlayer`.
- Default context is mix-with-others, so flame_audio does not by default steal focus from the user's music:
```dart
static final AudioContext _defaultAudioContext =
    AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
```
- Flame docs' claims (not benchmarks): `playLongAudio` "causes minor frame drop"; `loopLongAudio` has "small gaps between iterations" on Android.
- Factories overridable for tests: `static AudioCacheFactory audioCacheFactory = AudioCache.new;` `static BgmFactory bgmFactory = Bgm.new;`

### Preloading / cache
```dart
await FlameAudio.audioCache.load('jump.mp3');
await FlameAudio.audioCache.loadAll(['jump.mp3', 'pop.mp3']);
await FlameAudio.audioCache.clear('jump.mp3');   // one file
await FlameAudio.audioCache.clearAll();          // whole cache, e.g. on level switch
```
Preloading exists to remove first-play delay (asset is copied to a temp file on mobile/desktop).

### Bgm
```dart
class Bgm extends WidgetsBindingObserver {
  Bgm({AudioCache? audioCache});
  Future<void> initialize({AudioContext? audioContext});
  Future<void> dispose();
  Future<void> play(String fileName, {double volume = 1, String? package});
  Future<void> stop();
  Future<void> resume();
  Future<void> pause();
  void didChangeAppLifecycleState(AppLifecycleState state);
}
```
- Lifecycle handling is **explicit but automatic once wired**: `Bgm` is itself the `WidgetsBindingObserver`. You must call `FlameAudio.bgm.initialize()` (registers observer; requires an existing `WidgetsBinding` instance — do it in `onLoad`, not in a top-level field initializer) and `FlameAudio.bgm.dispose()` (removes the observer). After that, background/foreground pause+resume is handled for you.
- `pause()` marks it manually paused so lifecycle resume will not un-pause it.
- Uses `FlameAudio`'s static `AudioCache` unless you construct `Bgm(audioCache: ...)`.

### AudioPool
```dart
static Future<AudioPool> create({
  required Source source,
  required int maxPlayers,
  AudioCache? audioCache,
  AudioContext? audioContext,
  int minPlayers = 1,
  PlayerMode playerMode = PlayerMode.mediaPlayer,
});

static Future<AudioPool> createFromAsset({
  required String path,
  required int maxPlayers,
  AudioCache? audioCache,
  int minPlayers = 1,
  PlayerMode playerMode = PlayerMode.mediaPlayer,
});

Future<StopFunction> start({double volume = 1.0});
Future<void> dispose();
```
```dart
final pool = await FlameAudio.createPool('pop.mp3', minPlayers: 3, maxPlayers: 6);
final stop = await pool.start(volume: 0.8);
await stop(); // early termination
```
- `minPlayers`: players pre-created at init. `maxPlayers`: cap kept in the pool; beyond it, extra players are created on demand and released rather than retained.
- Why it matters: one `AudioPlayer` plays one sound at a time and re-`play()` on a busy player restarts it. Rapid overlapping SFX (taps, pops, combo chains) need N players; the pool recycles finished players so you avoid per-shot allocation + reload latency.
- Pool default `playerMode` is `mediaPlayer`, not `lowLatency` — pass `playerMode:` via `AudioPool.createFromAsset` if you want low latency (`FlameAudio.createPool` exposes no playerMode param).

## audioplayers 6.8.1

### Core
```dart
final player = AudioPlayer();                    // one sound at a time per instance
await player.play(AssetSource('audio/pop.mp3')); // sets source + resumes
await player.setSource(AssetSource('audio/pop.mp3')); // preload without playing
await player.resume(); await player.pause(); await player.stop();
await player.seek(const Duration(milliseconds: 250));
await player.setVolume(0.5);        // 0.0..1.0
await player.setPlaybackRate(1.0);
await player.setBalance(0.0);       // -1 left .. 1 right
await player.release();             // free native resources, keep instance
await player.dispose();             // permanent
```
- Sources: `AssetSource('x.mp3')` (relative to `AudioCache.prefix`, default `'assets/'`), `UrlSource('https://…')`, `DeviceFileSource('/path')`, `BytesSource(uint8list)`.
- Convenience setters: `setSourceAsset`, `setSourceUrl`, `setSourceDeviceFile`, `setSourceBytes` (UNVERIFIED exact param lists beyond the first positional).

### Release mode
```dart
await player.setReleaseMode(ReleaseMode.loop);    // loop forever
await player.setReleaseMode(ReleaseMode.stop);    // stop at end, keep resources
await player.setReleaseMode(ReleaseMode.release); // stop and free native resources at end
```
`ReleaseMode.release` on desktop platforms landed in 6.2.0.

### Player mode
```dart
await player.setPlayerMode(PlayerMode.lowLatency);
```
Docs state, for `lowLatency`: intended for short clips, minimizes impact on UI responsiveness, but "the backend won't fire any duration, position or playback completion events" (you are responsible for stopping) and "it is not possible to use the seek method to set the audio to a specific position". `PlayerMode.mediaPlayer` is for long audio/streaming and keeps all events. The docs do not publish latency numbers — no measured ms claim exists upstream.

### Events
```dart
player.onPlayerComplete.listen((_) { /* next track */ });
player.onPositionChanged.listen((Duration p) {});
player.onDurationChanged.listen((Duration d) {});
player.onPlayerStateChanged.listen((PlayerState s) {});
player.onSeekComplete.listen((_) {});
```

### AudioCache
```dart
final cache = AudioCache(prefix: 'assets/audio/');
await cache.load('pop.mp3');
await cache.loadAll(['pop.mp3', 'win.mp3']);
await cache.clear('pop.mp3');
await cache.clearAll();
AudioCache.instance; // global default used by AssetSource
```
Constructor default `prefix: 'assets/'`; assets are copied to a temp folder on mobile/desktop, fetched via GET on web.

### Audio focus / not killing the user's music
```dart
final ctx = AudioContextConfig(
  focus: AudioContextConfigFocus.mixWithOthers, // gain | duckOthers | mixWithOthers
  respectSilence: false,
  stayAwake: false,
  route: AudioContextConfigRoute.system,
).build();
await AudioPlayer.global.setAudioContext(ctx);   // global default
await player.setAudioContext(ctx);               // per-player
```
- `AudioContextConfigFocus.gain` → `AndroidAudioFocus.gain` (you become sole audio source; other apps stop).
- `duckOthers` → `AndroidAudioFocus.gainTransientMayDuck` (their music continues quieter).
- `mixWithOthers` → `AndroidAudioFocus.none` (nothing stops; use this for a casual game so Spotify keeps playing).
- Fine control:
```dart
const AudioContextAndroid(
  isSpeakerphoneOn: false,
  audioMode: AndroidAudioMode.normal,
  stayAwake: false,
  contentType: AndroidContentType.music,   // music | sonification | speech | movie | unknown
  usageType: AndroidUsageType.media,       // media | game | notification | alarm | ...
  audioFocus: AndroidAudioFocus.none,
);
```
  (`AndroidContentType`/`AndroidUsageType` value lists beyond `music`/`media` are UNVERIFIED here — check the enum pages before using an exotic one.)
- `AudioPlayer.global` is a `GlobalAudioScope`: `ensureInitialized()`, `setAudioContext(AudioContext)`, `eventStream`, `onLog`.

### 6.x breaking changes vs 5.x (from changelog)
- Removed all previously deprecated methods.
- `AudioContextConfig.duckAudio` replaced by `AudioContextConfig.focus` (`AudioContextConfigFocus`).
- `AudioContextIOS` restructured.
- `ForPlayer<>` generic wrapper removed.
- Position updates reworked: `FramePositionUpdater` / `TimerPositionUpdater`.
- Minimum Flutter bumped to 3.13.0.
Later 6.x notables: 6.2.0 `ReleaseMode.release` on desktop + `AudioContext` in `AudioPool`; 6.3.0 optional ExoPlayer/Media3 backend on Android; 6.4.0 players dispose on hot restart; 6.5.0 configurable prepare/seek timeouts; 6.6.0 `PlayerMode` for AudioPools; 6.7.0 cache existence checks; 6.8.0 C++23 + Kotlin compat; 6.8.1 fixes a `StateError` during player preparation.

## flutter_soloud 5.0.2

Dart/Flutter binding to the SoLoud C++ engine. Android minSdk 21+, iOS 13.0+, web needs Chrome/Edge 91+ or Safari 16.4+. Since 5.0.0 native builds go through **Dart build hooks** (`package:hooks` + `package:native_toolchain_c`) — no CMake/CocoaPods plumbing on your side. (The changelog does not state a minimum Flutter version for build hooks — verify against your Flutter channel; UNVERIFIED.)

### Lifecycle
```dart
final soloud = SoLoud.instance;
await soloud.init(
  // PlaybackDevice? device,
  // bool automaticCleanup = false,
  // int sampleRate = 44100,
  // int bufferSize = 2048,
  // Channels channels = Channels.stereo,
  // bool lowLatency = true,
  // AndroidAAudioAttributes androidAAudioAttributes = AndroidAAudioAttributes.mediaMusic,
  // int? devicePeriodFrames, int? renderAheadFrames,
);
...
soloud.deinit();        // stops engine, disposes everything
// deinitAsync() also exists (non-blocking)
```
Every other call before init completes throws `SoLoudNotInitializedException`. Smaller `bufferSize` = lower latency, higher underrun risk (docs' words, no ms figures published).

### Loading + playing
```dart
Future<AudioSource> loadAsset(String key, {LoadMode mode = LoadMode.memory, AssetBundle? assetBundle, bool autoDispose = false});
// loadFile(...) (not on web), loadMem(...) for in-memory bytes

SoundHandle play(
  AudioSource sound, {
  int busId = 0,
  double volume = 1,
  double pan = 0,
  bool paused = false,
  bool looping = false,
  Duration loopingStartAt = Duration.zero,
  Duration? loopingEndAt,
  int? loopingStartOffsetAt,
  int? loopingEndOffsetAt,
  double scale = 1,     // playback speed
});
```
- `play()` is **synchronous** and returns a `SoundHandle` = one playing voice. Loading is async and done once; playing is cheap and repeatable.
- `playSource(...)` is a convenience load+play (exact signature UNVERIFIED).
- `playClocked` / `playScheduled` give sample-accurate timing; `play3d*` variants give positional audio with Doppler.
- Note `loadAsset` takes the **full** asset key (`'assets/audio/pop.mp3'`), unlike flame_audio's prefixed short name.

### Voices
```dart
soloud.setVolume(handle, 0.6);
soloud.stop(handle);
await soloud.disposeSource(source);        // stops all its voices and unloads
soloud.setProtectVoice(handle, true);      // exempt from culling when voices are capped
soloud.setMaxActiveVoiceCount(24);         // default 16, hard max 1023 (pool is 1024)
soloud.getMaxActiveVoiceCount(); soloud.getActiveVoiceCount(); soloud.getVoiceCount();
soloud.countAudioSource(source);
```
Over the cap, SoLoud plays the loudest voices and drops the rest; protected voices count toward the cap but are never culled. `setMaxActiveVoiceCount(0)` or `>1023` is silently ignored.

### Waveforms / synth (real API)
```dart
Future<AudioSource> loadWaveform(WaveForm waveform, bool superWave, double scale, double detune);
// then, per source:
setWaveform(...); setWaveformFreq(...); setWaveformScale(...); setWaveformDetune(...);
```
`WaveForm` values: `square`, `saw`, `sin`, `triangle`, `bounce`, `jaws`, `humps`, `fSquare`, `fSaw`. (`fSquare`/`fSaw` = Fourier variants, "less noisy".) Exact param lists of the four `setWaveform*` setters are UNVERIFIED — check the per-method dartdoc before wiring a synth layer. `speechText()` exists for TTS-style generated audio.

### Effects / analysis
- `soloud.filters` — global filter access; built-ins include reverb, echo, equalizer, pitch shift.
- Mixing buses for grouping; faders for volume/pan ramps.
- 5.0.0 replaced polled `AudioData` with `SoLoud.instance.audioVisualizationEvents` streaming `AudioVisualizationData` (FFT + waveform).

### 5.0.0 breaking changes
- Web loader renamed → `web/index.html` must reference `assets/packages/flutter_soloud/web/init_soloud.js`.
- `NO_XIPH_LIBS` env var replaced by pubspec config:
```yaml
hooks:
  user_defines:
    flutter_soloud:
      no_xiph_libs: true
```
- Visualization API replaced (see above).
- Build migrated to Dart build hooks.

## Haptics (flutter/services)

```dart
static Future<void> vibrate();
static Future<void> lightImpact();
static Future<void> mediumImpact();
static Future<void> heavyImpact();
static Future<void> selectionClick();
```
Android mapping, straight from `PlatformPlugin.vibrateHapticFeedback` (calls `view.performHapticFeedback(constant)` with **no** flags):

| Dart | Android constant | Notes |
|---|---|---|
| `vibrate()` | `HapticFeedbackConstants.LONG_PRESS` | iOS: `kSystemSoundID_Vibrate` |
| `lightImpact()` | `VIRTUAL_KEY` | iOS: `UIImpactFeedbackStyleLight` |
| `mediumImpact()` | `KEYBOARD_TAP` | iOS: `UIImpactFeedbackStyleMedium` |
| `heavyImpact()` | `CONTEXT_CLICK` | API 23+; no-op below 23 |
| `selectionClick()` | `CLOCK_TICK` | iOS: `UISelectionFeedbackGenerator` |

- Flutter master additionally has `successNotification()` (`CONFIRM`), `warningNotification()` (`KEYBOARD_TAP`), `errorNotification()` (`REJECT`), all API 30+. They are **not** on the published stable API page as of 2026-09-08 — treat as unavailable unless your Flutter version's dartdoc lists them.
- Because no `FLAG_IGNORE_VIEW_SETTING` / `FLAG_IGNORE_GLOBAL_SETTING` is passed, the OS honours the user's "touch feedback / haptics" setting: calls are silently no-ops when the user has haptics off (or on devices with weak/absent haptic support). Never gate game logic on the future completing meaningfully — it resolves regardless.
- `View.performHapticFeedback` does **not** require the `VIBRATE` permission, and Flutter's framework manifest does not declare one for it. Flutter's tooling only injects `android.permission.INTERNET` (debug/profile manifests). So plain `HapticFeedback.*` needs no manifest edit; the moment you add the `vibration` package you need the permission. (The "Flutter implicit manifest already contains VIBRATE" claim circulating online is UNVERIFIED and appears false — the permission comes from plugins that declare it.)

## vibration 3.2.1

```dart
static Future<bool> hasVibrator();
static Future<bool> hasAmplitudeControl();          // Android 8.0+
static Future<bool> hasCustomVibrationsSupport();   // custom duration/pattern/intensity
static Future<void> vibrate({
  int duration = 500,            // ms
  List<int> pattern = const [],  // [wait, vibrate, wait, vibrate, ...]
  int repeat = -1,               // index into pattern to loop from; -1 = no repeat
  List<int> intensities = const [],
  int amplitude = -1,            // 1..255, -1 = device default
  double sharpness = 0.5,        // iOS CoreHaptics only
  VibrationPreset? preset,       // overrides the other params
});
static Future<void> cancel();
```
Manifest (verbatim, inside `<manifest>`, above `<application>`):
```xml
<uses-permission android:name="android.permission.VIBRATE"/>
```
- `pattern` + `intensities` need `hasCustomVibrationsSupport()`; `amplitude` needs `hasAmplitudeControl()` (else it is ignored and you get the default strength).
- Android 8+ uses `VibrationEffect`; older uses the legacy `Vibrator` API. iOS without CoreHaptics falls back to a fixed ~500ms buzz.
- BSD-2-Clause. `sharpness`/`preset` are recent additions — pin the version if you use them.

## Which to use

- **SFX, few overlapping sounds, already on Flame** → `flame_audio` + `AudioPool` per sound (`minPlayers` ≈ expected simultaneous instances). Zero native setup, ships with the engine.
- **Music/BGM** → `FlameAudio.bgm` (lifecycle observer for free) or a dedicated `AudioPlayer` with `ReleaseMode.loop` + `PlayerMode.mediaPlayer`. Never `lowLatency` for music.
- **Raw audioplayers (no Flame)** → same thing without the prefix/pool sugar; you own pooling.
- **flutter_soloud when**: you need many simultaneous voices with a real voice-culling policy (`setMaxActiveVoiceCount`, `setProtectVoice`), pitch/speed per instance (`scale:`), gapless loop regions, sample-accurate scheduling, runtime effects (reverb/echo/EQ/pitch), FFT-driven visuals, 3D positional audio, or procedurally generated tones (`loadWaveform`). audioplayers offers none of these.
- Neither project publishes latency benchmarks. audioplayers only claims `lowLatency` is "for short audio files" and minimizes UI impact (at the cost of events + seek); flutter_soloud claims "low-latency" via a native mixer with a configurable `bufferSize`. Any "soloud is X ms faster" number is UNVERIFIED — measure on target hardware.
- **Haptics**: `HapticFeedback` for standard UI-scale taps (no permission, respects user setting, cheap). Add `vibration` only when you need durations, patterns, amplitude ramps or long rumbles — and accept the manifest permission plus capability checks.
- Mixing soloud and audioplayers in one app is possible but means two audio engines competing for Android audio focus — pick one for gameplay audio.

## Gotchas

- **Two different prefixes.** `FlameAudio.audioCache` is created with `prefix: 'assets/audio/'`, but a bare `AudioCache()`/`AssetSource` defaults to `'assets/'`. Mixing flame_audio and raw audioplayers in one app gives "asset not found" on whichever path you got wrong. `FlameAudio.updatePrefix()` changes both flame caches at once.
- **`PlayerMode.lowLatency` silently disables `onPlayerComplete`, position/duration events and `seek`.** `FlameAudio.play()`/`loop()` use it. If you were waiting on completion to chain audio or free a player, it never fires — you must stop it yourself. Use `playLongAudio` / `mediaPlayer` when you need events.
- **Audio focus defaults differ.** flame_audio defaults to `mixWithOthers` (the user's music keeps playing), a raw `AudioPlayer` does not — a plain audioplayers setup can kill the player's Spotify. Set `AudioPlayer.global.setAudioContext(AudioContextConfig(focus: ...).build())` explicitly at startup.
- `FlameAudio.bgm.initialize()` must run after `WidgetsBinding` exists (do it in `onLoad`), and `dispose()` must run or the lifecycle observer leaks. Without `initialize()` you get no background pause/resume.
- One `AudioPlayer` = one sound. Calling `play()` again restarts the current sound instead of layering. Rapid SFX needs `AudioPool` (or soloud voices).
- `FlameAudio.createPool` has no `playerMode` param and pools default to `PlayerMode.mediaPlayer`; use `AudioPool.createFromAsset(playerMode: PlayerMode.lowLatency, ...)` if you want the low-latency path.
- soloud: forgetting `disposeSource` leaks native memory; `autoDispose: true` on `loadAsset` only fires after all handles stop. Over `maxActiveVoiceCount` (default 16) new sounds are dropped by loudness — protect the ones that matter.
- soloud 5.x web needs the renamed `init_soloud.js` in `index.html`; a 4.x `index.html` fails silently on web.
- `HapticFeedback.heavyImpact()` is a no-op below API 23, and *all* haptics are no-ops when the user turned touch feedback off. Do not use haptics as the sole feedback channel for a game event.
- `vibration`: `amplitude`/`intensities`/`pattern` are silently ignored on devices lacking support — gate on `hasAmplitudeControl()` / `hasCustomVibrationsSupport()` or your "subtle" tick becomes a full-strength 500ms buzz.
