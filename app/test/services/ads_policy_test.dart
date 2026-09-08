import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/services/ad_ids.dart';
import 'package:settle/services/ads.dart';

class FakeLoadedAd implements LoadedAd {
  FakeLoadedAd({this.failToShow = false, this.earnsReward = true});

  final bool failToShow;
  final bool earnsReward;
  AdCallbacks? callbacks;
  int shows = 0;
  int disposals = 0;

  @override
  void show(AdCallbacks callbacks) {
    this.callbacks = callbacks;
    shows += 1;
    if (failToShow) {
      callbacks.onFailedToShow();
      return;
    }
    callbacks.onShown();
    if (earnsReward) callbacks.onEarnedReward?.call();
    callbacks.onClosed();
  }

  @override
  void dispose() => disposals += 1;
}

class FakeAdPlatform implements AdPlatform {
  FakeAdPlatform({this.consent = true});

  bool consent;
  bool privacyRequired = false;
  bool alwaysFail = false;
  final List<(AdKind, String)> loads = [];
  final Map<AdKind, List<FakeLoadedAd?>> queued = {};
  int privacyForms = 0;

  /// Once the script runs out, loads succeed with a fresh ad.
  void queue(AdKind kind, List<FakeLoadedAd?> ads) => queued[kind] = [...ads];

  @override
  Future<bool> prepare({required bool forceEeaGeography}) async => consent;

  @override
  Future<LoadedAd?> load(AdKind kind, String unitId) async {
    loads.add((kind, unitId));
    if (alwaysFail) return null;
    final pending = queued[kind];
    if (pending == null || pending.isEmpty) return FakeLoadedAd();
    return pending.removeAt(0);
  }

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {
    privacyForms += 1;
    privacyRequired = false;
  }
}

class RecordingSink implements AdSink {
  final List<String> calls = [];

  @override
  void onInterstitialShown() => calls.add('interstitialShown');

  @override
  void onInterstitialClosed() => calls.add('interstitialClosed');

  @override
  void onRewardedShown() => calls.add('rewardedShown');

  @override
  void onRewardedClosed() => calls.add('rewardedClosed');
}

const AdIds testIds = AdIds(
  rewarded: 'rewarded-unit',
  interstitial: 'interstitial-unit',
  configured: true,
);

void main() {
  late RecordingSink sink;
  late FakeAdPlatform platform;
  late List<Duration> waits;
  // The reload loop retries for ever; the test stalls it to end the pump.
  late int stallAfter;

  setUp(() {
    sink = RecordingSink();
    platform = FakeAdPlatform();
    waits = [];
    stallAfter = 4;
  });

  AdMobAdsService build({AdIds ids = testIds}) => AdMobAdsService(
    platform: platform,
    ids: ids,
    delay: (d) {
      waits.add(d);
      return waits.length > stallAfter
          ? Completer<void>().future
          : Future<void>.value();
    },
  );

  Future<AdMobAdsService> started({AdIds ids = testIds}) async {
    final service = build(ids: ids)..start(sink);
    await pumpEventQueue();
    return service;
  }

  test('preloads one of each after consent, using the mapped unit ids', () async {
    final service = await started();
    expect(platform.loads, [
      (AdKind.rewarded, 'rewarded-unit'),
      (AdKind.interstitial, 'interstitial-unit'),
    ]);
    expect(service.isRewardedReady(RewardedPlacement.reroll), isTrue);
    expect(service.isInterstitialReady, isTrue);
  });

  test('placeholder ad ids load nothing and never report ready', () async {
    final service = await started(ids: const AdIds.unconfigured());
    expect(platform.loads, isEmpty);
    expect(service.isRewardedReady(RewardedPlacement.continueGame), isFalse);
    expect(service.isInterstitialReady, isFalse);
    expect(await service.showRewarded(RewardedPlacement.reroll), isFalse);
  });

  test('no consent means no ad requests at all', () async {
    platform.consent = false;
    final service = await started();
    expect(platform.loads, isEmpty);
    expect(service.isInterstitialReady, isFalse);
  });

  test('the reward comes only from the earned callback', () async {
    platform.queue(AdKind.rewarded, [
      FakeLoadedAd(earnsReward: false),
      FakeLoadedAd(),
    ]);
    final service = await started();
    expect(await service.showRewarded(RewardedPlacement.doubleCoins), isFalse);
    expect(sink.calls, ['rewardedShown', 'rewardedClosed']);
    await pumpEventQueue();
    expect(await service.showRewarded(RewardedPlacement.doubleCoins), isTrue);
  });

  test('a failed show grants nothing and raises no policy transition', () async {
    platform.queue(AdKind.rewarded, [FakeLoadedAd(failToShow: true)]);
    final service = await started();
    expect(await service.showRewarded(RewardedPlacement.reroll), isFalse);
    expect(sink.calls, isEmpty);
  });

  test('an ad is shown once, disposed, and replaced by a fresh load', () async {
    final first = FakeLoadedAd();
    final second = FakeLoadedAd();
    platform.queue(AdKind.interstitial, [first, second]);
    final service = await started();
    await service.showInterstitial();
    expect(sink.calls, ['interstitialShown', 'interstitialClosed']);
    expect(first.disposals, 1);
    await pumpEventQueue();
    expect(
      platform.loads.where((l) => l.$1 == AdKind.interstitial).length,
      2,
    );
    await service.showInterstitial();
    expect(first.shows, 1);
    expect(second.shows, 1);
  });

  test('showing with nothing loaded is a no-op', () async {
    platform.alwaysFail = true;
    final service = await started();
    await service.showInterstitial();
    expect(sink.calls, isEmpty);
  });

  test('load failures retry with exponential backoff capped at 60 s', () async {
    stallAfter = 20;
    platform.queue(AdKind.rewarded, [
      null, null, null, null, null, null, null, null, FakeLoadedAd(),
    ]);
    final service = await started();
    await pumpEventQueue();
    expect(waits.map((d) => d.inSeconds).take(8), [1, 2, 4, 8, 16, 32, 60, 60]);
    expect(service.isRewardedReady(RewardedPlacement.reroll), isTrue);
  });

  test('backoff schedule', () {
    expect(AdMobAdsService.backoffFor(1), const Duration(seconds: 1));
    expect(AdMobAdsService.backoffFor(6), const Duration(seconds: 32));
    expect(AdMobAdsService.backoffFor(7), const Duration(seconds: 60));
    expect(AdMobAdsService.backoffFor(40), const Duration(seconds: 60));
  });

  test('start never throws when the consent flow does', () async {
    final service = AdMobAdsService(
      platform: _ThrowingPlatform(),
      ids: testIds,
      delay: (_) async {},
    )..start(sink);
    await pumpEventQueue();
    expect(service.isInterstitialReady, isFalse);
    expect(service.privacyOptionsRequired, isFalse);
    await service.showPrivacyOptions();
  });

  test('privacy options mirror the SDK and refresh after the form', () async {
    platform.privacyRequired = true;
    final service = await started();
    expect(service.privacyOptionsRequired, isTrue);
    await service.showPrivacyOptions();
    expect(platform.privacyForms, 1);
    expect(service.privacyOptionsRequired, isFalse);
  });
}

class _ThrowingPlatform implements AdPlatform {
  @override
  Future<bool> prepare({required bool forceEeaGeography}) async =>
      throw StateError('no consent sdk');

  @override
  Future<LoadedAd?> load(AdKind kind, String unitId) async =>
      throw StateError('no ads');

  @override
  Future<bool> privacyOptionsRequired() async => throw StateError('nope');

  @override
  Future<void> showPrivacyOptions() async => throw StateError('nope');
}
