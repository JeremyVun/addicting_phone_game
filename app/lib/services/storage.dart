import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/game_state.dart' as core;
import '../meta/meta.dart';

/// The whole persisted app state (design 4). Written as one string so a crash
/// can never leave two keys disagreeing.
class AppData {
  const AppData({required this.profile, this.savedGame, this.lastResult});

  static const int version = 1;

  final PlayerProfile profile;
  final core.GameState? savedGame;
  final LastGameResult? lastResult;

  AppData copyWith({
    PlayerProfile? profile,
    core.GameState? savedGame,
    LastGameResult? lastResult,
    bool clearSavedGame = false,
    bool clearLastResult = false,
  }) => AppData(
    profile: profile ?? this.profile,
    savedGame: clearSavedGame ? null : (savedGame ?? this.savedGame),
    lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
  );

  Map<String, dynamic> toJson() => {
    'v': version,
    'profile': profile.toJson(),
    'savedGame': savedGame?.toJson(),
    'lastResult': lastResult?.toJson(),
  };

  static AppData fromJson(Map<String, dynamic> json) {
    final v = json['v'] as int;
    if (v != version) {
      throw FormatException('unsupported AppData version $v');
    }
    final game = json['savedGame'] as Map<String, dynamic>?;
    final result = json['lastResult'] as Map<String, dynamic>?;
    return AppData(
      profile: PlayerProfile.fromJson(json['profile'] as Map<String, dynamic>),
      savedGame: game == null ? null : core.GameState.fromJson(game),
      lastResult: result == null ? null : LastGameResult.fromJson(result),
    );
  }
}

abstract class Storage {
  Future<AppData?> load();
  Future<void> save(AppData data);
}

class SharedPreferencesStorage implements Storage {
  SharedPreferencesStorage([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const String key = 'settle.appdata.v1';

  final SharedPreferencesAsync _prefs;

  @override
  Future<AppData?> load() async {
    final raw = await _prefs.getString(key);
    if (raw == null) return null;
    return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppData data) =>
      _prefs.setString(key, jsonEncode(data.toJson()));
}

class MemoryStorage implements Storage {
  MemoryStorage([this._raw]);

  String? _raw;
  final List<String> writes = [];

  @override
  Future<AppData?> load() async => _raw == null
      ? null
      : AppData.fromJson(jsonDecode(_raw!) as Map<String, dynamic>);

  @override
  Future<void> save(AppData data) async {
    _raw = jsonEncode(data.toJson());
    writes.add(_raw!);
  }
}
