import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../ui/strings.dart';

abstract class NotificationsService {
  Future<bool> requestPermission();
  Future<void> scheduleReminder(DateTime at);
  Future<void> cancelReminder();
}

class NoopNotifications implements NotificationsService {
  const NoopNotifications();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleReminder(DateTime at) async {}

  @override
  Future<void> cancelReminder() async {}
}

/// One inexact local notification (design 10). Inexact on purpose: a puzzle
/// game does not qualify for Play's exact-alarm permissions.
class LocalNotificationsService implements NotificationsService {
  LocalNotificationsService();

  static const int _reminderId = 1;
  static const String _channelId = 'daily_reminder';

  static const AndroidNotificationDetails _details = AndroidNotificationDetails(
    _channelId,
    S.notifyChannelName,
    channelDescription: S.notifyChannelDescription,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _ensureReady() async {
    if (_ready) return;
    _ready = true;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        S.notifyChannelName,
        description: S.notifyChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> scheduleReminder(DateTime at) async {
    await _ensureReady();
    await _plugin.cancel(id: _reminderId);
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: S.reminderTitle,
      body: S.reminderBody,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelReminder() async {
    await _ensureReady();
    await _plugin.cancel(id: _reminderId);
  }
}

class RecordingNotifications implements NotificationsService {
  RecordingNotifications({this.grantPermission = true});

  bool grantPermission;
  final List<DateTime> scheduled = [];
  int cancels = 0;
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return grantPermission;
  }

  @override
  Future<void> scheduleReminder(DateTime at) async => scheduled.add(at);

  @override
  Future<void> cancelReminder() async => cancels += 1;
}
