import '../entities/oferta_entity.dart';
import '../entities/negociacion_oferta_entity.dart';

abstract interface class OfertaRepository {
  Stream<List<OfertaEntity>> watchAll({
    String? estado,
    String? centroId,
    String? recolectorId,
    DateTime? desde,
    DateTime? hasta,
  });

  Stream<OfertaEntity> watchById(String id);

  Future<void> create(OfertaEntity entity);

  Future<void> accept(String id);

  Future<void> markInTransit(String id);

  Future<void> finalize(String id, {double? weightConfirmed});

  Future<void> cancel(String id, {String? reason});

  Future<List<OfertaEntity>> search(String query);

  Stream<List<NegociacionOfertaEntity>> watchNegotiationOffers({
    String? publicacionId,
    String? ciudadanoId,
    String? recolectorId,
  });

  Future<void> createNegotiationOffer(NegociacionOfertaEntity entity);
}

class OfertaStateTransitionException implements Exception {
  const OfertaStateTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfertaCapacityExceeded implements Exception {
  const OfertaCapacityExceeded({
    required this.capacity,
    required this.committed,
    required this.offerWeight,
  });

  final double capacity;
  final double committed;
  final double offerWeight;

  @override
  String toString() => 'La oferta excede la capacidad disponible del centro '
      '($committed + $offerWeight > $capacity kg).';
}

class OfertaDuplicateActive implements Exception {
  const OfertaDuplicateActive();

  @override
  String toString() =>
      'Ya existe una oferta pendiente o aceptada para este centro y material.';
}
