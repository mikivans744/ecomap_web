import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/recolector_entity.dart';
import '../../domain/repositories/recolector_repository.dart';

class FirestoreRecolectorRepository implements RecolectorRepository {
  FirestoreRecolectorRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'recolectores';
  static const String _offersCollection = 'ofertas';
  static const String _centersCollection = 'centros_acopio';
  static const String _plateRegistryCollection = 'recolector_plate_registry';

  @override
  Stream<List<RecolectorEntity>> watchAll({String? zona, bool? estadoActivo}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    if (zona != null && zona.trim().isNotEmpty) {
      query = query.where('zona', isEqualTo: zona.trim());
    }
    if (estadoActivo != null) {
      query = query.where('estadoActivo', isEqualTo: estadoActivo);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(RecolectorEntity.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Stream<RecolectorEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        throw StateError('No existe el recolector $id.');
      }
      return RecolectorEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(RecolectorEntity entity) async {
    final reference = entity.id.isEmpty
        ? _firestore.collection(_collection).doc()
        : _firestore.collection(_collection).doc(entity.id);
    final data = entity.toFirestore();
    if (entity.userId.isEmpty) {
      data['userId'] = reference.id;
    }
    final plate = _activePlate(data);
    if (plate == null) {
      await reference.set(data);
      return;
    }

    await _assertPlateAvailable(plate, excludingId: reference.id);
    final registry = _plateRegistryReference(plate);
    await _firestore.runTransaction((transaction) async {
      final reservation = await transaction.get(registry);
      final ownerId = reservation.data()?['recolectorId'];
      if (reservation.exists && ownerId != reference.id) {
        throw RecolectorPlateAlreadyInUse(plate);
      }
      transaction.set(registry, {
        'placa': plate,
        'recolectorId': reference.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(reference, data);
    });
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final reference = _firestore.collection(_collection).doc(id);
    final initialSnapshot = await reference.get();
    if (!initialSnapshot.exists) {
      throw StateError('No existe el recolector $id.');
    }

    final initialData = initialSnapshot.data()!;
    if (data.containsKey('estadoActivo') &&
        data['estadoActivo'] != (initialData['estadoActivo'] == true)) {
      if (data.length == 1 && data['estadoActivo'] == true) {
        return _activate(id);
      }
      throw StateError(
          'Usa toggleActive para cambiar el estado del recolector.');
    }

    final nextData = <String, dynamic>{...initialData, ...data};
    final plate = _activePlate(nextData);
    if (plate != null) {
      await _assertPlateAvailable(plate, excludingId: id);
    }

    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(reference);
      if (!currentSnapshot.exists) {
        throw StateError('No existe el recolector $id.');
      }
      final currentData = currentSnapshot.data()!;
      final currentPlate = _activePlate(currentData);
      final mergedData = <String, dynamic>{...currentData, ...data};
      final nextPlate = _activePlate(mergedData);
      final nextRegistry =
          nextPlate == null ? null : _plateRegistryReference(nextPlate);
      final oldRegistry = currentPlate == null || currentPlate == nextPlate
          ? null
          : _plateRegistryReference(currentPlate);

      final nextReservation =
          nextRegistry == null ? null : await transaction.get(nextRegistry);
      final oldReservation =
          oldRegistry == null ? null : await transaction.get(oldRegistry);
      final ownerId = nextReservation?.data()?['recolectorId'];
      if (nextReservation?.exists == true && ownerId != id) {
        throw RecolectorPlateAlreadyInUse(nextPlate!);
      }

      transaction.update(reference, data);
      if (oldReservation?.data()?['recolectorId'] == id) {
        transaction.delete(oldRegistry!);
      }
      if (nextRegistry != null) {
        transaction.set(nextRegistry, {
          'placa': nextPlate,
          'recolectorId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> toggleActive(String id) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) {
      throw StateError('No existe el recolector $id.');
    }
    if (snapshot.data()?['estadoActivo'] != true) {
      await _activate(id);
      return;
    }
    await _deactivateWithCascade(id, snapshot.data()!);
  }

  @override
  Future<bool> isPlateAvailable(String plate, {String? excludingId}) async {
    final normalizedPlate = _normalizePlate(plate);
    if (normalizedPlate.isEmpty) return true;

    final reservation = await _plateRegistryReference(normalizedPlate).get();
    final reservationOwner = reservation.data()?['recolectorId'];
    if (reservation.exists && reservationOwner != excludingId) return false;

    final activeRecolectores = await _firestore
        .collection(_collection)
        .where('estadoActivo', isEqualTo: true)
        .get();
    return activeRecolectores.docs.every((doc) {
      if (doc.id == excludingId) return true;
      return _activePlate(doc.data()) != normalizedPlate;
    });
  }

  @override
  Future<List<RecolectorEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <RecolectorEntity>[];
    }
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map(RecolectorEntity.fromFirestore)
        .where((recolector) => <String>[
              recolector.nombreCompleto,
              recolector.telefono,
              recolector.zona,
            ].any((value) => value.toLowerCase().contains(normalizedQuery)))
        .toList(growable: false);
  }

  Future<void> _assertPlateAvailable(String plate,
      {required String excludingId}) async {
    if (!await isPlateAvailable(plate, excludingId: excludingId)) {
      throw RecolectorPlateAlreadyInUse(plate);
    }
  }

  Future<void> _activate(String id) async {
    final reference = _firestore.collection(_collection).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('No existe el recolector $id.');
      }
      final data = snapshot.data()!;
      final plate = _activePlate({...data, 'estadoActivo': true});
      if (plate != null) {
        await _assertPlateAvailable(plate, excludingId: id);
      }
      final registry = plate == null ? null : _plateRegistryReference(plate);
      final reservation =
          registry == null ? null : await transaction.get(registry);
      final ownerId = reservation?.data()?['recolectorId'];
      if (reservation?.exists == true && ownerId != id) {
        throw RecolectorPlateAlreadyInUse(plate!);
      }

      final update = <String, dynamic>{'estadoActivo': true};
      if (data['medioTransporte'] == 'vehiculo') {
        update['vehiculoInfo.estadoActivo'] = true;
      }
      transaction.update(reference, update);
      if (registry != null) {
        transaction.set(registry, {
          'placa': plate,
          'recolectorId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> _deactivateWithCascade(
    String id,
    Map<String, dynamic> recolectorData,
  ) async {
    final reference = _firestore.collection(_collection).doc(id);
    final activeOffers = await _firestore
        .collection(_offersCollection)
        .where('recolectorId', isEqualTo: id)
        .where('estadoActivo', isEqualTo: true)
        .get();
    final committedByCenter = <String, double>{};
    final pendingByCenter = <String, double>{};
    final acceptedCountByCenter = <String, int>{};
    final lockReferences = <String, DocumentReference<Map<String, dynamic>>>{};
    var canceledOfferWeight = 0.0;
    for (final offer in activeOffers.docs) {
      final data = offer.data();
      final weight = _asDouble(data['peso']);
      canceledOfferWeight += weight;
      final centerId = data['centroId'] as String?;
      if (centerId != null && centerId.isNotEmpty) {
        final state = data['estado'] as String? ?? '';
        if (state == 'pendiente' && data['capacityReserved'] == true) {
          pendingByCenter.update(
            centerId,
            (current) => current + weight,
            ifAbsent: () => weight,
          );
        } else if (state == 'aceptada' || state == 'en_camino') {
          committedByCenter.update(
            centerId,
            (current) => current + weight,
            ifAbsent: () => weight,
          );
          acceptedCountByCenter.update(
            centerId,
            (current) => current + 1,
            ifAbsent: () => 1,
          );
        }
        final category = data['categoria'] as String? ?? '';
        final lockId = _offerLockId(id, centerId, category);
        lockReferences[lockId] =
            _firestore.collection('oferta_active_locks').doc(lockId);
      }
    }

    final centers = await Future.wait(
      {...committedByCenter.keys, ...pendingByCenter.keys}.map(
        (centerId) =>
            _firestore.collection(_centersCollection).doc(centerId).get(),
      ),
    );
    final locks = await Future.wait(
      lockReferences.values.map((reference) => reference.get()),
    );
    final locksToDelete = <DocumentReference<Map<String, dynamic>>>[];
    for (final lock in locks) {
      final offerId = lock.data()?['ofertaId'];
      if (lock.exists &&
          activeOffers.docs.any((offer) => offer.id == offerId)) {
        locksToDelete.add(lock.reference);
      }
    }
    final plate = _activePlate(recolectorData);
    final registry = plate == null ? null : _plateRegistryReference(plate);
    final reservation = registry == null ? null : await registry.get();
    final reservationBelongsToRecolector =
        reservation?.data()?['recolectorId'] == id;

    final writeCount = 1 +
        activeOffers.docs.length +
        centers.where((center) => center.exists).length +
        locksToDelete.length +
        (reservationBelongsToRecolector ? 1 : 0);
    if (writeCount > 500) {
      throw StateError(
        'No se puede completar el bloqueo en una sola operación segura; '
        'el recolector tiene demasiadas ofertas activas.',
      );
    }

    final batch = _firestore.batch();
    final currentKilos = _asDouble(recolectorData['kilosOfertados']);
    final currentOffers = _asInt(recolectorData['totalOfertas']);
    final update = <String, dynamic>{
      'estadoActivo': false,
      'kilosOfertados':
          (currentKilos - canceledOfferWeight).clamp(0, double.infinity),
      'totalOfertas':
          (currentOffers - activeOffers.docs.length).clamp(0, 1 << 31),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (recolectorData['medioTransporte'] == 'vehiculo') {
      update['vehiculoInfo.estadoActivo'] = false;
    }
    batch.update(reference, update);

    for (final offer in activeOffers.docs) {
      batch.update(offer.reference, {
        'estadoActivo': false,
        'estado': 'cancelada',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': 'Recolector desactivado por administración',
      });
    }
    for (final center in centers) {
      if (!center.exists) continue;
      final centerData = center.data()!;
      final committedKilos = _asDouble(centerData['kilosComprometidos']);
      final pendingKilos = _asDouble(centerData['kilosPendientes']);
      final releasedCommitted = committedByCenter[center.id] ?? 0;
      final releasedPending = pendingByCenter[center.id] ?? 0;
      final acceptedCount = acceptedCountByCenter[center.id] ?? 0;
      final centerUpdate = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (releasedCommitted > 0) {
        centerUpdate['kilosComprometidos'] =
            (committedKilos - releasedCommitted).clamp(0, double.infinity);
        centerUpdate['totalOfertas'] =
            (_asInt(centerData['totalOfertas']) - acceptedCount)
                .clamp(0, 1 << 31);
      }
      if (releasedPending > 0) {
        centerUpdate['kilosPendientes'] =
            (pendingKilos - releasedPending).clamp(0, double.infinity);
      }
      batch.update(center.reference, centerUpdate);
    }
    for (final lockReference in locksToDelete) {
      batch.delete(lockReference);
    }
    if (reservationBelongsToRecolector) {
      batch.delete(registry!);
    }
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _plateRegistryReference(
      String plate) {
    return _firestore
        .collection(_plateRegistryCollection)
        .doc(_normalizePlate(plate));
  }

  String? _activePlate(Map<String, dynamic> data) {
    if (data['estadoActivo'] != true || data['medioTransporte'] != 'vehiculo') {
      return null;
    }
    final vehicle = data['vehiculoInfo'];
    if (vehicle is! Map) return null;
    final plate = vehicle['placa'];
    if (plate is! String || plate.trim().isEmpty) return null;
    return _normalizePlate(plate);
  }

  String _normalizePlate(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _offerLockId(String collectorId, String centerId, String category) =>
      base64Url
          .encode(utf8.encode(
            '$collectorId|$centerId|${category.trim().toLowerCase()}',
          ))
          .replaceAll('=', '');

  double _asDouble(dynamic value) => value is num ? value.toDouble() : 0;

  int _asInt(dynamic value) => value is num ? value.toInt() : 0;
}
