import '../entities/oferta_entity.dart';

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

  Future<void> finalize(String id);

  Future<void> cancel(String id, {String? reason});

  Future<List<OfertaEntity>> search(String query);
}

class OfertaStateTransitionException implements Exception {
  const OfertaStateTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfertaValidationException implements Exception {
  const OfertaValidationException(this.message);

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
