import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/services/audit_service.dart';
import '../services/firestore_audit_service.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({
    FirebaseFirestore? firestore,
    AuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditService =
            auditService ?? FirestoreAuditService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AuditService _auditService;
  static const String _collection = 'usuarios';

  @override
  Stream<List<UserEntity>> watchAll({String? zona, bool? estadoActivo}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(UserEntity.fromFirestore)
              .where((user) =>
                  (zona == null || zona.trim().isEmpty) ||
                  user.zona == zona.trim())
              .where((user) =>
                  estadoActivo == null || user.estadoActivo == estadoActivo)
              .toList(growable: false),
        );
  }

  @override
  Stream<UserEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        throw StateError('No existe el usuario $id.');
      }
      return UserEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(UserEntity entity) async {
    final data = entity.toFirestore();
    await _firestore.collection(_collection).doc(entity.uid).set(data);
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe el usuario $id.');
    final before = snapshot.data()!;
    final normalized = <String, dynamic>{
      for (final entry in data.entries)
        if (_allowedFields.contains(entry.key)) entry.key: entry.value,
    };
    if (data.containsKey('estadoActivo')) {
      normalized['activo'] = data['estadoActivo'];
    }
    if (normalized.isEmpty) return;
    normalized['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await reference.update(normalized);
    if (normalized.containsKey('rol')) {
      await _auditService.log(
        action: 'role_changed',
        entityType: 'user',
        entityId: id,
        before: _changedFields(before, normalized),
        after: normalized,
      );
    }
  }

  @override
  Future<void> adjustReputationPoints(
    String id, {
    double? reputation,
    int? pointsDelta,
    required String reason,
  }) async {
    if ((reputation == null) == (pointsDelta == null)) {
      throw ArgumentError(
        'Indica reputación o delta de puntos, pero no ambos.',
      );
    }
    if (reputation != null && (reputation < 1 || reputation > 5)) {
      throw RangeError.range(reputation, 1, 5, 'reputation');
    }
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'El motivo es obligatorio.');
    }

    final reference = _firestore.collection(_collection).doc(id);
    final now = DateTime.now().millisecondsSinceEpoch;
    late Map<String, dynamic> before;
    late Map<String, dynamic> after;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('No existe el usuario $id.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentReputation = _numberValue(data['reputacion']);
      final currentPoints = _intValue(data['puntos']);
      before = {
        'reputacion': currentReputation,
        'puntos': currentPoints,
      };
      after = {
        'reputacion': reputation ?? currentReputation,
        'puntos': currentPoints + (pointsDelta ?? 0),
        'motivo': trimmedReason,
        'updatedAt': now,
      };
      transaction.update(reference, {
        if (reputation != null) 'reputacion': reputation,
        if (pointsDelta != null) 'puntos': currentPoints + pointsDelta,
        'updatedAt': now,
      });
    });
    await _auditService.log(
      action: 'reputacion_ajustada',
      entityType: 'user',
      entityId: id,
      before: before,
      after: after,
    );
  }

  @override
  Future<void> toggleActive(String id) => _toggleActive(id);

  @override
  Future<List<UserEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <UserEntity>[];
    }
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map(UserEntity.fromFirestore)
        .where((user) => <String>[
              user.uid,
              user.email,
              user.nombre,
              user.telefono,
            ].any((value) => value.toLowerCase().contains(normalizedQuery)))
        .toList(growable: false);
  }

  Future<void> _toggleActive(String id) async {
    final reference = _firestore.collection(_collection).doc(id);
    var wasActive = false;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('No existe el usuario $id.');
      }
      wasActive = snapshot.data()?['activo'] != false;
      transaction.update(reference, {
        'activo': !wasActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
    await _auditService.log(
      action: wasActive ? 'user_blocked' : 'user_unblocked',
      entityType: 'user',
      entityId: id,
      before: {'activo': wasActive},
      after: {
        'activo': !wasActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Map<String, dynamic> _changedFields(
    Map<String, dynamic> before,
    Map<String, dynamic> changes,
  ) =>
      {
        for (final key in changes.keys)
          if (before.containsKey(key)) key: before[key]
      };

  double _numberValue(dynamic value) => value is num ? value.toDouble() : 0;

  int _intValue(dynamic value) => value is num ? value.toInt() : 0;

  static const Set<String> _allowedFields = {
    'nombre',
    'rol',
    'telefono',
    'reputacion',
    'puntos',
    'lat',
    'lon',
    'activo',
  };
}
