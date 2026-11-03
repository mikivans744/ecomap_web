import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/recolector_entity.dart';
import '../../domain/repositories/recolector_repository.dart';
import '../../domain/services/audit_service.dart';
import '../services/firestore_audit_service.dart';

class FirestoreRecolectorRepository implements RecolectorRepository {
  FirestoreRecolectorRepository({
    FirebaseFirestore? firestore,
    AuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditService =
            auditService ?? FirestoreAuditService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AuditService _auditService;
  static const String _collection = 'usuarios';

  @override
  Stream<List<RecolectorEntity>> watchAll({String? zona, bool? estadoActivo}) {
    return _firestore
        .collection(_collection)
        .where('rol', isEqualTo: 'RECOLECTOR')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(RecolectorEntity.fromFirestore)
            .where((item) =>
                (zona == null || zona.trim().isEmpty || item.zona == zona) &&
                (estadoActivo == null || item.estadoActivo == estadoActivo))
            .toList(growable: false));
  }

  @override
  Stream<RecolectorEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data()?['rol'] != 'RECOLECTOR') {
        throw StateError('No existe el recolector $id.');
      }
      return RecolectorEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(RecolectorEntity entity) async {
    if (entity.id.isEmpty) {
      throw StateError('El recolector debe tener un UID de Firebase Auth.');
    }
    final reference = _firestore.collection(_collection).doc(entity.id);
    await reference.set(entity.toFirestore());
    await _auditService.log(
      action: 'recolector_created',
      entityType: 'recolector',
      entityId: reference.id,
      before: const {},
      after: entity.toFirestore(),
    );
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final normalized = <String, dynamic>{
      for (final field in const [
        'nombre',
        'telefono',
        'placa_vehiculo',
        'tipo_vehiculo',
        'capacidad_kg',
        'zona_cobertura',
      ])
        if (data.containsKey(field)) field: data[field],
    };
    if (normalized.isEmpty) return;
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data()?['rol'] != 'RECOLECTOR') {
      throw StateError('No existe el recolector $id.');
    }
    normalized['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await reference.update(normalized);
    await _auditService.log(
      action: 'recolector_updated',
      entityType: 'recolector',
      entityId: id,
      before: {
        for (final key in normalized.keys)
          if (snapshot.data()!.containsKey(key)) key: snapshot.data()![key],
      },
      after: normalized,
    );
  }

  @override
  Future<void> toggleActive(String id) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data()?['rol'] != 'RECOLECTOR') {
      throw StateError('No existe el recolector $id.');
    }
    final wasActive = snapshot.data()?['activo'] != false;
    final changes = {
      'activo': !wasActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await reference.update(changes);
    await _auditService.log(
      action: wasActive ? 'recolector_blocked' : 'recolector_unblocked',
      entityType: 'recolector',
      entityId: id,
      before: {'activo': wasActive},
      after: changes,
    );
  }

  @override
  Future<bool> isPlateAvailable(String plate, {String? excludingId}) async {
    final normalized = _normalizePlate(plate);
    if (normalized.isEmpty) return true;
    final snapshot = await _firestore
        .collection(_collection)
        .where('rol', isEqualTo: 'RECOLECTOR')
        .get();
    return snapshot.docs.every((doc) {
      if (doc.id == excludingId || doc.data()['activo'] == false) return true;
      return _normalizePlate(doc.data()['placa_vehiculo'] as String? ?? '') !=
          normalized;
    });
  }

  @override
  Future<List<RecolectorEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const <RecolectorEntity>[];
    final snapshot = await _firestore
        .collection(_collection)
        .where('rol', isEqualTo: 'RECOLECTOR')
        .get();
    return snapshot.docs
        .map(RecolectorEntity.fromFirestore)
        .where((item) => <String>[
              item.nombreCompleto,
              item.telefono,
              item.zona,
            ].any((value) => value.toLowerCase().contains(normalizedQuery)))
        .toList(growable: false);
  }

  String _normalizePlate(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

class RecolectorPlateAlreadyInUse implements Exception {
  const RecolectorPlateAlreadyInUse(this.plate);

  final String plate;

  @override
  String toString() =>
      'La placa $plate ya está registrada en otro recolector activo.';
}
