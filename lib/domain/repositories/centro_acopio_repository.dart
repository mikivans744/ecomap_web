import '../entities/centro_acopio_entity.dart';

abstract interface class CentroAcopioRepository {
  Stream<List<CentroAcopioEntity>> watchAll({
    String? zona,
    bool? estadoActivo,
  });

  Stream<CentroAcopioEntity> watchById(String id);

  Future<void> create(CentroAcopioEntity entity);

  Future<void> update(String id, Map<String, dynamic> data);

  Future<void> toggleActive(String id);

  Future<List<Map<String, dynamic>>> getActiveOffers(String centerId);

  Future<List<CentroAcopioEntity>> search(String query);
}

class CentroAcopioHasActiveOffers implements Exception {
  const CentroAcopioHasActiveOffers(this.offerCount);

  final int offerCount;

  @override
  String toString() => 'El centro tiene $offerCount ofertas activas.';
}

class CentroAcopioCapacityBelowCommitted implements Exception {
  const CentroAcopioCapacityBelowCommitted({
    required this.capacity,
    required this.committed,
  });

  final double capacity;
  final double committed;

  @override
  String toString() =>
      'La capacidad no puede ser menor que los $committed kg comprometidos.';
}
