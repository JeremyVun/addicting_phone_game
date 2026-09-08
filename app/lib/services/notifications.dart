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
