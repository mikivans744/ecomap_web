import '../entities/system_notification.dart';

abstract interface class SystemNotificationService {
  List<SystemNotification> get notifications;
  void add(SystemNotification notification);
  void acknowledge(String notificationId);
}

class InMemorySystemNotificationService implements SystemNotificationService {
  InMemorySystemNotificationService({
    List<SystemNotification>? initialNotifications,
  }) : _notifications = initialNotifications ?? [];

  final List<SystemNotification> _notifications;

  @override
  List<SystemNotification> get notifications =>
      List.unmodifiable(_notifications);

  @override
  void add(SystemNotification notification) {
    _notifications.add(notification);
  }

  @override
  void acknowledge(String notificationId) {
    _notifications
        .removeWhere((notification) => notification.id == notificationId);
  }
}
