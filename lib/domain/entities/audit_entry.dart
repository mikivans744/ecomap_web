import 'package:cloud_firestore/cloud_firestore.dart';

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.before,
    required this.after,
    required this.timestamp,
  });

  final String id;
  final String adminId;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;
  final DateTime timestamp;

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'adminId': adminId,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'before': before,
        'after': after,
        'timestamp': Timestamp.fromDate(timestamp),
        'performedBy': adminId,
        'performedAt': Timestamp.fromDate(timestamp),
        'previousData': before,
        'newData': after,
      };
}
