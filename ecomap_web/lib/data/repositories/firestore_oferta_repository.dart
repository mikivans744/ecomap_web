import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/oferta_entity.dart';
import '../../domain/repositories/oferta_repository.dart';

class FirestoreOfertaRepository implements OfertaRepository {
  FirestoreOfertaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _firestore.collection('ofertas');

  @override
  Stream<List<OfertaEntity>> watchAll({
    String? estado,
    String? centroId,
    String? recolectorId,
    DateTime? desde,
    DateTime? hasta,
  }) {
    Query<Map<String, dynamic>> query = _offers;
    if (estado != null) query = query.where('estado', isEqualTo: estado);
    if (centroId != null) query = query.where('centroId', isEqualTo: centroId);
    if (recolectorId != null) {
      query = query.where('recolectorId', isEqualTo: recolectorId);
    }
    if (desde != null) {
      query = query.where(
        'fechaOferta',
        isGreaterThanOrEqualTo: Timestamp.fromDate(desde),
      );
    }
    if (hasta != null) {
      query = query.where(
        'fechaOferta',
        isLessThanOrEqualTo: Timestamp.fromDate(hasta),
      );
    }
    return query.snapshots().map(
          (snapshot) =>
              snapshot.docs.map(OfertaEntity.fromFirestore).toList(),
        );
  }

