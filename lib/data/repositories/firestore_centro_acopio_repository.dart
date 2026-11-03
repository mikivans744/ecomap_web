import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/centro_acopio_entity.dart';
import '../../domain/repositories/centro_acopio_repository.dart';
import '../../domain/services/audit_service.dart';
import '../services/firestore_audit_service.dart';

class FirestoreCentroAcopioRepository implements CentroAcopioRepository {
  FirestoreCentroAcopioRepository({
    FirebaseFirestore? firestore,
    AuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditService =
            auditService ?? FirestoreAuditService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AuditService _auditService;
  static const String _collection = 'usuarios';

  @override
  Stream<List<CentroAcopioEntity>> watchAll({
    String? zona,
    bool? estadoActivo,
  }) {
    return _firestore
        .collection(_collection)
        .where('rol', isEqualTo: 'CENTRO_ACOPIO')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CentroAcopioEntity.fromFirestore)
            .where((item) =>
                (estadoActivo == null || item.estadoActivo == estadoActivo))
            .toList(growable: false));
  }

  @override
  Stream<CentroAcopioEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data()?['rol'] != 'CENTRO_ACOPIO') {
        throw StateError('No existe el centro de acopio $id.');
      }
      return CentroAcopioEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(CentroAcopioEntity entity) async {
    if (entity.id.isEmpty) {
      throw StateError('El centro debe tener un UID de Firebase Auth.');
    }
    final reference = _firestore.collection(_collection).doc(entity.id);
    final data = entity.toFirestore();
    await reference.set(data);
    await _auditService.log(
      action: 'centro_created',
      entityType: 'centro',
      entityId: reference.id,
      before: const {},
      after: data,
    );
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data()?['rol'] != 'CENTRO_ACOPIO') {
      throw StateError('No existe el centro de acopio $id.');
    }
    final normalized = <String, dynamic>{
      for (final field in const [
        'nombre',
        'telefono',
        'nombre_empresa',
        'direccion_fija',
      ])
        if (data.containsKey(field)) field: data[field],
    };
    if (normalized.isEmpty) return;
    normalized['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await reference.update(normalized);
    await _auditService.log(
      action: 'centro_updated',
      entityType: 'centro',
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
    if (!snapshot.exists || snapshot.data()?['rol'] != 'CENTRO_ACOPIO') {
      throw StateError('No existe el centro de acopio $id.');
    }
    final wasActive = snapshot.data()?['activo'] != false;
    final changes = {
      'activo': !wasActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await reference.update(changes);
    await _auditService.log(
      action: wasActive ? 'centro_deactivated' : 'centro_activated',
      entityType: 'centro',
      entityId: id,
      before: {'activo': wasActive},
      after: changes,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveOffers(String centerId) async {
    final snapshot = await _firestore
        .collection('ofertas_centro')
        .where('centroId', isEqualTo: centerId)
        .get();
    return snapshot.docs
        .where((document) =>
            const {'OFERTADA', 'ACEPTADA'}.contains(document.data()['estado']))
        .map((document) => <String, dynamic>{
              'id': document.id,
              ...document.data(),
            })
        .toList(growable: false);
  }

  @override
  Future<List<CentroAcopioEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const <CentroAcopioEntity>[];
    final snapshot = await _firestore
        .collection(_collection)
        .where('rol', isEqualTo: 'CENTRO_ACOPIO')
        .get();
    return snapshot.docs
        .map(CentroAcopioEntity.fromFirestore)
        .where((item) => <String>[
              item.nombre,
              item.responsable,
              item.telefono,
              item.direccion,
            ].any((value) => value.toLowerCase().contains(normalizedQuery)))
        .toList(growable: false);
  }
}
