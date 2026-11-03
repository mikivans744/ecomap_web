import '../entities/audit_entry.dart';

abstract interface class AuditService {
  Future<AuditEntry> log({
    required String action,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  });
}
