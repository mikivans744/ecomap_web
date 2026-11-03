import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/centro_acopio_entity.dart';
import '../../domain/repositories/centro_acopio_repository.dart';

class FirestoreCentroAcopioRepository implements CentroAcopioRepository {
  FirestoreCentroAcopioRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'centros_acopio';
  static const String _offersCollection = 'ofertas';
  static const List<String> _activeOfferStatuses = [
    'pendiente',
    'aceptada',
    'en_camino',
  ];

  @override
  Stream<List<CentroAcopioEntity>> watchAll({
    String? zona,
    bool? estadoActivo,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    if (zona != null && zona.trim().isNotEmpty) {
      query = query.where('zona', isEqualTo: zona.trim());
    }
    if (estadoActivo != null) {
      query = query.where('estadoActivo', isEqualTo: estadoActivo);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(CentroAcopioEntity.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Stream<CentroAcopioEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        throw StateError('No existe el centro de acopio $id.');
      }
      return CentroAcopioEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(CentroAcopioEntity entity) async {
    final reference = entity.id.isEmpty
        ? _firestore.collection(_collection).doc()
        : _firestore.collection(_collection).doc(entity.id);
    await reference.set(entity.toFirestore());
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final reference = _firestore.collection(_collection).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('No existe el centro de acopio $id.');
      }
      final current = CentroAcopioEntity.fromFirestore(snapshot);
      final nextCapacity = data['capacidadMaxima'] is num
          ? (data['capacidadMaxima'] as num).toDouble()
          : current.capacidadMaxima;
      final reservedKilos =
          current.kilosComprometidos + current.kilosPendientes;
      if (nextCapacity < reservedKilos) {
        throw CentroAcopioCapacityBelowCommitted(
          capacity: nextCapacity,
          committed: reservedKilos,
        );
      }
      transaction.update(reference, data);
    });
  }

  @override
  Future<void> toggleActive(String id) => _toggleActive(id);

  @override
  Future<List<Map<String, dynamic>>> getActiveOffers(String centerId) async {
    final snapshot = await _firestore
        .collection(_offersCollection)
        .where('centroId', isEqualTo: centerId)
        .where('estado', whereIn: _activeOfferStatuses)
        .get();
    return snapshot.docs
        .map((document) => <String, dynamic>{
              'id': document.id,
              ...document.data(),
            })
        .toList(growable: false);
  }

  @override
  Future<List<CentroAcopioEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <CentroAcopioEntity>[];
    }
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map(CentroAcopioEntity.fromFirestore)
        .where((centro) => <String>[
              centro.nombre,
              centro.responsable,
              centro.telefono,
              centro.direccion,
            ].any((value) => value.toLowerCase().contains(normalizedQuery)))
        .toList(growable: false);
  }

  Future<void> _toggleActive(String id) async {
    final reference = _firestore.collection(_collection).doc(id);
    final current = await reference.get();
    if (!current.exists) {
      throw StateError('No existe el centro de acopio $id.');
    }
    final wasActive = current.data()?['estadoActivo'] == true;
    if (wasActive) {
      final activeOffers = await getActiveOffers(id);
      if (activeOffers.isNotEmpty) {
        throw CentroAcopioHasActiveOffers(activeOffers.length);
      }
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('No existe el centro de acopio $id.');
      }
      if ((snapshot.data()?['estadoActivo'] == true) != wasActive) {
        throw StateError(
          'El estado del centro cambió. Actualiza la lista e intenta nuevamente.',
        );
      }
      transaction.update(reference, {'estadoActivo': !wasActive});
    });
  }
}
