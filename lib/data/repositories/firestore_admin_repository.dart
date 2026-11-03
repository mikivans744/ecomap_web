import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/services/audit_service.dart';
import '../services/firestore_audit_service.dart';

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({
    FirebaseFirestore? firestore,
    AuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditService =
            auditService ?? FirestoreAuditService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AuditService _auditService;

  static const String _collection = 'admins';

  @override
  Stream<AdminUser?> watchCurrentAdmin() {
    return _firestore
        .collection(_collection)
        .where('estadoActivo', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.isEmpty ? null : _fromDoc(snapshot.docs.first));
  }

  @override
  Future<AdminUser?> getAdmin(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists || !doc.data()!.containsKey('role')) {
      return null;
    }
    return _fromDoc(doc);
  }

  @override
  Future<void> updateAdmin(
    String id, {
    bool? estadoActivo,
    AdminUserRole? role,
  }) async {
    final updates = <String, dynamic>{};
    if (estadoActivo != null) {
      updates['estadoActivo'] = estadoActivo;
    }
    if (role != null) {
      updates['role'] = role.name;
    }

    if (updates.isEmpty) {
      return;
    }

    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe el administrador $id.');
    await reference.update(updates);
    final isRoleChange = role != null;
    await _auditService.log(
      action: isRoleChange ? 'role_changed' : 'admin_status_changed',
      entityType: 'admin',
      entityId: id,
      before: {
        if (role != null) 'role': snapshot.data()?['role'],
        if (estadoActivo != null)
          'estadoActivo': snapshot.data()?['estadoActivo'],
      },
      after: updates,
    );
  }

  AdminUser _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final role = AdminUserRole.values.firstWhere(
      (value) => value.name == data['role'],
      orElse: () => AdminUserRole.admin,
    );

    return AdminUser(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Administrador',
      role: role,
      estadoActivo: data['estadoActivo'] as bool? ?? false,
      createdAt: _readTimestamp(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastLoginAt: _readTimestamp(data['lastLoginAt']),
    );
  }

  DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
