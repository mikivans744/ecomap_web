import 'package:flutter/foundation.dart';

@immutable
class SystemNotification {
  const SystemNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final SystemNotificationPriority priority;
  final DateTime createdAt;
}

enum SystemNotificationPriority {
  low,
  medium,
  high,
}
