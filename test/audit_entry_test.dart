import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/domain/entities/audit_entry.dart';

void main() {
  test('serializes audit entries for the audit page and legacy fields', () {
    final timestamp = DateTime(2026, 11, 2, 1, 30);
    final entry = AuditEntry(
      id: 'audit-1',
      adminId: 'admin-1',
      action: 'user_blocked',
      entityType: 'user',
      entityId: 'user-1',
      before: const {'estadoActivo': true},
      after: const {'estadoActivo': false},
      timestamp: timestamp,
    );

    final data = entry.toFirestore();

    expect(data['id'], 'audit-1');
    expect(data['adminId'], 'admin-1');
    expect(data['action'], 'user_blocked');
    expect(data['entityType'], 'user');
    expect(data['entityId'], 'user-1');
    expect(data['before'], {'estadoActivo': true});
    expect(data['after'], {'estadoActivo': false});
    expect((data['timestamp'] as Timestamp).toDate(), timestamp);
    expect(data['performedBy'], 'admin-1');
    expect((data['performedAt'] as Timestamp).toDate(), timestamp);
    expect(data['previousData'], data['before']);
    expect(data['newData'], data['after']);
  });
}
