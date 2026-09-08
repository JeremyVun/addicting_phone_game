import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../meta/economy.dart' show RewardedPlacement;
import 'ad_ids.dart';

/// The placement enum is `meta`'s, re-exported so callers need one import and
/// the two layers can never drift apart.
export '../meta/economy.dart' show RewardedPlacement;

abstract class AdsService {
  void start(AdSink sink);
  bool isRewardedReady(RewardedPlacement placement);

  /// True only when the reward was earned.
  Future<bool> showRewarded(RewardedPlacement placement);
  bool get isInterstitialReady;
  Future<void> showInterstitial();
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
}

/// The design 8.2 policy transitions, raised by the ad SDK's full-screen
/// callbacks and applied inside the controller's mutation queue.
abstract class AdSink {
  void onInterstitialShown();
  void onInterstitialClosed();
  void onRewardedShown();
  void onRewardedClosed();
}

class FakeAdsService implements AdsService {
  FakeAdsService({
    this.showDuration = const Duration(milliseconds: 300),
    this.rewardedReady = true,
    this.interstitialReady = true,
    this.grantsReward = true,
  });

  final Duration showDuration;
  bool rewardedReady;
  bool interstitialReady;
  bool grantsReward;
  bool showFails = false;

  final List<RewardedPlacement> rewardedShows = [];
  int interstitialShows = 0;
  AdSink? _sink;

  @override
  void start(AdSink sink) => _sink = sink;

  @override
  bool isRewardedReady(RewardedPlacement placement) => rewardedReady;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    if (!rewardedReady) return false;
    rewardedShows.add(placement);
    if (showFails) return false;
    _sink?.onRewardedShown();
    await Future<void>.delayed(showDuration);
    _sink?.onRewardedClosed();
    return grantsReward;
  }

  @override
  bool get isInterstitialReady => interstitialReady;

  @override
  Future<void> showInterstitial() async {
    if (!interstitialReady) return;
    interstitialShows += 1;
    if (showFails) return;
    _sink?.onInterstitialShown();
    await Future<void>.delayed(showDuration);
    _sink?.onInterstitialClosed();
  }

  bool privacyRequired = false;
  int privacyOptionForms = 0;

  @override
  bool get privacyOptionsRequired => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {
    privacyOptionForms += 1;
    privacyRequired = false;
  }
}

enum AdKind { rewarded, interstitial }

/// The four full-screen callbacks the service reacts to. A failed show is kept
/// apart from a dismissal because design 8.2 counts only the ads that ran.
class AdCallbacks {
  const AdCallbacks({
    required this.onShown,
    required this.onClosed,
    required this.onFailedToShow,
    this.onEarnedReward,
  });

  final void Function() onShown;
  final void Function() onClosed;
  final void Function() onFailedToShow;
  final void Function()? onEarnedReward;
}

abstract class LoadedAd {
  void show(AdCallbacks callbacks);
  void dispose();
}

/// Everything `AdMobAdsService` needs from the platform, so its state machine
/// can be driven by a fake in unit tests.
abstract class AdPlatform {
  /// Runs the UMP flow and initialises the SDK; true when ads may be requested.
  Future<bool> prepare({required bool forceEeaGeography});
  Future<LoadedAd?> load(AdKind kind, String unitId);
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

class AdMobAdsService implements AdsService {
  AdMobAdsService({
    AdPlatform? platform,
    AdIds? ids,
    this.forceEeaGeography = kForceEeaConsent,
    Future<void> Function(Duration)? delay,
  }) : _platform = platform ?? MobileAdsPlatform(),
       _ids = ids ?? AdIds.current,
       _delay = delay ?? _wait;

  static const Duration minBackoff = Duration(seconds: 1);
  static const Duration maxBackoff = Duration(seconds: 60);

  final AdPlatform _platform;
  final AdIds _ids;
  final Future<void> Function(Duration) _delay;
  final bool forceEeaGeography;

  final Map<AdKind, LoadedAd> _ready = {};
  final Set<AdKind> _loading = {};

  AdSink? _sink;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  static Future<void> _wait(Duration d) => Future<void>.delayed(d);

  static Duration backoffFor(int attempt) {
    final seconds = attempt >= 7 ? maxBackoff.inSeconds : 1 << (attempt - 1);
    return Duration(
      seconds: seconds.clamp(minBackoff.inSeconds, maxBackoff.inSeconds),
    );
  }

  @override
  void start(AdSink sink) {
    _sink = sink;
    unawaited(_startConsent());
  }

  Future<void> _startConsent() async {
    if (!_ids.configured) {
      _log('ad ids are placeholders; no ads will load');
      return;
    }
    try {
      _canRequestAds = await _platform.prepare(
        forceEeaGeography: forceEeaGeography,
      );
      _privacyOptionsRequired = await _platform.privacyOptionsRequired();
    } catch (error, stack) {
      _log('consent flow failed', error, stack);
      return;
    }
    if (!_canRequestAds) return;
    unawaited(_keepLoaded(AdKind.rewarded));
    unawaited(_keepLoaded(AdKind.interstitial));
  }

  String _unitId(AdKind kind) =>
      kind == AdKind.rewarded ? _ids.rewarded : _ids.interstitial;

