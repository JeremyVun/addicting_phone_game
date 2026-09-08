import 'package:flutter/foundation.dart';

import '../config.dart';
import 'ads.dart';
import 'analytics.dart';
import 'purchases.dart';
import 'storage.dart';

bool get _useFakes => kDebugMode && kFakeServices;

AdsService buildAds() => _useFakes ? FakeAdsService() : AdMobAdsService();

PurchaseService buildPurchases() => _useFakes
    ? FakePurchaseService()
    : PlayPurchaseService(analytics: buildAnalytics());

AnalyticsService? _analytics;

AnalyticsService buildAnalytics() =>
    _analytics ??= HttpAnalytics.fromEnvironment(unitId: _analyticsUnitId);

/// Read from the envelope rather than the controller: `bootstrap()` runs before
/// the profile exists, and an empty id is retried at the next flush.
Future<String> _analyticsUnitId() async {
  try {
    final data = await SharedPreferencesStorage().load();
    return data?.profile.analyticsUnitId ?? '';
  } catch (_) {
    return '';
  }
}
