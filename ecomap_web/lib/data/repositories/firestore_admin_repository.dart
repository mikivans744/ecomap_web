import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_repository.dart';

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    if (!doc.exists || !(doc.data()?.containsKey('role') ?? false)) {
      return null;
    }
    return _fromDoc(doc);
  }

  @override
  Future<void> updateAdmin(
    String id, {
    bool? isActive,
    AdminUserRole? role,
  }) async {
    final updates = <String, dynamic>{};
    if (isActive != null) {
      updates['estadoActivo'] = isActive;
    }
    if (role != null) {
      updates['role'] = role.name;
    }

    if (updates.isEmpty) {
      return;
    }

    await _firestore.collection(_collection).doc(id).update(updates);
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
      displayName: data['display_name'] as String? ?? 'Administrador',
      role: role,
      isActive: data['estadoActivo'] as bool? ?? false,
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
