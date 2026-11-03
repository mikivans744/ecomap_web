import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/audit_entry.dart';
import '../../domain/services/audit_service.dart';

class FirestoreAuditService implements AuditService {
  FirestoreAuditService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<AuditEntry> log({
    required String action,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) {
      throw StateError('No hay un administrador autenticado para auditar.');
    }

    final reference = _firestore.collection('audit_logs').doc();
    final entry = AuditEntry(
      id: reference.id,
      adminId: adminId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      before: Map<String, dynamic>.from(before),
      after: Map<String, dynamic>.from(after),
      timestamp: DateTime.now(),
    );
    await reference.set(entry.toFirestore());
    return entry;
  }
}
