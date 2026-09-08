import 'dart:async';

import '../meta/economy.dart' show RewardedPlacement;

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
    _sink?.onInterstitialShown();
    await Future<void>.delayed(showDuration);
    _sink?.onInterstitialClosed();
  }

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
