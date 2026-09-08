import 'ads.dart';
import 'analytics.dart';
import 'purchases.dart';

// Phase 4 replaces these fakes with the AdMob, Play Billing and analytics services.
AdsService buildAds() => FakeAdsService();

PurchaseService buildPurchases() => FakePurchaseService();

AnalyticsService buildAnalytics() => const NoopAnalytics();