  @override
  Stream<OfertaEntity> watchById(String id) {
    return _offers.doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists) throw StateError('No existe la oferta $id.');
      return OfertaEntity.fromFirestore(snapshot);
    });
  }

  @override
  Future<void> create(OfertaEntity entity) async {
    if (entity.id.isEmpty) {
      throw const OfertaValidationException(
        'La oferta debe tener un identificador.',
      );
    }
    if (entity.estado != 'pendiente' || entity.peso <= 0) {
      throw const OfertaValidationException(
        'Una oferta nueva debe estar pendiente y tener un peso mayor que cero.',
      );
    }

    final offerRef = _offers.doc(entity.id);
    final centerRef = _firestore.collection('centros_acopio').doc(entity.centroId);
    final collectorRef =
        _firestore.collection('recolectores').doc(entity.recolectorId);
    final lockRef = _activeLock(entity);
    final publicationRef = entity.publicacionId == null
        ? null
        : _firestore.collection('publicaciones').doc(entity.publicacionId);

    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);
      final lockSnapshot = await transaction.get(lockRef);
      final centerSnapshot = await transaction.get(centerRef);
      final collectorSnapshot = await transaction.get(collectorRef);
      final publicationSnapshot = publicationRef == null
          ? null
          : await transaction.get(publicationRef);

      if (offerSnapshot.exists) {
        throw const OfertaValidationException(
          'Ya existe una oferta con este identificador.',
        );
      }
      if (lockSnapshot.exists) {
        throw const OfertaDuplicateActive();
      }
      final center = _requireDocument(centerSnapshot, 'El centro no existe.');
      final collector =
          _requireDocument(collectorSnapshot, 'El recolector no existe.');
      _requireActive(center, 'El centro está inactivo.');
      _requireActive(collector, 'El recolector está inactivo.');
      _validateVehicle(collector, entity.peso);
      _validateAcceptedMaterial(center, entity.categoria);

      if (publicationSnapshot != null) {
        final publication =
            _requireDocument(publicationSnapshot, 'La publicación no existe.');
        if (publication['estadoActivo'] != true ||
            publication['estado'] != 'disponible') {
          throw const OfertaValidationException(
            'La publicación relacionada no está disponible.',
          );
        }
      }

      final capacity = _number(center['capacidadMaxima']);
      final committed = _number(center['kilosComprometidos']);
      final pending = _number(center['kilosPendientes']);
      if (committed + pending + entity.peso > capacity) {
        throw OfertaCapacityExceeded(
          capacity: capacity,
          committed: committed + pending,
          offerWeight: entity.peso,
        );
      }

      final now = Timestamp.now();
      transaction.set(offerRef, {
        ...entity.toFirestore(),
        'estado': 'pendiente',
        'estadoActivo': true,
        'capacityReserved': true,
        'fechaOferta': Timestamp.fromDate(entity.fechaOferta),
        'createdAt': now,
      });
      transaction.set(lockRef, {
        'ofertaId': entity.id,
        'recolectorId': entity.recolectorId,
        'centroId': entity.centroId,
        'categoria': _normalize(entity.categoria),
        'estado': 'pendiente',
        'createdAt': now,
      });
      transaction.update(centerRef, {
        'kilosPendientes': FieldValue.increment(entity.peso),
      });
      transaction.update(collectorRef, {
        'kilosOfertados': FieldValue.increment(entity.peso),
        'totalOfertas': FieldValue.increment(1),
      });
    });
  }

  @override
  Future<void> accept(String id) async {
    final offerRef = _offers.doc(id);
    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);
      final offer = _requireDocument(offerSnapshot, 'La oferta no existe.');
      _requireState(offer, id, 'pendiente');

      final centerRef =
          _firestore.collection('centros_acopio').doc(offer['centroId'] as String);
      final collectorRef = _firestore
          .collection('recolectores')
          .doc(offer['recolectorId'] as String);
      final publicationId = offer['publicacionId'] as String?;
      final publicationRef = publicationId == null
          ? null
          : _firestore.collection('publicaciones').doc(publicationId);

      final centerSnapshot = await transaction.get(centerRef);
      final collectorSnapshot = await transaction.get(collectorRef);
      final publicationSnapshot = publicationRef == null
          ? null
          : await transaction.get(publicationRef);
      final center = _requireDocument(centerSnapshot, 'El centro no existe.');
      final collector =
          _requireDocument(collectorSnapshot, 'El recolector no existe.');
      _requireActive(center, 'El centro está inactivo.');
      _requireActive(collector, 'El recolector está inactivo.');

      final weight = _number(offer['peso']);
      if (weight <= 0) {
        throw const OfertaValidationException(
          'El peso de la oferta debe ser mayor que cero.',
        );
      }
      _validateVehicle(collector, weight);
      _validateAcceptedMaterial(center, offer['categoria'] as String? ?? '');
      final capacity = _number(center['capacidadMaxima']);
      final committed = _number(center['kilosComprometidos']);
      final pending = _number(center['kilosPendientes']);
      final hasCapacityReservation = offer['capacityReserved'] == true;
      if (hasCapacityReservation && pending < weight) {
        throw const OfertaValidationException(
          'La reserva de capacidad de esta oferta no está disponible. '
          'Cancela la oferta y vuelve a crearla para recalcular la capacidad.',
        );
      }
      final pendingAfterAcceptance =
          pending - (hasCapacityReservation ? weight : 0);
      if (committed + pendingAfterAcceptance + weight > capacity) {
        throw OfertaCapacityExceeded(
          capacity: capacity,
          committed: committed + pendingAfterAcceptance,
          offerWeight: weight,
        );
      }

      if (publicationSnapshot != null) {
        final publication =
            _requireDocument(publicationSnapshot, 'La publicación no existe.');
        if (publication['estadoActivo'] != true ||
            publication['estado'] != 'disponible') {
          throw const OfertaValidationException(
            'La publicación ya no está disponible para reservarse.',
          );
        }
        final sellerId = publication['userId'] as String?;
        if (sellerId != null) {
          final sellerRef = _firestore.collection('users').doc(sellerId);
          final sellerSnapshot = await transaction.get(sellerRef);
          final seller = _requireDocument(
            sellerSnapshot,
            'El vendedor de la publicación no existe.',
          );
          _requireActive(seller, 'El vendedor está inactivo.');
          transaction.update(publicationRef!, {
            'estado': 'reservado',
            'reservedByOfferId': id,
          });
        }
      }

      transaction.update(offerRef, {
        'estado': 'aceptada',
        'acceptedAt': Timestamp.now(),
        'capacityReserved': false,
      });
      transaction.update(centerRef, {
        'kilosPendientes': pendingAfterAcceptance,
        'kilosComprometidos': FieldValue.increment(weight),
        'totalOfertas': FieldValue.increment(1),
      });
    });
  }

  @override
  Future<void> markInTransit(String id) async {
    final offerRef = _offers.doc(id);
    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);
      final offer = _requireDocument(offerSnapshot, 'La oferta no existe.');
      _requireState(offer, id, 'aceptada');

      final collectorRef = _firestore
          .collection('recolectores')
          .doc(offer['recolectorId'] as String);
      final collectorSnapshot = await transaction.get(collectorRef);
      final collector =
          _requireDocument(collectorSnapshot, 'El recolector no existe.');
      _requireActive(collector, 'El recolector está inactivo.');
      _validateVehicle(collector, _number(offer['peso']));

      transaction.update(offerRef, {
        'estado': 'en_camino',
        'inTransitAt': Timestamp.now(),
      });
    });
  }

  @override
  Future<void> finalize(String id) async {
    final offerRef = _offers.doc(id);
    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);
      final offer = _requireDocument(offerSnapshot, 'La oferta no existe.');
      _requireState(offer, id, 'en_camino');

      final centerRef =
          _firestore.collection('centros_acopio').doc(offer['centroId'] as String);
      final lockRef = _activeLockFromData(offer);
      final publicationId = offer['publicacionId'] as String?;
      final publicationRef = publicationId == null
          ? null
          : _firestore.collection('publicaciones').doc(publicationId);
      final centerSnapshot = await transaction.get(centerRef);
      final lockSnapshot = await transaction.get(lockRef);
      final publicationSnapshot = publicationRef == null
          ? null
          : await transaction.get(publicationRef);
      final center = _requireDocument(centerSnapshot, 'El centro no existe.');
      final weight = _number(offer['peso']);

      if (publicationSnapshot != null) {
        final publication =
            _requireDocument(publicationSnapshot, 'La publicación no existe.');
        if (publication['reservedByOfferId'] != id) {
          throw const OfertaValidationException(
            'La publicación ya no está reservada por esta oferta.',
          );
        }
        transaction.update(publicationRef!, {
          'estado': 'vendido',
          'estadoActivo': false,
          'soldByOfferId': id,
          'reservedByOfferId': FieldValue.delete(),
        });
      }

      transaction.update(offerRef, {
        'estado': 'finalizada',
        'estadoActivo': false,
        'finalizedAt': Timestamp.now(),
      });
      transaction.update(centerRef, {
        'kilosComprometidos': _nonNegativeDouble(
          _number(center['kilosComprometidos']) - weight,
        ),
      });
      if (lockSnapshot.exists &&
          lockSnapshot.data()?['ofertaId'] == id) {
        transaction.delete(lockRef);
      }
    });
  }

  @override
  Future<void> cancel(String id, {String? reason}) async {
    final offerRef = _offers.doc(id);
    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);
      final offer = _requireDocument(offerSnapshot, 'La oferta no existe.');
      final state = offer['estado'] as String? ?? '';
      if (state == 'finalizada' || state == 'cancelada') {
        throw OfertaStateTransitionException(
          'No se puede cancelar una oferta $state.',
        );
      }
      if (state != 'pendiente' &&
          state != 'aceptada' &&
          state != 'en_camino') {
        throw OfertaStateTransitionException(
          'No se puede cancelar una oferta en estado "$state".',
        );
      }

      final centerRef =
          _firestore.collection('centros_acopio').doc(offer['centroId'] as String);
      final collectorRef = _firestore
          .collection('recolectores')
          .doc(offer['recolectorId'] as String);
      final lockRef = _activeLockFromData(offer);
      final publicationId = offer['publicacionId'] as String?;
      final publicationRef = publicationId == null
          ? null
          : _firestore.collection('publicaciones').doc(publicationId);
      final centerSnapshot = await transaction.get(centerRef);
      final collectorSnapshot = await transaction.get(collectorRef);
      final lockSnapshot = await transaction.get(lockRef);
      final publicationSnapshot = publicationRef == null
          ? null
          : await transaction.get(publicationRef);
      final center = _requireDocument(centerSnapshot, 'El centro no existe.');
      final collector =
          _requireDocument(collectorSnapshot, 'El recolector no existe.');
      final weight = _number(offer['peso']);
      final wasAccepted = state == 'aceptada' || state == 'en_camino';
      final hadCapacityReservation = offer['capacityReserved'] == true;

      transaction.update(offerRef, {
        'estado': 'cancelada',
        'estadoActivo': false,
        'cancelledAt': Timestamp.now(),
        if (reason != null && reason.trim().isNotEmpty)
          'cancelReason': reason.trim(),
      });
      final centerUpdates = <String, dynamic>{};
      if (wasAccepted) {
        centerUpdates.addAll({
          'kilosComprometidos': _nonNegativeDouble(
            _number(center['kilosComprometidos']) - weight,
          ),
          'totalOfertas':
              _nonNegativeInt(_integer(center['totalOfertas']) - 1),
        });
      } else if (hadCapacityReservation) {
        centerUpdates['kilosPendientes'] = _nonNegativeDouble(
          _number(center['kilosPendientes']) - weight,
        );
      }
      if (centerUpdates.isNotEmpty) {
        transaction.update(centerRef, centerUpdates);
      }
      transaction.update(collectorRef, {
        'kilosOfertados': _nonNegativeDouble(
          _number(collector['kilosOfertados']) - weight,
        ),
        'totalOfertas':
            _nonNegativeInt(_integer(collector['totalOfertas']) - 1),
      });
      if (publicationSnapshot != null &&
          publicationSnapshot.data()?['reservedByOfferId'] == id) {
        transaction.update(publicationRef!, {
          'estado': 'disponible',
          'reservedByOfferId': FieldValue.delete(),
        });
      }
      if (lockSnapshot.exists &&
          lockSnapshot.data()?['ofertaId'] == id) {
        transaction.delete(lockRef);
      }
    });
  }

  @override
  Future<List<OfertaEntity>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const <OfertaEntity>[];
    final snapshot = await _offers.get();
    return snapshot.docs
        .map(OfertaEntity.fromFirestore)
        .where((offer) =>
            offer.id.toLowerCase().contains(normalized) ||
            offer.categoria.toLowerCase().contains(normalized) ||
            offer.centroId.toLowerCase().contains(normalized) ||
            offer.recolectorId.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  DocumentReference<Map<String, dynamic>> _activeLock(OfertaEntity offer) =>
      _firestore.collection('oferta_active_locks').doc(
            _lockId(
              offer.recolectorId,
              offer.centroId,
              offer.categoria,
            ),
          );

  DocumentReference<Map<String, dynamic>> _activeLockFromData(
    Map<String, dynamic> offer,
  ) =>
      _firestore.collection('oferta_active_locks').doc(
            _lockId(
              offer['recolectorId'] as String? ?? '',
              offer['centroId'] as String? ?? '',
              offer['categoria'] as String? ?? '',
            ),
          );

  static String _lockId(String collectorId, String centerId, String material) =>
      base64Url
          .encode(utf8.encode(
            '$collectorId|$centerId|${_normalize(material)}',
          ))
          .replaceAll('=', '');

  static Map<String, dynamic> _requireDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String message,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw OfertaValidationException(message);
    }
    return data;
  }

  static void _requireActive(Map<String, dynamic> data, String message) {
    if (data['estadoActivo'] != true) {
      throw OfertaValidationException(message);
    }
  }

  static void _requireState(
    Map<String, dynamic> offer,
    String id,
    String expected,
  ) {
    if (offer['estado'] != expected) {
      throw OfertaStateTransitionException(
        'La oferta $id debe estar en estado "$expected".',
      );
    }
  }

  static void _validateAcceptedMaterial(
    Map<String, dynamic> center,
    String category,
  ) {
    final materials = center['materialesAceptados'];
    final acceptsMaterial = materials is Iterable &&
        materials.whereType<String>().any(
              (material) =>
                  _normalize(material) == _normalize(category),
            );
    if (!acceptsMaterial) {
      throw OfertaValidationException(
        'El centro no acepta el material "${category.trim()}".',
      );
    }
  }

  static void _validateVehicle(
    Map<String, dynamic> collector,
    double weight,
  ) {
    final vehicle = collector['vehiculoInfo'];
    if (vehicle is! Map<String, dynamic> ||
        vehicle['estadoActivo'] != true) {
      throw const OfertaValidationException(
        'El vehículo del recolector está inactivo o no está registrado.',
      );
    }
    final vehicleCapacity = _number(vehicle['capacidad']);
    if (weight > vehicleCapacity) {
      throw OfertaValidationException(
        'El peso de la oferta ($weight kg) supera la capacidad del vehículo '
        '($vehicleCapacity kg).',
      );
    }
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static double _number(Object? value) =>
      value is num ? value.toDouble() : 0;

  static int _integer(Object? value) => value is num ? value.toInt() : 0;

  static double _nonNegativeDouble(double value) => value < 0 ? 0 : value;

  static int _nonNegativeInt(int value) => value < 0 ? 0 : value;
}
