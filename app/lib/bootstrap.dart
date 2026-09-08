import 'services/ads.dart';
import 'services/analytics.dart';
import 'services/clock.dart';
import 'services/notifications.dart';
import 'services/purchases.dart';
import 'services/storage.dart';

/// Audio and haptics are deliberately absent: the play screen owns those two
/// interfaces and integration adds them here (see docs/contracts/app-shell.md).
class AppServices {
  const AppServices({
    required this.storage,
    required this.clock,
    required this.ads,
    required this.purchases,
    required this.analytics,
    required this.notifications,
  });

  final Storage storage;
  final Clock clock;
  final AdsService ads;
  final PurchaseService purchases;
  final AnalyticsService analytics;
  final NotificationsService notifications;
}

Future<AppServices> bootstrap() async => AppServices(
  storage: SharedPreferencesStorage(),
  clock: const SystemClock(),
  ads: FakeAdsService(),
  purchases: FakePurchaseService(),
  analytics: const NoopAnalytics(),
  notifications: const NoopNotifications(),
);
