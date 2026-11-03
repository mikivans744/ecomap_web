import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/negociacion_oferta_entity.dart';
import '../../domain/entities/oferta_entity.dart';
import '../../domain/repositories/oferta_repository.dart';
import '../../domain/services/audit_service.dart';
import '../services/firestore_audit_service.dart';

class FirestoreOfertaRepository implements OfertaRepository {
  FirestoreOfertaRepository(
    this._firestore, {
    AuditService? auditService,
  }) : _auditService =
            auditService ?? FirestoreAuditService(firestore: _firestore);

  final FirebaseFirestore _firestore;
  final AuditService _auditService;
  static const String _centerOffers = 'ofertas_centro';
  static const String _negotiationOffers = 'ofertas';

  @override
  Stream<List<OfertaEntity>> watchAll({
    String? centroId,
    DateTime? desde,
    String? estado,
    DateTime? hasta,
    String? recolectorId,
    bool? estadoActivo,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection(_centerOffers);
    if (centroId != null) {
      query = query.where('centroId', isEqualTo: centroId);
    }
    if (recolectorId != null) {
      query = query.where('recolectorId', isEqualTo: recolectorId);
    }
    if (estado != null) {
      query = query.where('estado', isEqualTo: _canonicalState(estado));
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(OfertaEntity.fromFirestore)
        .where((offer) =>
            (estadoActivo == null || offer.estadoActivo == estadoActivo) &&
            (desde == null || !offer.fechaOferta.isBefore(desde)) &&
            (hasta == null || !offer.fechaOferta.isAfter(hasta)))
        .toList(growable: false));
  }

  @override
  Stream<List<NegociacionOfertaEntity>> watchNegotiationOffers({
    String? publicacionId,
    String? ciudadanoId,
    String? recolectorId,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection(_negotiationOffers);
    if (publicacionId != null) {
      query = query.where('publicacionId', isEqualTo: publicacionId);
    }
    if (ciudadanoId != null) {
      query = query.where('ciudadanoId', isEqualTo: ciudadanoId);
    }
    if (recolectorId != null) {
      query = query.where('recolectorId', isEqualTo: recolectorId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(NegociacionOfertaEntity.fromFirestore)
        .toList(growable: false));
  }

  @override
  Future<void> createNegotiationOffer(
      NegociacionOfertaEntity entity) async {
    final reference = entity.id.isEmpty
        ? _firestore.collection(_negotiationOffers).doc()
        : _firestore.collection(_negotiationOffers).doc(entity.id);
    await reference.set(entity.toFirestore());
  }

  @override
  Stream<OfertaEntity> watchById(String id) {
    return _firestore.collection(_centerOffers).doc(id).snapshots().map((doc) {
      if (!doc.exists) throw StateError('No existe la oferta $id.');
      return OfertaEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(OfertaEntity entity) async {
    final reference = entity.id.isEmpty
        ? _firestore.collection(_centerOffers).doc()
        : _firestore.collection(_centerOffers).doc(entity.id);
    final data = entity.toFirestore();
    await reference.set(data);
    await _auditService.log(
      action: 'center_offer_created',
      entityType: 'oferta_centro',
      entityId: reference.id,
      before: const {},
      after: data,
    );
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    const allowed = {
      'estado',
      'pesoKg',
      'precioSugerido',
      'fotoUrl',
      'lat',
      'lon',
      'weightConfirmed',
      'signatureUrl',
    };
    final changes = <String, dynamic>{};
    for (final entry in data.entries) {
      if (!allowed.contains(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'data',
          'No es un campo del diccionario oficial de ofertas_centro.',
        );
      }
      changes[entry.key] = entry.key == 'estado'
          ? _canonicalState('${entry.value}')
          : entry.value;
    }
    await _updateCenterOffer(id, changes, action: 'center_offer_updated');
  }

  @override
  Future<void> accept(String id) =>
      _updateCenterOffer(id, {'estado': 'ACEPTADA'}, action: 'offer_accepted',
          requiredState: 'OFERTADA');

  @override
  Future<void> markInTransit(String id) {
    throw UnsupportedError(
      'ofertas_centro no define un estado EN_RUTA o EN_CAMINO.',
    );
  }

  @override
  Future<void> finalize(String id) =>
      _updateCenterOffer(id, {'estado': 'ENTREGADA'},
          action: 'offer_delivered', requiredState: 'ACEPTADA');

  @override
  Future<void> cancel(String id, {String? reason}) =>
      _updateCenterOffer(id, {'estado': 'RECHAZADA'},
          action: 'offer_rejected', requiredState: 'OFERTADA');

  @override
  Future<List<OfertaEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const <OfertaEntity>[];
    final snapshot = await _firestore.collection(_centerOffers).get();
    return snapshot.docs
        .map(OfertaEntity.fromFirestore)
        .where((offer) =>
            offer.categoria.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  Future<void> _updateCenterOffer(
    String id,
    Map<String, dynamic> changes, {
    required String action,
    String? requiredState,
  }) async {
    final reference = _firestore.collection(_centerOffers).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe la oferta $id.');
    final current = snapshot.data()!;
    if (requiredState != null && current['estado'] != requiredState) {
      throw OfertaStateTransitionException(
        'La oferta debe estar en estado $requiredState, '
        'pero está en ${current['estado']}.',
      );
    }
    await reference.update(changes);
    await _auditService.log(
      action: action,
      entityType: 'oferta_centro',
      entityId: id,
      before: {for (final key in changes.keys) key: current[key]},
      after: changes,
    );
  }

  String _canonicalState(String state) => switch (state) {
        'ofertada' || 'pendiente' => 'OFERTADA',
        'aceptada' => 'ACEPTADA',
        'entregada' || 'finalizada' => 'ENTREGADA',
        'rechazada' || 'cancelada' => 'RECHAZADA',
        _ => state,
      };
}
