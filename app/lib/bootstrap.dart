import 'services/ads.dart';
import 'services/analytics.dart';
import 'services/audio.dart';
import 'services/haptics.dart';
import 'services/clock.dart';
import 'services/notifications.dart';
import 'services/purchases.dart';
import 'services/storage.dart';
import 'services/wiring_monetisation.dart';
import 'services/wiring_notifications.dart';

class AppServices {
  const AppServices({
    required this.storage,
    required this.clock,
    required this.ads,
    required this.purchases,
    required this.analytics,
    required this.notifications,
    this.audio = const NoopAudioService(),
    this.haptics = const NoopHapticsService(),
  });

  final Storage storage;
  final Clock clock;
  final AdsService ads;
  final PurchaseService purchases;
  final AnalyticsService analytics;
  final NotificationsService notifications;
  final AudioService audio;
  final HapticsService haptics;
}

Future<AppServices> bootstrap() async => AppServices(
  storage: SharedPreferencesStorage(),
  clock: const SystemClock(),
  ads: buildAds(),
  purchases: buildPurchases(),
  analytics: buildAnalytics(),
  notifications: buildNotifications(),
  audio: FlameAudioService(),
  haptics: PlatformHapticsService(),
);
