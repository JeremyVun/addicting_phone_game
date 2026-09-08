import 'package:flutter/foundation.dart';

const String adIdPlaceholder = 'REPLACE_ME';

const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
const String testRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
const String testInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

const String releaseAppId = adIdPlaceholder;
const String releaseRewardedUnitId = adIdPlaceholder;
const String releaseInterstitialUnitId = adIdPlaceholder;

/// A store build shipped with placeholders must load nothing at all rather than
/// serve Google's test ads to real players.
bool get adIdsConfigured =>
    kDebugMode ||
    ![
      releaseAppId,
      releaseRewardedUnitId,
      releaseInterstitialUnitId,
    ].contains(adIdPlaceholder);

/// One rewarded unit serves all four placements of design 8.1.
class AdIds {
  const AdIds({
    required this.rewarded,
    required this.interstitial,
    required this.configured,
  });

  const AdIds.unconfigured()
    : rewarded = '',
      interstitial = '',
      configured = false;

  final String rewarded;
  final String interstitial;
  final bool configured;

  static AdIds get current => AdIds(
    rewarded: kDebugMode ? testRewardedUnitId : releaseRewardedUnitId,
    interstitial: kDebugMode ? testInterstitialUnitId : releaseInterstitialUnitId,
    configured: adIdsConfigured,
  );
}
