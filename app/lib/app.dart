import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'bootstrap.dart';
import 'core/day_ordinal.dart';
import 'core/game.dart' as core;
import 'core/game_state.dart' as core;
import 'meta/meta.dart';
import 'navigator.dart';
import 'services/ads.dart';
import 'services/purchases.dart';
import 'services/storage.dart';
import 'ui/play/play_host.dart';
import 'ui/strings.dart';
import 'ui/theme/palettes.dart';

part 'app_daily.dart';
part 'app_shop.dart';

enum ContinuePayment { rewarded, coins, free }

class AppController extends ChangeNotifier
    implements PlayHost, PurchaseSink, AdSink {
  AppController(this.services);

  final AppServices services;

  AppNavigator navigator = const NoopNavigator();

  late AppData _data;
  Future<void> _queue = Future<void>.value();
  int _elapsedAtResume = 0;
  int _resumedAtMs = 0;

  /// `finishGame` deletes `savedGame`, but the play screen is still mounted
  /// under the result sheet and must keep drawing the board it ended on.
  core.GameState? _finishedGame;

  AppData get data => _data;

  /// Completes when every queued mutation has been written.
  Future<void> get idle => _queue;
  PlayerProfile get profile => _data.profile;
  core.GameState? get currentGame => _data.savedGame;
  LastGameResult? get lastResult => _data.lastResult;

  // ---- mutation queue (design 4) ----

  Future<AppData> mutate(AppData Function(AppData) fn) =>
      mutateWith<AppData>((d) {
        final next = fn(d);
        return (data: next, result: next);
      });

  Future<T> mutateWith<T>(({AppData data, T result}) Function(AppData) fn) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        final out = fn(_data);
        _data = out.data;
        await services.storage.save(out.data);
        notifyListeners();
        completer.complete(out.result);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  // ---- launch ----

  Future<void> start() async {
    final loaded = await services.storage.load();
    final now = services.clock.now();
    _data =
        loaded ??
        AppData(
          profile: PlayerProfile.initial(
            analyticsUnitId: _randomUnitId(),
            now: now,
          ),
        );
    await mutate((d) {
      var profile = Streaks.reconcile(d.profile, now);
      profile = InterstitialPolicy.reconcileClock(profile, now);
      final saved = d.savedGame;
      final stale =
          saved != null &&
          saved.mode == core.GameMode.daily &&
          saved.dayOrdinal != dayOrdinalOf(now);
      return AppData(
        profile: profile,
        savedGame: stale ? null : saved,
        lastResult: d.lastResult,
      );
    });
    final game = _data.savedGame;
    if (game != null) _markResumed(game);
    services.purchases.start(this);
    services.ads.start(this);
    services.analytics.count('session_started', {'first': '${loaded == null}'});
  }

  /// What the first frame should show (design 6.1: a pending result reopens its
  /// sheet, a saved game resumes).
  void resumeFromLaunch() {
    if (_data.lastResult != null) {
      navigator.showGameOver();
      return;
    }
    final game = _data.savedGame;
    if (game == null) return;
    navigator.goPlay();
    if (game.status == core.GameStatus.over) navigator.showGameOver();
  }

  // ---- game lifecycle ----

  Future<void> startClassic() async {
    await mutate(
      (d) => AppData(
        profile: d.profile,
        savedGame: _newClassicGame(d.profile),
        lastResult: null,
      ),
    );
    _markResumed(_data.savedGame!);
    services.analytics.count('game_started', {'mode': 'classic'});
    navigator.goPlay();
  }

  core.GameState _newClassicGame(PlayerProfile profile) => core.Game.newGame(
    mode: core.GameMode.classic,
    seed: Random.secure().nextInt(1 << 32),
    skill: profile.skill,
    restricted: profile.gamesCompleted == 0,
    startedAtMs: services.clock.now().millisecondsSinceEpoch,
  );

  void _markResumed(core.GameState game) {
    _elapsedAtResume = game.elapsedMs;
    _resumedAtMs = services.clock.now().millisecondsSinceEpoch;
  }

  int get _elapsedNow =>
      _elapsedAtResume +
      (services.clock.now().millisecondsSinceEpoch - _resumedAtMs);

  // ---- PlayHost ----

  @override
  core.GameState get state => _data.savedGame ?? _finishedGame!;

  @override
  int get bestScore {
    final game = _data.savedGame;
    if (game != null && game.mode == core.GameMode.daily) {
      return profile.dailyBest[game.dayOrdinal] ?? 0;
    }
    return profile.bestClassic;
  }

  @override
  int get coins => profile.coins;

  @override
  bool get rewardedRerollAvailable =>
      services.ads.isRewardedReady(RewardedPlacement.reroll);

  @override
  int get rerollCoinPrice => Economy.rerollCost;

  @override
  bool get soundOn => profile.soundEnabled;

  @override
  bool get hapticsOn => profile.hapticsEnabled;

  @override
  bool get showFirstGameHints => profile.gamesCompleted == 0;

  @override
  ThemePalette get palette => ThemePalette.all[profile.selectedTheme - 1];

  @override
  core.PlacementResult place(int slot, int row, int col) {
    final result = core.Game.place(state, slot, row, col);
    final next = core.Game.withElapsed(result.state, _elapsedNow);
    unawaited(mutate((d) => d.copyWith(savedGame: next)));
    return result;
  }

  @override
  void requestReroll() => navigator.showReroll();

  @override
  void requestPause() => navigator.showPause();

  @override
  void onGameOver() => navigator.showGameOver();

  // ---- reroll (design 6) ----

  bool get canReroll =>
      _data.savedGame != null &&
      state.rerollsUsed < Economy.maxRerollsPerGame &&
      state.status == core.GameStatus.playing;

  Future<void> rerollWithAd() async {
    if (!canReroll) return;
    if (!await _watchRewarded(RewardedPlacement.reroll)) return;
    await mutate((d) => d.copyWith(savedGame: core.Game.reroll(d.savedGame!)));
  }

  Future<void> rerollWithCoins() async {
    if (!canReroll || coins < Economy.rerollCost) return;
    await mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(coins: d.profile.coins - Economy.rerollCost),
        savedGame: core.Game.reroll(d.savedGame!),
      ),
    );
  }

  // ---- continue and game over (design 6.1) ----

  bool get continueAvailable =>
      _data.savedGame != null &&
      state.status == core.GameStatus.over &&
      state.continuesUsed < Economy.maxContinuesPerGame;

  ContinuePayment get continuePayment => profile.adFree
      ? ContinuePayment.free
      : services.ads.isRewardedReady(RewardedPlacement.continueGame)
      ? ContinuePayment.rewarded
      : ContinuePayment.coins;

  String get continuePriceLabel => switch (continuePayment) {
    ContinuePayment.free => S.overFree,
    ContinuePayment.rewarded => S.overWatchAd,
    ContinuePayment.coins => S.overUseCoins(Economy.continueCost),
  };

  Future<void> continueGame() async {
    if (!continueAvailable) return;
    switch (continuePayment) {
      case ContinuePayment.free:
        break;
      case ContinuePayment.rewarded:
        if (!await _watchRewarded(RewardedPlacement.continueGame)) return;
      case ContinuePayment.coins:
        if (coins < Economy.continueCost) {
          navigator.showMessage(S.streakNotEnough);
          return;
        }
    }
    final payWithCoins = continuePayment == ContinuePayment.coins;
    await mutate(
      (d) => d.copyWith(
        profile: payWithCoins
            ? d.profile.copyWith(coins: d.profile.coins - Economy.continueCost)
            : d.profile,
        savedGame: core.Game.continueGame(d.savedGame!),
      ),
    );
    _markResumed(_data.savedGame!);
    navigator.dismissSheet();
    navigator.goPlay();
  }

  Future<void> endGame() => finishGame();

  Future<LastGameResult?> finishGame() async {
    final game = _data.savedGame;
    if (game == null) return _data.lastResult;
    _finishedGame = game;
    final summary = GameSummary(
      mode: game.mode == core.GameMode.daily ? GameMode.daily : GameMode.classic,
      gameId: game.id,
      score: game.score,
      placements: game.placements,
      durationMs: game.elapsedMs,
      maxCombo: game.maxCombo,
      boardClearedCount: game.boardClears,
      continued: game.continuesUsed > 0,
      dayOrdinal: game.dayOrdinal,
    );
    final result = await mutateWith<LastGameResult?>((d) {
      final outcome = Progression.finish(d.profile, summary, services.clock.now());
      final result = outcome.result ?? d.lastResult;
      return (
        data: AppData(
          profile: outcome.profile,
          savedGame: null,
          lastResult: result,
        ),
        result: result,
      );
    });
    services.analytics.count('game_ended', {
      'mode': summary.mode.name,
      'score': Buckets.score(summary.score),
      'placements': Buckets.placements(summary.placements),
      'continued': '${summary.continued}',
    });
    return result;
  }

  bool get doubleCoinsAvailable =>
      services.ads.isRewardedReady(RewardedPlacement.doubleCoins);

  /// The best to show beside a finished game: `finishGame` has already folded
  /// this score into the profile, so the profile is the answer.
  int bestScoreFor(LastGameResult result) => result.mode == GameMode.daily
      ? (profile.dailyBest[result.dayOrdinal] ?? result.score)
      : profile.bestClassic;

  bool get lastResultIsNewBest {
    final result = _data.lastResult;
    return result != null &&
        result.score > 0 &&
        bestScoreFor(result) == result.score;
  }

  Future<void> doubleCoins() async {
    final result = _data.lastResult;
    if (result == null || result.doubled) return;
    if (!await _watchRewarded(RewardedPlacement.doubleCoins)) return;
    await mutate((d) {
      final pending = d.lastResult;
      if (pending == null || pending.doubled) return d;
      final out = Progression.doubleCoins(d.profile, pending);
      return d.copyWith(profile: out.profile, lastResult: out.result);
    });
  }

  Future<void> playAgain() async {
    final result = _data.lastResult;
    final shouldShow =
        result != null &&
        InterstitialPolicy.shouldShow(
          profile: profile,
          adFree: profile.adFree,
          gameDurationMs: result.elapsedMs,
          loaded: services.ads.isInterstitialReady,
          now: services.clock.now(),
        );
    if (shouldShow) {
      await services.ads.showInterstitial();
      services.analytics.count('interstitial_shown');
    }
    await mutate(
      (d) => AppData(
        profile: d.profile,
        savedGame: _newClassicGame(d.profile),
        lastResult: null,
      ),
    );
    _markResumed(_data.savedGame!);
    services.analytics.count('game_started', {'mode': 'classic'});
    navigator.dismissSheet();
    navigator.goPlay();
  }

  Future<void> goHome() async {
    await mutate((d) => d.copyWith(clearLastResult: true));
    navigator.dismissSheet();
    navigator.goHome();
  }

  // ---- settings and themes ----

  Future<void> selectTheme(int slot) async {
    await mutate((d) => d.copyWith(profile: Themes.select(d.profile, slot)));
    services.analytics.count('theme_selected', {
      'theme': Themes.bySlot(slot).name,
    });
  }

  Future<void> setSound(bool on) =>
      mutate((d) => d.copyWith(profile: d.profile.copyWith(soundEnabled: on)));

  Future<void> setHaptics(bool on) =>
      mutate((d) => d.copyWith(profile: d.profile.copyWith(hapticsEnabled: on)));

  // ---- AdSink (design 8.2) ----

  @override
  void onInterstitialShown() => unawaited(
    mutate(
      (d) => d.copyWith(
        profile: InterstitialPolicy.afterInterstitialShown(
          d.profile,
          services.clock.now(),
        ),
      ),
    ),
  );

  @override
  void onInterstitialClosed() => unawaited(
    mutate(
      (d) => d.copyWith(
        profile: InterstitialPolicy.afterInterstitialClosed(
          d.profile,
          services.clock.now(),
        ),
      ),
    ),
  );

  @override
  void onRewardedShown() => unawaited(
    mutate(
      (d) => d.copyWith(
        profile: InterstitialPolicy.afterRewardedShown(
          d.profile,
          services.clock.now(),
        ),
      ),
    ),
  );

  @override
  void onRewardedClosed() => unawaited(
    mutate(
      (d) => d.copyWith(
        profile: InterstitialPolicy.afterRewardedClosed(
          d.profile,
          services.clock.now(),
        ),
      ),
    ),
  );

  // ---- PurchaseSink (design 8.3) ----

  @override
  Future<void> applyPurchase(String productId, String purchaseToken) =>
      mutate(
        (d) => d.copyWith(
          profile: Purchases.grant(d.profile, productId, purchaseToken),
        ),
      );

  @override
  Future<void> purchaseCompleted(String purchaseToken) => mutate(
    (d) => d.copyWith(
      profile: Purchases.markPurchaseCompleted(d.profile, purchaseToken),
    ),
  );

  @override
  void purchasePending(String productId) {}

  @override
  void purchaseFailed(String productId) =>
      navigator.showMessage(S.shopPurchaseFailed);

  // ---- helpers ----

  Future<bool> _watchRewarded(RewardedPlacement placement) async {
    if (!services.ads.isRewardedReady(placement)) {
      services.analytics.count('rewarded_unavailable', {
        'placement': placement.name,
      });
      navigator.showMessage(S.adUnavailable);
      return false;
    }
    final earned = await services.ads.showRewarded(placement);
    services.analytics.count(
      earned ? 'rewarded_completed' : 'rewarded_unavailable',
      {'placement': placement.name},
    );
    if (!earned) navigator.showMessage(S.adUnavailable);
    return earned;
  }

  static String _randomUnitId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
