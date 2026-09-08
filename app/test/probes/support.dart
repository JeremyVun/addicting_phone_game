import 'package:settle/app.dart';
import 'package:settle/bootstrap.dart';
import 'package:settle/services/ads.dart';
import 'package:settle/services/analytics.dart';
import 'package:settle/services/clock.dart';
import 'package:settle/services/notifications.dart';
import 'package:settle/services/purchases.dart';
import 'package:settle/services/storage.dart';

import '../app/harness.dart';

/// The real `AdMobAdsService` clears its cached ad at show time and reloads
/// asynchronously, so `isRewardedReady` is false for a while after a show.
class OneShotAds implements AdsService {
  OneShotAds({this.grantsReward = true, this.reloads = false});

  bool grantsReward;
  bool reloads;
  bool rewardedReady = true;
  bool interstitialReady = true;
  final List<RewardedPlacement> shows = [];
  AdSink? sink;

  @override
  void start(AdSink s) => sink = s;

  @override
  bool isRewardedReady(RewardedPlacement placement) => rewardedReady;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    if (!rewardedReady) return false;
    rewardedReady = false;
    shows.add(placement);
    sink?.onRewardedShown();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    sink?.onRewardedClosed();
    if (reloads) rewardedReady = true;
    return grantsReward;
  }

  @override
  bool get isInterstitialReady => interstitialReady;

  @override
  Future<void> showInterstitial() async {
    interstitialReady = false;
    sink?.onInterstitialShown();
    sink?.onInterstitialClosed();
  }

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

class ThrowingStorage implements Storage {
  ThrowingStorage(this.inner, {this.failFromWrite = -1, this.failWhen});

  final MemoryStorage inner;
  int failFromWrite;
  bool Function(AppData)? failWhen;
  int writes = 0;

  @override
  Future<AppData?> load() => inner.load();

  @override
  Future<void> save(AppData data) async {
    writes += 1;
    if ((failFromWrite >= 0 && writes >= failFromWrite) ||
        (failWhen?.call(data) ?? false)) {
      throw StateError('disk full');
    }
    await inner.save(data);
  }
}

class ProbeApp {
  ProbeApp({
    Storage? storage,
    AdsService? ads,
    PurchaseService? purchases,
    DateTime? now,
  }) : storage = storage ?? MemoryStorage(),
       clock = FixedClock(now ?? DateTime(2026, 9, 8, 12)),
       ads = ads ?? OneShotAds(),
       purchases = purchases ?? FakePurchaseService(delay: Duration.zero) {
    controller = AppController(
      AppServices(
        storage: this.storage,
        clock: clock,
        ads: this.ads,
        purchases: this.purchases,
        analytics: analytics,
        notifications: RecordingNotifications(),
      ),
    )..navigator = navigator;
  }

  final Storage storage;
  final FixedClock clock;
  final AdsService ads;
  final PurchaseService purchases;
  final RecordingAnalytics analytics = RecordingAnalytics();
  final RecordingNavigator navigator = RecordingNavigator();
  late final AppController controller;

  Future<void> start() => controller.start();
}

Future<void> setCoins(AppController controller, int coins) =>
    controller.mutate((d) => d.copyWith(profile: d.profile.copyWith(coins: coins)));