  Future<void> _keepLoaded(AdKind kind) async {
    if (!_canRequestAds || _ready.containsKey(kind) || _loading.contains(kind)) {
      return;
    }
    _loading.add(kind);
    try {
      for (var attempt = 1; ; attempt++) {
        LoadedAd? ad;
        try {
          ad = await _platform.load(kind, _unitId(kind));
        } catch (error, stack) {
          _log('$kind load threw', error, stack);
        }
        if (ad != null) {
          _ready[kind] = ad;
          return;
        }
        await _delay(backoffFor(attempt));
      }
    } finally {
      _loading.remove(kind);
    }
  }

  /// An ad object may only be shown once, so the cache is cleared at show time.
  LoadedAd? _take(AdKind kind) => _ready.remove(kind);

  @override
  bool isRewardedReady(RewardedPlacement placement) =>
      _ready.containsKey(AdKind.rewarded);

  @override
  bool get isInterstitialReady => _ready.containsKey(AdKind.interstitial);

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    final ad = _take(AdKind.rewarded);
    if (ad == null) return false;
    var earned = false;
    final done = Completer<void>();
    ad.show(
      AdCallbacks(
        onShown: () => _sink?.onRewardedShown(),
        onEarnedReward: () => earned = true,
        onClosed: () {
          _sink?.onRewardedClosed();
          if (!done.isCompleted) done.complete();
        },
        onFailedToShow: () {
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    await done.future;
    ad.dispose();
    unawaited(_keepLoaded(AdKind.rewarded));
    return earned;
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _take(AdKind.interstitial);
    if (ad == null) return;
    final done = Completer<void>();
    ad.show(
      AdCallbacks(
        onShown: () => _sink?.onInterstitialShown(),
        onClosed: () {
          _sink?.onInterstitialClosed();
          if (!done.isCompleted) done.complete();
        },
        onFailedToShow: () {
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    await done.future;
    ad.dispose();
    unawaited(_keepLoaded(AdKind.interstitial));
  }

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await _platform.showPrivacyOptions();
      _privacyOptionsRequired = await _platform.privacyOptionsRequired();
    } catch (error, stack) {
      _log('privacy options failed', error, stack);
    }
  }
}

void _log(String what, [Object? error, StackTrace? stack]) {
  if (error == null) {
    debugPrint('ads: $what');
    return;
  }
  debugPrint('ads: $what: $error');
  if (kDebugMode && stack != null) debugPrintStack(stackTrace: stack);
}

class MobileAdsPlatform implements AdPlatform {
  @override
  Future<bool> prepare({required bool forceEeaGeography}) async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(
        consentDebugSettings: forceEeaGeography && kDebugMode
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: kConsentTestDeviceId.isEmpty
                    ? null
                    : [kConsentTestDeviceId],
              )
            : null,
      ),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (FormError error) {
        _log('consent info update: ${error.errorCode} ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => _log('consent info update timed out'),
    );

    final dismissed = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        _log('consent form: ${error.errorCode} ${error.message}');
      }
      if (!dismissed.isCompleted) dismissed.complete();
    });
    await dismissed.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => _log('consent form never dismissed'),
    );

    // Documented trap: false until requestConsentInfoUpdate has run once.
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.t),
    );
    return true;
  }

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    final dismissed = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        _log('privacy options form: ${error.errorCode} ${error.message}');
      }
      if (!dismissed.isCompleted) dismissed.complete();
    });
    await dismissed.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => _log('privacy options form never dismissed'),
    );
  }

  @override
  Future<LoadedAd?> load(AdKind kind, String unitId) {
    final loaded = Completer<LoadedAd?>();
    void fail(LoadAdError error) {
      _log('$kind load failed: ${error.code} ${error.message}');
      if (!loaded.isCompleted) loaded.complete(null);
    }

    if (kind == AdKind.rewarded) {
      RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!loaded.isCompleted) loaded.complete(_RewardedHandle(ad));
          },
          onAdFailedToLoad: fail,
        ),
      );
    } else {
      InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!loaded.isCompleted) loaded.complete(_InterstitialHandle(ad));
          },
          onAdFailedToLoad: fail,
        ),
      );
    }
    return loaded.future;
  }
}

FullScreenContentCallback<T> _contentCallback<T extends Ad>(
  AdCallbacks callbacks,
) => FullScreenContentCallback<T>(
  onAdShowedFullScreenContent: (_) => callbacks.onShown(),
  onAdDismissedFullScreenContent: (_) => callbacks.onClosed(),
  onAdFailedToShowFullScreenContent: (_, error) {
    _log('show failed: ${error.code} ${error.message}');
    callbacks.onFailedToShow();
  },
);

class _RewardedHandle implements LoadedAd {
  _RewardedHandle(this._ad);

  final RewardedAd _ad;

  @override
  void show(AdCallbacks callbacks) {
    _ad.fullScreenContentCallback = _contentCallback<RewardedAd>(callbacks);
    unawaited(
      _ad.show(
        onUserEarnedReward: (_, _) => callbacks.onEarnedReward?.call(),
      ),
    );
  }

  @override
  void dispose() => unawaited(_ad.dispose());
}

class _InterstitialHandle implements LoadedAd {
  _InterstitialHandle(this._ad);

  final InterstitialAd _ad;

  @override
  void show(AdCallbacks callbacks) {
    _ad.fullScreenContentCallback = _contentCallback<InterstitialAd>(callbacks);
    unawaited(_ad.show());
  }

  @override
  void dispose() => unawaited(_ad.dispose());
}
